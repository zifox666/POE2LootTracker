using System.Runtime.InteropServices;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using GameHelper;
using GameHelper.RemoteEnums;
using GameHelper.RemoteEnums.Entity;
using GameHelper.RemoteObjects.Components;
using LootTracker;

namespace LootTracker.App;

internal sealed class LootTrackerEngine : IDisposable
{
    internal const string CostEntryPrefix = "__cost_preset__:";
    private static readonly Regex EmbeddedPricePattern = new(
        @"[\[【]\s*(?<amount>\d+(?:[\.,]\d+)?)\s*(?<unit>[dDeE])\s*[\]】]\s*$",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    private const char ItemKeySeparator = '\u001f';
    private const uint ProcessVmRead = 0x0010;
    private const uint ProcessQueryInformation = 0x0400;

    private static readonly HashSet<string> SafeZoneIds = new(StringComparer.Ordinal)
    {
        "Abyss_Hub",
    };

    private readonly AppSettings settings;
    private readonly SqliteStore store;
    private PriceCache priceCache = new();
    private readonly Dictionary<string, string> metaToArt = new(StringComparer.Ordinal);
    private readonly Dictionary<string, string> chineseItemNames = new(StringComparer.OrdinalIgnoreCase);
    private readonly Dictionary<string, string> itemBaseNames = new(StringComparer.Ordinal);
    private readonly Dictionary<string, double> manualPricesEx = new(StringComparer.Ordinal);
    private readonly List<MapRun> runs = new();
    private readonly Dictionary<uint, MonsterTally> monsterTallies = new();
    private readonly string leagueCachePath = Path.Combine(AppSettings.CacheDirectory, "leagues.json");

    private DateTime sessionStartUtc = DateTime.UtcNow;
    private TimeSpan sessionPausedTime;
    private DateTime? pauseStartedUtc;
    private DateTime? runStartUtc;
    private DateTime nextInventoryReadUtc;
    private DateTime nextKillScanUtc;
    private DateTime nextAutoSaveUtc;
    private DateTime nextPriceRefreshCheckUtc;
    private DateTime nextLeagueRefreshCheckUtc;
    private MapRun? current;
    private Dictionary<string, long>? baseline;
    private Dictionary<string, long> liveLegDelta = new(StringComparer.Ordinal);
    private string lastZoneHash = string.Empty;
    private bool baselinePending;
    private bool onMap;
    private bool trackingPaused;

    /// Set when a saved session with recorded runs was restored at startup, and cleared the moment a
    /// brand-new session is started. Surfaced in the snapshot so the panel can ask whether to keep
    /// it.
    private bool resumedSession;
    private IntPtr processHandle;
    private int handlePid;
    private string sessionId = Guid.NewGuid().ToString("N");
    private DateTime persistedPriceSyncUtc = DateTime.MinValue;

    public LootTrackerEngine(AppSettings settings, SqliteStore store)
    {
        this.settings = settings;
        this.store = store;
        Directory.CreateDirectory(AppSettings.CacheDirectory);
        this.LoadMetaArt();
        this.LoadChineseItemNames();
        this.LoadManualPrices();
        this.LoadActiveSession();
        if (!NinjaLeagues.TryLoadFromDisk(this.leagueCachePath, NinjaLeagues.DefaultTtlHours))
        {
            NinjaLeagues.StartRefresh(this.leagueCachePath);
        }

        var market = this.store.LoadMarketSnapshot(settings.League);
        if (market != null)
        {
            this.priceCache.LoadSnapshot(market.Prices.Select(row => new PriceEntry(row.Key, row.Name, row.PriceEx, row.IconUrl, row.Kind, row.Category)), market.DivineRate, market.FetchedUtc);
        }
        if (market == null || MissingCategories(market) || DateTime.UtcNow - market.FetchedUtc > TimeSpan.FromMinutes(settings.PriceCacheMinutes))
        {
            this.priceCache.StartRefresh(settings.League, string.Empty);
        }
    }

    /// True when a stored snapshot predates category tagging, which would leave the panel's price
    /// table with nothing to group by. Treated as stale so it is refetched once and then rewritten
    /// with categories.
    private static bool MissingCategories(MarketSnapshot market) =>
        market.Prices.Count > 0 && market.Prices.All(row => row.Category.Length == 0);

    public void Tick()
    {
        var now = DateTime.UtcNow;
        if (now >= this.nextLeagueRefreshCheckUtc)
        {
            this.nextLeagueRefreshCheckUtc = now.AddMinutes(1);
            if (NinjaLeagues.IsStale && NinjaLeagues.Status != PriceSyncStatus.Syncing)
            {
                NinjaLeagues.StartRefresh(this.leagueCachePath);
            }
        }

        if (now >= this.nextPriceRefreshCheckUtc)
        {
            this.nextPriceRefreshCheckUtc = now.AddMinutes(1);
            if (this.priceCache.Status != PriceSyncStatus.Syncing &&
                now - this.priceCache.LastSyncUtc > TimeSpan.FromMinutes(Math.Max(1, this.settings.PriceCacheMinutes)))
            {
                this.priceCache.StartRefresh(this.settings.League, string.Empty);
            }
        }

        if (this.priceCache.Status == PriceSyncStatus.Ready &&
            this.priceCache.LastSyncUtc > this.persistedPriceSyncUtc)
        {
            this.store.ReplaceMarketPrices(
                this.settings.League,
                this.priceCache.SnapshotEntries().Select(entry => new MarketPriceRow(entry.Key, entry.Name, entry.PriceEx, entry.IconUrl, entry.Kind, entry.Category)),
                this.priceCache.LastSyncUtc,
                this.priceCache.DivineToExaltedRate);
            this.persistedPriceSyncUtc = this.priceCache.LastSyncUtc;
        }

        if (Core.States.GameCurrentState != GameStateTypes.InGameState)
        {
            return;
        }

        this.UpdateAreaState();
        this.UpdateLiveInventory();
        this.ScanKills();

        if (now >= this.nextAutoSaveUtc)
        {
            this.nextAutoSaveUtc = now.AddSeconds(20);
            this.SaveActiveSession();
        }
    }

    public TrackerSnapshot GetSnapshot()
    {
        if (this.onMap && this.current is { CostEx: <= 0 } currentWithPendingCost &&
            currentWithPendingCost.CostPresetId.Length > 0)
        {
            var pendingPreset = this.settings.CostPresets.FirstOrDefault(
                preset => string.Equals(preset.Id, currentWithPendingCost.CostPresetId, StringComparison.Ordinal));
            if (pendingPreset != null && CostInEx(pendingPreset, this.priceCache.DivineToExaltedRate) > 0)
            {
                ApplyCostPreset(currentWithPendingCost, pendingPreset, this.priceCache.DivineToExaltedRate);
            }
        }
        bool connected = Core.Process.Pid != 0;
        var currentGained = this.CurrentGainedLive();
        var currentLoot = this.BuildLoot(currentGained, this.current);
        double currentProfit = this.current == null ? 0 : this.NetValue(this.current, currentGained);
        double totalProfit = 0;
        var totalTime = TimeSpan.Zero;

        foreach (var run in this.runs)
        {
            bool isCurrent = ReferenceEquals(run, this.current);
            var gained = isCurrent ? currentGained : run.Gained;
            totalProfit += isCurrent || run.FrozenProfitEx is null ? this.NetValue(run, gained) : run.FrozenProfitEx.Value;
            totalTime += isCurrent ? this.CurrentLiveTime() : run.ActiveTime;
        }

        double perHour = totalTime.TotalHours > 0 ? totalProfit / totalTime.TotalHours : 0;
        var mapSummaries = this.runs
            .AsEnumerable()
            .Reverse()
            .Select(run =>
            {
                bool isCurrent = ReferenceEquals(run, this.current);
                var gained = isCurrent ? currentGained : run.Gained;
                return new MapSummary(
                    run.Id,
                    run.Name,
                    run.AreaLevel,
                    isCurrent ? this.CurrentLiveTime() : run.ActiveTime,
                    isCurrent || run.FrozenProfitEx is null ? this.NetValue(run, gained) : run.FrozenProfitEx.Value,
                    this.CostOf(run, gained),
                    gained.Count(entry => entry.Value != 0) + (run.CostEx > 0 ? 1 : 0),
                    (int[])run.Kills.Clone(),
                    isCurrent && this.onMap);
            })
            .ToList();
        string status = !connected
            ? "等待游戏"
            : Core.States.GameCurrentState != GameStateTypes.InGameState
                ? "游戏已连接"
                : this.onMap ? "追踪中" : "安全区";

        return new TrackerSnapshot(
            this.sessionId,
            this.resumedSession,
            this.sessionStartUtc,
            connected,
            this.onMap,
            this.trackingPaused,
            status,
            this.current?.Name ?? "—",
            this.onMap ? this.current?.CostPresetId ?? string.Empty : string.Empty,
            this.onMap ? this.current?.CostName ?? string.Empty : string.Empty,
            this.onMap ? this.current?.CostEx ?? 0 : 0,
            this.CurrentLiveTime(),
            this.CurrentSessionTime(),
            totalTime,
            currentProfit,
            totalProfit,
            perHour,
            this.priceCache.DivineToExaltedRate,
            this.runs.Count,
            this.current == null ? new int[4] : (int[])this.current.Kills.Clone(),
            currentLoot,
            mapSummaries,
            this.priceCache.LastSyncUtc,
            this.priceCache.Status,
            this.priceCache.LastError);
    }

    public void ResetSession()
    {
        if (this.current != null && this.baseline != null)
        {
            MergeInto(this.current.Gained, this.liveLegDelta);
            this.liveLegDelta.Clear();
        }

        this.BankActiveTime(DateTime.UtcNow);
        this.ArchiveSession();
        this.runs.Clear();
        this.current = null;
        this.runStartUtc = null;
        this.baseline = null;
        this.baselinePending = false;
        this.liveLegDelta.Clear();
        this.monsterTallies.Clear();
        this.lastZoneHash = string.Empty;
        this.sessionStartUtc = DateTime.UtcNow;
        this.sessionId = Guid.NewGuid().ToString("N");
        this.sessionPausedTime = TimeSpan.Zero;
        this.pauseStartedUtc = null;
        this.trackingPaused = false;
        this.resumedSession = false;
        this.SaveActiveSession();
    }

    public void ToggleTrackingPause()
    {
        if (this.trackingPaused)
        {
            this.ResumeTracking();
        }
        else
        {
            this.PauseTracking();
        }
    }

    public void SetManualPrice(string itemKey, double priceEx)
    {
        if (string.IsNullOrWhiteSpace(itemKey) || priceEx <= 0 || double.IsNaN(priceEx) || double.IsInfinity(priceEx))
        {
            return;
        }

        this.manualPricesEx[itemKey] = priceEx;
        this.store.SetManualPrice(itemKey, priceEx);
    }

    public void ClearManualPrice(string itemKey)
    {
        if (this.manualPricesEx.Remove(itemKey)) this.store.SetManualPrice(itemKey, null);
    }

    public void SelectCostPreset(string presetId)
    {
        var selected = this.settings.CostPresets.FirstOrDefault(
            preset => string.Equals(preset.Id, presetId, StringComparison.Ordinal));
        if (this.onMap && this.current != null)
        {
            ApplyCostPreset(this.current, selected, this.priceCache.DivineToExaltedRate);
            this.current.FrozenProfitEx = null;
            this.SaveActiveSession();
            return;
        }

        foreach (var preset in this.settings.CostPresets)
        {
            preset.IsDefault = ReferenceEquals(preset, selected);
        }
        this.settings.SelectedCostPresetId = selected?.Id ?? string.Empty;
        this.settings.Save(this.store);
    }

    public void RefreshCostSettings()
    {
        if (this.onMap && this.current != null)
        {
            var preset = this.settings.CostPresets.FirstOrDefault(
                value => string.Equals(value.Id, this.current.CostPresetId, StringComparison.Ordinal));
            ApplyCostPreset(this.current, preset, this.priceCache.DivineToExaltedRate);
            this.current.FrozenProfitEx = null;
            this.SaveActiveSession();
        }
    }

    public void RefreshPrices()
    {
        this.priceCache.StartRefresh(this.settings.League, string.Empty);
    }

    public void Pause() => this.PauseTracking();

    public void Resume() => this.ResumeTracking();

    public OffsetValidation TestOffsetProfile(MemoryOffsetProfile profile)
    {
        if (!profile.IsStructurallyValid(out var error)) return new OffsetValidation("invalid", error);
        if (Core.Process.Pid == 0 || Core.States.GameCurrentState != GameStateTypes.InGameState)
        {
            return new OffsetValidation("pending", "game_not_ready");
        }

        var previous = this.settings.Offsets;
        try
        {
            this.settings.Offsets = profile;
            this.ResetHandle();
            return this.TrySnapshotInventory(out _, true)
                ? new OffsetValidation("valid", string.Empty)
                : new OffsetValidation("invalid", "inventory_validation_failed");
        }
        finally
        {
            this.settings.Offsets = previous;
            this.ResetHandle();
        }
    }

    public void ApplyOffsetProfile(MemoryOffsetProfile profile)
    {
        this.settings.Offsets = profile;
        this.settings.Save(this.store);
        this.ResetHandle();
    }

    public IReadOnlyList<string> GetLeagues() => NinjaLeagues.ComboItems(this.settings.League).ToList();

    /// Whether display names should be shown in Chinese: an explicit language setting wins,
    /// otherwise follow the OS UI language -- the same rule the panel's own locale getter uses.
    private bool PreferChineseNames => this.settings.Language switch
    {
        "en" => false,
        "zh" => true,
        _ => CultureInfo.CurrentUICulture.TwoLetterISOLanguageName.Equals("zh", StringComparison.OrdinalIgnoreCase),
    };

    /// The price table as the panel wants it: localized display names, the poe.ninja economy section
    /// each row came from (so the panel can group the table the way poe.ninja's own pages do), and
    /// manual overrides attached.
    ///
    /// The search runs here rather than in SQL because it has to match the name the user actually
    /// reads; the table only stores poe.ninja's English name, so a query typed in Chinese could
    /// never match it there.
    public IReadOnlyList<object> ListMarketPrices(string query, int limit)
    {
        string needle = query.Trim();
        bool chinese = this.PreferChineseNames;
        var rows = this.store.ListMarketPrices(this.settings.League);

        return rows
            .Select(row => (Row: row, Name: chinese ? this.LocalizeItemName(row.Name) : row.Name))
            .Where(entry => needle.Length == 0
                || entry.Name.Contains(needle, StringComparison.OrdinalIgnoreCase)
                || entry.Row.Name.Contains(needle, StringComparison.OrdinalIgnoreCase)
                || entry.Row.Key.Contains(needle, StringComparison.OrdinalIgnoreCase))
            .OrderByDescending(entry => entry.Row.PriceEx)
            .Take(Math.Clamp(limit, 1, 1000))
            .Select(entry => (object)new
            {
                key = entry.Row.Key,
                name = entry.Name,
                priceEx = entry.Row.PriceEx,
                manualPriceEx = entry.Row.ManualEx,
                iconUrl = entry.Row.IconUrl,
                fetchedUtc = entry.Row.FetchedUtc,
                category = entry.Row.Category,
            })
            .ToList();
    }

    public PriceSyncStatus LeagueStatus => NinjaLeagues.Status;

    public string LeagueError => NinjaLeagues.LastError;

    public void RefreshLeagues() => NinjaLeagues.StartRefresh(this.leagueCachePath);

    public void ChangeLeague(string league)
    {
        string value = league.Trim();
        if (value.Length == 0 || string.Equals(value, this.settings.League, StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        this.settings.League = value;
        this.settings.Save(this.store);
        this.priceCache = new PriceCache();
        var market = this.store.LoadMarketSnapshot(value);
        if (market != null)
        {
            this.priceCache.LoadSnapshot(market.Prices.Select(row => new PriceEntry(row.Key, row.Name, row.PriceEx, row.IconUrl, row.Kind, row.Category)), market.DivineRate, market.FetchedUtc);
        }
        if (market == null || MissingCategories(market) || DateTime.UtcNow - market.FetchedUtc > TimeSpan.FromMinutes(this.settings.PriceCacheMinutes)) this.priceCache.StartRefresh(value, string.Empty);
    }

    public void Dispose()
    {
        this.BankActiveTime(DateTime.UtcNow);
        if (this.current != null)
        {
            MergeInto(this.current.Gained, this.liveLegDelta);
            this.current.ActiveTime = this.CurrentLiveTime();
        }
        this.DisposeSession();
        this.ResetHandle();
    }

    private void UpdateAreaState()
    {
        var inGame = Core.States.InGameStateObject;
        var area = inGame.CurrentAreaInstance;
        var details = inGame.CurrentWorldInstance.AreaDetails;
        string hash = area.AreaHash;

        if (string.IsNullOrEmpty(hash) || string.IsNullOrEmpty(details.Name))
        {
            return;
        }

        if (!string.Equals(hash, this.lastZoneHash, StringComparison.Ordinal))
        {
            this.lastZoneHash = hash;
            this.HandleZoneTransition(hash, details.Name, details.Id, details.IsHideout, details.IsTown, area.CurrentAreaLevel);
        }

        if (this.baselinePending && this.TrySnapshotInventory(out var snapshot))
        {
            this.baseline = snapshot;
            this.baselinePending = false;
            this.liveLegDelta.Clear();
        }
    }

    private void HandleZoneTransition(string hash, string name, string id, bool isHideout, bool isTown, int areaLevel)
    {
        bool isMap = !isHideout && !isTown && !SafeZoneIds.Contains(id);
        bool wasOnMap = this.onMap;
        this.onMap = isMap;
        var now = DateTime.UtcNow;

        if (isMap)
        {
            if (this.trackingPaused)
            {
                this.ResumeTracking(now, false);
            }

            this.BankActiveTime(now);
            if (wasOnMap && this.current != null && this.baseline != null && this.TrySnapshotInventory(out var outgoing))
            {
                MergeInto(this.current.Gained, Diff(outgoing, this.baseline));
            }

            this.current = this.runs.LastOrDefault(run => string.Equals(run.Hash, hash, StringComparison.Ordinal));
            if (this.current == null)
            {
                this.current = new MapRun
                {
                    SessionId = this.sessionId,
                    Name = name,
                    Hash = hash,
                    AreaLevel = areaLevel,
                    StartedUtc = now,
                };
                var preset = ResolveCostPreset(this.settings.CostPresets, name);
                ApplyCostPreset(this.current, preset, this.priceCache.DivineToExaltedRate);
                this.runs.Add(this.current);
                while (this.runs.Count > 100)
                {
                    this.runs.RemoveAt(0);
                }
            }
            else
            {
                this.current.EndedUtc = null;
                this.current.FrozenProfitEx = null;
            }

            this.runStartUtc = now;
            this.baseline = null;
            this.baselinePending = true;
            this.liveLegDelta.Clear();
            this.monsterTallies.Clear();
        }
        else if (this.current != null)
        {
            this.BankActiveTime(now);
            if (this.baseline != null && this.TrySnapshotInventory(out var snapshot))
            {
                MergeInto(this.current.Gained, Diff(snapshot, this.baseline));
            }

            this.baseline = null;
            this.baselinePending = false;
            this.liveLegDelta.Clear();
            this.current.EndedUtc = now;
            this.current.ClosingDivineRate = this.priceCache.DivineToExaltedRate;
            this.current.FrozenProfitEx = this.NetValue(this.current, this.current.Gained);
        }

        this.SaveActiveSession();
    }

    private void UpdateLiveInventory()
    {
        if (this.current == null || !this.onMap || this.baseline == null)
        {
            return;
        }

        var now = DateTime.UtcNow;
        if (now < this.nextInventoryReadUtc)
        {
            return;
        }

        this.nextInventoryReadUtc = now.AddMilliseconds(500);
        if (this.TrySnapshotInventory(out var snapshot))
        {
            this.liveLegDelta = Diff(snapshot, this.baseline);
        }
    }

    private void ScanKills()
    {
        if (this.current == null || !this.onMap || DateTime.UtcNow < this.nextKillScanUtc)
        {
            return;
        }

        this.nextKillScanUtc = DateTime.UtcNow.AddMilliseconds(150);
        foreach (var pair in Core.States.InGameStateObject.CurrentAreaInstance.AwakeEntities)
        {
            var entity = pair.Value;
            if (!entity.IsValid || entity.EntityType != EntityTypes.Monster)
            {
                continue;
            }

            bool dead = entity.EntityState == EntityStates.Useless;
            if (this.monsterTallies.TryGetValue(entity.Id, out var tally))
            {
                if (!tally.Tallied)
                {
                    if (!dead)
                    {
                        tally.SeenAlive = true;
                    }
                    else if (tally.SeenAlive)
                    {
                        this.current.Kills[tally.RarityIndex]++;
                        tally.Tallied = true;
                    }
                }

                continue;
            }

            if (entity.EntityState is EntityStates.MonsterFriendly or EntityStates.PinnacleBossHidden ||
                !entity.TryGetComponent<ObjectMagicProperties>(out var properties, true))
            {
                continue;
            }

            int rarity = (int)properties.Rarity;
            if (rarity is >= 0 and <= 3)
            {
                this.monsterTallies[entity.Id] = new MonsterTally(rarity, !dead);
            }
        }
    }

    private Dictionary<string, long> CurrentGainedLive()
    {
        if (this.current == null)
        {
            return new Dictionary<string, long>(StringComparer.Ordinal);
        }

        var result = new Dictionary<string, long>(this.current.Gained, StringComparer.Ordinal);
        if (this.baseline != null)
        {
            MergeInto(result, this.liveLegDelta);
        }

        return result;
    }

    private TimeSpan CurrentLiveTime()
    {
        if (this.current == null)
        {
            return TimeSpan.Zero;
        }

        return this.current.ActiveTime + (this.runStartUtc is { } started ? DateTime.UtcNow - started : TimeSpan.Zero);
    }

    private void BankActiveTime(DateTime now)
    {
        if (this.current != null && this.runStartUtc is { } started)
        {
            this.current.ActiveTime += now - started;
            this.runStartUtc = null;
        }
    }

    private TimeSpan CurrentSessionTime()
    {
        var paused = this.sessionPausedTime;
        if (this.trackingPaused && this.pauseStartedUtc is { } pausedAt)
        {
            paused += DateTime.UtcNow - pausedAt;
        }

        var value = DateTime.UtcNow - this.sessionStartUtc - paused;
        return value < TimeSpan.Zero ? TimeSpan.Zero : value;
    }

    private void PauseTracking()
    {
        if (this.trackingPaused)
        {
            return;
        }

        var now = DateTime.UtcNow;
        this.BankActiveTime(now);
        this.trackingPaused = true;
        this.pauseStartedUtc = now;
        this.SaveActiveSession();
    }

    private void ResumeTracking() => this.ResumeTracking(DateTime.UtcNow, true);

    private void ResumeTracking(DateTime now, bool save)
    {
        if (!this.trackingPaused)
        {
            return;
        }

        if (this.pauseStartedUtc is { } pausedAt)
        {
            this.sessionPausedTime += now - pausedAt;
        }

        this.pauseStartedUtc = null;
        this.trackingPaused = false;
        if (this.onMap && this.current != null)
        {
            this.runStartUtc = now;
        }

        if (save)
        {
            this.SaveActiveSession();
        }
    }

    private IReadOnlyList<LootLine> BuildLoot(Dictionary<string, long> gained, MapRun? run = null)
    {
        var result = new List<LootLine>();
        foreach (var entry in gained)
        {
            if (entry.Value == 0)
            {
                continue;
            }

            bool priced = this.TryPriceItem(entry.Key, out double unit, out string label);
            result.Add(new LootLine(entry.Key, label, entry.Value, unit, priced ? unit * entry.Value : 0, priced, this.ResolveIconUrl(entry.Key)));
        }

        if (run is { CostEx: > 0 })
        {
            result.Add(new LootLine(
                CostEntryPrefix + run.CostPresetId,
                run.CostName,
                -1,
                run.CostEx,
                -run.CostEx,
                true,
                string.Empty));
        }

        return result.OrderByDescending(line => Math.Abs(line.TotalEx)).ThenBy(line => line.Name, StringComparer.Ordinal).ToList();
    }

    private double ValueOf(Dictionary<string, long> gained)
    {
        double total = 0;
        foreach (var entry in gained)
        {
            if (entry.Value != 0 && this.TryPriceItem(entry.Key, out double unit, out _))
            {
                total += unit * entry.Value;
            }
        }

        return total;
    }

    private double NetValue(MapRun run, Dictionary<string, long> gained) => this.ValueOf(gained) - run.CostEx;

    /// What the map cost, as a positive number: the priced value of the negative side of its loot.
    ///
    /// Kept alongside the profit rather than folded into it so the map log can show spending and
    /// income as two columns; `ValueOf` already nets them out.
    private double CostOf(MapRun run, Dictionary<string, long> gained)
    {
        double total = 0;
        foreach (var entry in gained)
        {
            if (entry.Value < 0 && this.TryPriceItem(entry.Key, out double unit, out _))
            {
                total += unit * entry.Value;
            }
        }

        return -total + run.CostEx;
    }

    internal static CostPreset? ResolveCostPreset(IReadOnlyList<CostPreset> presets, string mapName) =>
        presets.FirstOrDefault(preset => preset.MapNames.Any(
            name => string.Equals(name, mapName.Trim(), StringComparison.OrdinalIgnoreCase)))
        ?? presets.FirstOrDefault(preset => preset.IsDefault);

    internal static double CostInEx(CostPreset preset, double divineRate) =>
        string.Equals(preset.Currency, "D", StringComparison.OrdinalIgnoreCase)
            ? preset.Amount * Math.Max(0, divineRate)
            : preset.Amount;

    internal static void ApplyCostPreset(MapRun run, CostPreset? preset, double divineRate)
    {
        run.CostPresetId = preset?.Id ?? string.Empty;
        run.CostName = preset?.Name ?? string.Empty;
        run.CostEx = preset == null ? 0 : CostInEx(preset, divineRate);
    }

    private bool TryPriceItem(string itemKey, out double unit, out string label)
    {
        var (rarity, path, renderArt) = SplitItemKey(itemKey);
        if (this.manualPricesEx.TryGetValue(itemKey, out unit) && unit > 0)
        {
            label = this.ResolveItemLabel(itemKey, rarity, path, renderArt);
            return true;
        }

        if (rarity == 3 && renderArt.Length > 0)
        {
            bool found = this.priceCache.TryGetPriceByArtId(renderArt, out unit) && unit > 0;
            label = this.priceCache.TryGetNameByArtId(renderArt, out var uniqueName) && uniqueName.Length > 0
                ? uniqueName
                : renderArt;
            label = this.LocalizeItemName(label);
            if (!found)
            {
                if (this.TryGetEmbeddedPrice(itemKey, out unit, out var embeddedLabel))
                {
                    label = embeddedLabel;
                    return true;
                }

                unit = 0;
            }

            return found;
        }

        string art = this.PriceKey(path);
        string variant = art + RarityVariant(rarity);
        bool priced = this.priceCache.TryGetPriceByArtId(variant, out unit) && unit > 0;
        if (!priced)
        {
            priced = this.priceCache.TryGetPriceByArtId(art, out unit) && unit > 0;
        }

        if (this.priceCache.TryGetNameByArtId(variant, out var name) && name.Length > 0)
        {
            label = name;
        }
        else if (this.priceCache.TryGetNameByArtId(art, out name) && name.Length > 0)
        {
            label = name;
        }
        else
        {
            label = this.itemBaseNames.TryGetValue(itemKey, out var baseName) && baseName.Length > 0 ? baseName : art;
        }

        label = this.LocalizeItemName(label);

        if (!priced)
        {
            if (this.TryGetEmbeddedPrice(itemKey, out unit, out var embeddedLabel))
            {
                label = embeddedLabel;
                return true;
            }

            unit = 0;
        }

        return priced;
    }

    private string ResolveItemLabel(string itemKey, int rarity, string path, string renderArt)
    {
        if (rarity == 3 && renderArt.Length > 0)
        {
            string uniqueLabel = this.priceCache.TryGetNameByArtId(renderArt, out var uniqueName) && uniqueName.Length > 0
                ? uniqueName
                : renderArt;
            return this.LocalizeItemName(uniqueLabel);
        }

        string art = this.PriceKey(path);
        string variant = art + RarityVariant(rarity);
        if (this.priceCache.TryGetNameByArtId(variant, out var name) && name.Length > 0)
        {
            return this.LocalizeItemName(name);
        }

        string label = this.priceCache.TryGetNameByArtId(art, out name) && name.Length > 0
            ? name
            : this.itemBaseNames.TryGetValue(itemKey, out var baseName) && baseName.Length > 0 ? baseName : art;
        return this.LocalizeItemName(label);
    }

    private string ResolveIconUrl(string itemKey)
    {
        var (rarity, path, renderArt) = SplitItemKey(itemKey);
        if (rarity == 3 && renderArt.Length > 0 && this.priceCache.TryGetIconUrlByArtId(renderArt, out var uniqueIcon))
        {
            return uniqueIcon;
        }

        string art = this.PriceKey(path);
        string variant = art + RarityVariant(rarity);
        if (this.priceCache.TryGetIconUrlByArtId(variant, out var iconUrl))
        {
            return iconUrl;
        }

        return this.priceCache.TryGetIconUrlByArtId(art, out iconUrl) ? iconUrl : string.Empty;
    }

    private string LocalizeItemName(string name) => this.chineseItemNames.TryGetValue(name.Trim(), out var translated) && translated.Length > 0
        ? translated
        : name;

    private bool TryGetEmbeddedPrice(string itemKey, out double unitEx, out string label)
    {
        unitEx = 0;
        label = string.Empty;
        if (!this.itemBaseNames.TryGetValue(itemKey, out var baseName) || string.IsNullOrWhiteSpace(baseName))
        {
            return false;
        }

        var match = EmbeddedPricePattern.Match(baseName);
        if (!match.Success || !double.TryParse(match.Groups["amount"].Value.Replace(',', '.'), NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out var amount) || amount <= 0)
        {
            return false;
        }

        bool divine = string.Equals(match.Groups["unit"].Value, "d", StringComparison.OrdinalIgnoreCase);
        if (divine && this.priceCache.DivineToExaltedRate <= 0)
        {
            return false;
        }

        unitEx = divine ? amount * this.priceCache.DivineToExaltedRate : amount;
        string displayName = baseName[..match.Index].Trim();
        label = this.LocalizeItemName(displayName.Length > 0 ? displayName : baseName);
        return true;
    }

    private string PriceKey(string path)
    {
        string segment = LastSegment(path);
        if (this.metaToArt.TryGetValue(segment, out var art))
        {
            return art;
        }

        int split = segment.Length;
        while (split > 0 && char.IsAsciiDigit(segment[split - 1]))
        {
            split--;
        }

        if (split > 0 && split < segment.Length && this.metaToArt.TryGetValue(segment[..split], out var stemArt))
        {
            return stemArt + segment[split..];
        }

        return segment;
    }

    private bool TrySnapshotInventory(out Dictionary<string, long> snapshot, bool strict = false)
    {
        snapshot = new Dictionary<string, long>(StringComparer.Ordinal);
        if (!this.TryReadMainInventory(out var items, strict))
        {
            return false;
        }

        foreach (var item in items)
        {
            snapshot.TryGetValue(item.Key, out long count);
            snapshot[item.Key] = count + item.Count;
        }

        return true;
    }

    private bool TryReadMainInventory(out List<(string Key, int Count)> items, bool strict = false)
    {
        items = new List<(string, int)>();
        if (!this.EnsureProcess())
        {
            return false;
        }

        var serverData = Core.States.InGameStateObject.CurrentAreaInstance.ServerDataObject;
        if (serverData.Address == IntPtr.Zero ||
            !this.TryReadStdVector(serverData.Address + this.settings.Offsets.ServerDataPlayerVector, out var playerFirst, out _))
        {
            return false;
        }

        IntPtr playerData = this.ReadPtr(playerFirst);
        if (playerData == IntPtr.Zero ||
            !this.TryReadStdVector(playerData + this.settings.Offsets.PlayerInventoriesVector, out var inventoryFirst, out var inventoryLast))
        {
            return false;
        }

        long inventoryCount = ((long)inventoryLast - (long)inventoryFirst) / this.settings.Offsets.InventoryArrayStride;
        if (inventoryCount is <= 0 or > 4096)
        {
            return false;
        }

        IntPtr inventory = IntPtr.Zero;
        for (long i = 0; i < inventoryCount; i++)
        {
            IntPtr entry = inventoryFirst + (int)(i * this.settings.Offsets.InventoryArrayStride);
            if (this.ReadInt(entry + this.settings.Offsets.InventoryArrayId) == this.settings.Offsets.MainInventoryId)
            {
                inventory = this.ReadPtr(entry + this.settings.Offsets.InventoryArrayPointer);
                break;
            }
        }

        if (inventory == IntPtr.Zero)
        {
            return false;
        }

        int width = this.ReadInt(inventory + this.settings.Offsets.InventoryTotalBoxes);
        int height = this.ReadInt(inventory + this.settings.Offsets.InventoryTotalBoxes + 4);
        if (width is <= 0 or > 100 || height is <= 0 or > 100)
        {
            return false;
        }

        if (!this.TryReadStdVector(inventory + this.settings.Offsets.InventoryItemList, out var itemFirst, out var itemLast))
        {
            return !strict;
        }

        long slotCount = ((long)itemLast - (long)itemFirst) / 8;
        if (slotCount is <= 0 or > 4096)
        {
            return !strict;
        }

        var seen = new HashSet<long>();
        for (long i = 0; i < slotCount; i++)
        {
            IntPtr inventoryItem = this.ReadPtr(itemFirst + (int)(i * 8));
            if (inventoryItem == IntPtr.Zero || !seen.Add(inventoryItem.ToInt64()))
            {
                continue;
            }

            IntPtr entity = this.ReadPtr(inventoryItem + this.settings.Offsets.InventoryItemItem);
            IntPtr details = this.ReadPtr(entity + this.settings.Offsets.EntityDetailsPointer);
            string path = this.ReadStdWString(details + this.settings.Offsets.EntityDetailsName);
            if (entity == IntPtr.Zero || details == IntPtr.Zero || path.Length == 0)
            {
                continue;
            }

            bool factsValid = this.ReadItemFacts(entity, details, out int stack, out int rarity, out string renderArt, out string baseName);
            if (strict && !factsValid) return false;
            string key = BuildItemKey(rarity, path, renderArt);
            if (baseName.Length > 0)
            {
                this.itemBaseNames[key] = baseName;
            }

            items.Add((key, stack));
        }

        return true;
    }

    private bool ReadItemFacts(IntPtr entity, IntPtr details, out int stack, out int rarity, out string renderArt, out string baseName)
    {
        stack = 1;
        rarity = 0;
        renderArt = string.Empty;
        baseName = string.Empty;

        if (!this.TryReadStdVector(entity + this.settings.Offsets.EntityComponentList, out var componentFirst, out var componentLast))
        {
            return false;
        }

        long componentCount = ((long)componentLast - (long)componentFirst) / 8;
        IntPtr lookup = this.ReadPtr(details + this.settings.Offsets.EntityComponentLookup);
        if (componentCount is <= 0 or > 256 || lookup == IntPtr.Zero ||
            !this.TryReadStdVector(lookup + this.settings.Offsets.ComponentLookupBucket, out var nameFirst, out var nameLast))
        {
            return false;
        }

        long nameCount = ((long)nameLast - (long)nameFirst) / this.settings.Offsets.ComponentNameIndexStride;
        if (nameCount is <= 0 or > 256)
        {
            return false;
        }

        int stackIndex = -1;
        int modsIndex = -1;
        int renderIndex = -1;
        int baseIndex = -1;
        for (long i = 0; i < nameCount && (stackIndex < 0 || modsIndex < 0 || renderIndex < 0 || baseIndex < 0); i++)
        {
            IntPtr record = nameFirst + (int)(i * this.settings.Offsets.ComponentNameIndexStride);
            string name = this.ReadCString(this.ReadPtr(record), 40);
            switch (name)
            {
                case "Stack": stackIndex = this.ReadInt(record + 8); break;
                case "Mods": modsIndex = this.ReadInt(record + 8); break;
                case "RenderItem": renderIndex = this.ReadInt(record + 8); break;
                case "Base": baseIndex = this.ReadInt(record + 8); break;
            }
        }

        if (baseIndex >= 0 && baseIndex < componentCount)
        {
            IntPtr baseComponent = this.ReadPtr(componentFirst + baseIndex * 8);
            if (baseComponent != IntPtr.Zero)
            {
                IntPtr displayNameRow = this.ReadPtr(baseComponent + this.settings.Offsets.BaseDisplayNameRow);
                if (displayNameRow != IntPtr.Zero)
                {
                    baseName = this.ReadUnicodeString(this.ReadPtr(displayNameRow + this.settings.Offsets.BaseDisplayName), 160);
                }
            }
        }

        if (stackIndex >= 0 && stackIndex < componentCount)
        {
            int value = this.ReadInt(this.ReadPtr(componentFirst + stackIndex * 8) + this.settings.Offsets.StackCount);
            if (value > 0)
            {
                stack = value;
            }
        }

        if (modsIndex >= 0 && modsIndex < componentCount)
        {
            int value = this.ReadInt(this.ReadPtr(componentFirst + modsIndex * 8) + this.settings.Offsets.ModsRarity);
            if (value is >= 0 and <= 3)
            {
                rarity = value;
            }
        }

        if (rarity == 3 && renderIndex >= 0 && renderIndex < componentCount)
        {
            string path = this.ReadStdWString(this.ReadPtr(componentFirst + renderIndex * 8) + this.settings.Offsets.RenderItemArt);
            renderArt = Path.GetFileNameWithoutExtension(path.Replace('/', Path.DirectorySeparatorChar));
        }
        return baseIndex >= 0;
    }

    private bool EnsureProcess()
    {
        int pid = (int)Core.Process.Pid;
        if (pid == 0)
        {
            this.ResetHandle();
            return false;
        }

        if (pid == this.handlePid && this.processHandle != IntPtr.Zero)
        {
            return true;
        }

        this.ResetHandle();
        this.processHandle = OpenProcess(ProcessVmRead | ProcessQueryInformation, false, pid);
        if (this.processHandle == IntPtr.Zero)
        {
            return false;
        }

        this.handlePid = pid;
        return true;
    }

    private void ResetHandle()
    {
        if (this.processHandle != IntPtr.Zero)
        {
            CloseHandle(this.processHandle);
            this.processHandle = IntPtr.Zero;
        }

        this.handlePid = 0;
    }

    private IntPtr ReadPtr(IntPtr address)
    {
        if (address == IntPtr.Zero)
        {
            return IntPtr.Zero;
        }

        var buffer = new byte[8];
        if (!ReadProcessMemory(this.processHandle, address, buffer, (uint)buffer.Length, out _))
        {
            return IntPtr.Zero;
        }

        long value = BitConverter.ToInt64(buffer);
        return value is >= 0x10000 and <= 0x7FFFFFFFFFFF ? (IntPtr)value : IntPtr.Zero;
    }

    private int ReadInt(IntPtr address)
    {
        if (address == IntPtr.Zero)
        {
            return 0;
        }

        var buffer = new byte[4];
        return ReadProcessMemory(this.processHandle, address, buffer, (uint)buffer.Length, out _)
            ? BitConverter.ToInt32(buffer)
            : 0;
    }

    private bool TryReadStdVector(IntPtr address, out IntPtr first, out IntPtr last)
    {
        first = IntPtr.Zero;
        last = IntPtr.Zero;
        var buffer = new byte[16];
        if (!ReadProcessMemory(this.processHandle, address, buffer, (uint)buffer.Length, out _))
        {
            return false;
        }

        first = (IntPtr)BitConverter.ToInt64(buffer, 0);
        last = (IntPtr)BitConverter.ToInt64(buffer, 8);
        long firstValue = (long)first;
        return firstValue is >= 0x10000 and <= 0x7FFFFFFFFFFF && (long)last >= firstValue;
    }

    private string ReadCString(IntPtr address, int maximumLength)
    {
        if (address == IntPtr.Zero)
        {
            return string.Empty;
        }

        var buffer = new byte[maximumLength];
        if (!ReadProcessMemory(this.processHandle, address, buffer, (uint)buffer.Length, out _))
        {
            return string.Empty;
        }

        int length = Array.IndexOf(buffer, (byte)0);
        return Encoding.ASCII.GetString(buffer, 0, length < 0 ? maximumLength : length);
    }

    private string ReadUnicodeString(IntPtr address, int maximumLength)
    {
        if (address == IntPtr.Zero || maximumLength <= 0)
        {
            return string.Empty;
        }

        var buffer = new byte[maximumLength * 2];
        if (!ReadProcessMemory(this.processHandle, address, buffer, (uint)buffer.Length, out _))
        {
            return string.Empty;
        }

        int byteLength = 0;
        while (byteLength + 1 < buffer.Length && (buffer[byteLength] != 0 || buffer[byteLength + 1] != 0))
        {
            byteLength += 2;
        }

        return byteLength == 0 ? string.Empty : Encoding.Unicode.GetString(buffer, 0, byteLength);
    }

    private string ReadStdWString(IntPtr address)
    {
        var header = new byte[0x20];
        if (address == IntPtr.Zero || !ReadProcessMemory(this.processHandle, address, header, (uint)header.Length, out _))
        {
            return string.Empty;
        }

        int length = BitConverter.ToInt32(header, 0x10);
        int capacity = BitConverter.ToInt32(header, 0x18);
        if (length is <= 0 or > 256 || capacity < length)
        {
            return string.Empty;
        }

        if (capacity < 8)
        {
            return Encoding.Unicode.GetString(header, 0, Math.Min(length * 2, 16));
        }

        long pointer = BitConverter.ToInt64(header, 0);
        if (pointer is < 0x10000 or > 0x7FFFFFFFFFFF)
        {
            return string.Empty;
        }

        var buffer = new byte[length * 2];
        return ReadProcessMemory(this.processHandle, (IntPtr)pointer, buffer, (uint)buffer.Length, out _)
            ? Encoding.Unicode.GetString(buffer)
            : string.Empty;
    }

    private void LoadMetaArt()
    {
        try
        {
            string path = Path.Combine(AppContext.BaseDirectory, "metaArt.json");
            if (File.Exists(path))
            {
                var data = Newtonsoft.Json.JsonConvert.DeserializeObject<Dictionary<string, string>>(File.ReadAllText(path));
                if (data != null)
                {
                    foreach (var entry in data)
                    {
                        this.metaToArt[entry.Key] = entry.Value;
                    }
                }
            }
        }
        catch
        {
        }
    }

    private void LoadChineseItemNames()
    {
        try
        {
            string path = Path.Combine(AppContext.BaseDirectory, "Localization", "item-names.zh-CN.json");
            if (!File.Exists(path))
            {
                return;
            }

            var values = JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(path));
            if (values == null)
            {
                return;
            }

            foreach (var entry in values)
            {
                if (!string.IsNullOrWhiteSpace(entry.Key) && !string.IsNullOrWhiteSpace(entry.Value))
                {
                    this.chineseItemNames[entry.Key.Trim()] = entry.Value.Trim();
                }
            }
        }
        catch
        {
        }
    }

    private void LoadManualPrices()
    {
        foreach (var entry in this.store.LoadManualPrices())
        {
            if (entry.Value > 0)
            {
                this.manualPricesEx[entry.Key] = entry.Value;
            }
        }
    }

    private void LoadActiveSession()
    {
        var state = this.store.LoadActiveSession();
        if (state != null)
        {
            this.sessionId = state.Id;
            this.sessionStartUtc = state.StartUtc == default ? DateTime.UtcNow : state.StartUtc;
            this.sessionPausedTime = TimeSpan.FromSeconds(Math.Max(0, state.PausedSeconds));
            this.trackingPaused = state.TrackingPaused;
            this.pauseStartedUtc = this.trackingPaused ? DateTime.UtcNow : null;
            this.runs.AddRange(state.Runs);
            foreach (var entry in state.ItemNames)
            {
                if (entry.Value.Length > 0)
                {
                    this.itemBaseNames[entry.Key] = entry.Value;
                }
            }

            // A restored session is only worth asking about when it actually recorded something; an
            // empty leftover would just be noise at startup.
            this.resumedSession = this.runs.Count > 0;
        }
    }

    private void SaveActiveSession()
    {
        var copies = this.runs.Select(run => new MapRun
        {
            Id = run.Id,
            SessionId = this.sessionId,
            Name = run.Name,
            Hash = run.Hash,
            AreaLevel = run.AreaLevel,
            StartedUtc = run.StartedUtc,
            EndedUtc = run.EndedUtc,
            ActiveTime = ReferenceEquals(run, this.current) ? this.CurrentLiveTime() : run.ActiveTime,
            ClosingDivineRate = run.ClosingDivineRate,
            FrozenProfitEx = run.FrozenProfitEx,
            CostPresetId = run.CostPresetId,
            CostName = run.CostName,
            CostEx = run.CostEx,
            Gained = new Dictionary<string, long>(ReferenceEquals(run, this.current) ? this.CurrentGainedLive() : run.Gained, StringComparer.Ordinal),
            Kills = (int[])run.Kills.Clone(),
        }).ToList();
        double pausedSeconds = this.sessionPausedTime.TotalSeconds;
        if (this.trackingPaused && this.pauseStartedUtc is { } pausedAt)
        {
            pausedSeconds += (DateTime.UtcNow - pausedAt).TotalSeconds;
        }

        var state = new ActiveSessionState
        {
            Id = this.sessionId,
            StartUtc = this.sessionStartUtc,
            League = this.settings.League,
            PausedSeconds = pausedSeconds,
            TrackingPaused = this.trackingPaused,
            ItemNames = new Dictionary<string, string>(this.itemBaseNames, StringComparer.Ordinal),
            Runs = copies,
        };
        this.store.SaveActiveSession(state, run => this.BuildLoot(run.Gained, run));
    }

    private void DisposeSession()
    {
        // Deliberately SAVES instead of archiving.
        //
        // Archiving on exit closed the session, so the next launch found no active session and
        // silently started a new one. Leaving it open is what makes "continue the previous session"
        // possible, and it is also the safer default: the panel asks, and ignoring the question
        // keeps the session rather than throwing it away.
        this.SaveActiveSession();
    }

    /// Closes the session out for good: ends its open map, freezes per-map profits, and flips its
    /// status to archived so the next launch does not offer to resume it. Only reached by an
    /// explicit "new session".
    private void ArchiveSession()
    {
        if (this.runs.Count == 0)
        {
            return;
        }

        var state = new ActiveSessionState
        {
            Id = this.sessionId,
            StartUtc = this.sessionStartUtc,
            League = this.settings.League,
            PausedSeconds = this.sessionPausedTime.TotalSeconds,
            TrackingPaused = false,
            ItemNames = new Dictionary<string, string>(this.itemBaseNames, StringComparer.Ordinal),
            Runs = this.runs,
        };
        foreach (var run in state.Runs)
        {
            run.EndedUtc ??= DateTime.UtcNow;
            run.ClosingDivineRate = run.ClosingDivineRate > 0 ? run.ClosingDivineRate : this.priceCache.DivineToExaltedRate;
            run.FrozenProfitEx ??= this.NetValue(run, run.Gained);
        }
        this.store.ArchiveSession(state, run => this.BuildLoot(run.Gained, run));
    }

    internal static Dictionary<string, long> Diff(Dictionary<string, long> current, Dictionary<string, long> baseline)
    {
        var result = new Dictionary<string, long>(StringComparer.Ordinal);
        foreach (var entry in current)
        {
            baseline.TryGetValue(entry.Key, out long previous);
            long delta = entry.Value - previous;
            if (delta != 0)
            {
                result[entry.Key] = delta;
            }
        }

        foreach (var entry in baseline)
        {
            if (!current.ContainsKey(entry.Key))
            {
                result[entry.Key] = -entry.Value;
            }
        }

        return result;
    }

    private static void MergeInto(Dictionary<string, long> target, Dictionary<string, long> delta)
    {
        foreach (var entry in delta)
        {
            target.TryGetValue(entry.Key, out long previous);
            long value = previous + entry.Value;
            if (value == 0)
            {
                target.Remove(entry.Key);
            }
            else
            {
                target[entry.Key] = value;
            }
        }
    }

    private static string BuildItemKey(int rarity, string path, string renderArt)
    {
        string prefix = $"{(char)('0' + (rarity & 3))}{ItemKeySeparator}{path}";
        return renderArt.Length == 0 ? prefix : $"{prefix}{ItemKeySeparator}{renderArt}";
    }

    private static (int Rarity, string Path, string RenderArt) SplitItemKey(string key)
    {
        int first = key.IndexOf(ItemKeySeparator);
        if (first < 0)
        {
            return (0, key, string.Empty);
        }

        int rarity = first == 1 && key[0] is >= '0' and <= '3' ? key[0] - '0' : 0;
        string rest = key[(first + 1)..];
        int second = rest.IndexOf(ItemKeySeparator);
        return second < 0 ? (rarity, rest, string.Empty) : (rarity, rest[..second], rest[(second + 1)..]);
    }

    private static string RarityVariant(int rarity) => rarity switch
    {
        1 => "Magic",
        2 => "Rare",
        3 => "Unique",
        _ => "Normal",
    };

    private static string LastSegment(string path)
    {
        int index = path.LastIndexOf('/');
        return index >= 0 && index < path.Length - 1 ? path[(index + 1)..] : path;
    }

    private sealed class MonsterTally(int rarityIndex, bool seenAlive)
    {
        public int RarityIndex { get; } = rarityIndex;
        public bool SeenAlive { get; set; } = seenAlive;
        public bool Tallied { get; set; }
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint access, bool inheritHandle, int processId);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool ReadProcessMemory(IntPtr process, IntPtr address, byte[] buffer, uint size, out int bytesRead);
}
