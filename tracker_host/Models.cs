using LootTracker;

namespace LootTracker.App;

internal sealed class MapRun
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string SessionId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Hash { get; set; } = string.Empty;
    public int AreaLevel { get; set; }
    public DateTime StartedUtc { get; set; } = DateTime.UtcNow;
    public DateTime? EndedUtc { get; set; }
    public TimeSpan ActiveTime { get; set; }
    public double ClosingDivineRate { get; set; }
    public double? FrozenProfitEx { get; set; }
    public string CostPresetId { get; set; } = string.Empty;
    public string CostName { get; set; } = string.Empty;
    public double CostEx { get; set; }
    public Dictionary<string, long> Gained { get; set; } = new(StringComparer.Ordinal);
    public int[] Kills { get; set; } = new int[4];
}

internal sealed class CostPreset
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Name { get; set; } = string.Empty;
    public double Amount { get; set; }
    public string Currency { get; set; } = "E";
    public List<string> MapNames { get; set; } = new();
    public bool IsDefault { get; set; }

    /// Legacy v1 field. Normalization moves it into MapNames so previously saved presets continue
    /// matching after the multi-map upgrade.
    public string MapName { get; set; } = string.Empty;
}

internal sealed record LootLine(string Key, string Name, long Count, double UnitEx, double TotalEx, bool Priced, string IconUrl);

internal sealed record MapSummary(
    string Id,
    string Name,
    int AreaLevel,
    TimeSpan ActiveTime,
    double ProfitEx,
    double CostEx,
    int LootTypes,
    int[] Kills,
    bool Active);

internal sealed record TrackerSnapshot(
    string ActiveSessionId,
    /// True when the session was restored from a previous run. The panel uses this to ask whether to
    /// keep it instead of silently appending to it (or silently discarding it).
    bool ResumedSession,
    DateTime SessionStartedUtc,
    bool GameConnected,
    bool InMap,
    bool TrackingPaused,
    string Status,
    string MapName,
    string CurrentCostPresetId,
    string CurrentCostName,
    double CurrentCostEx,
    TimeSpan MapTime,
    TimeSpan SessionTime,
    /// Total time spent inside maps across the session, which is what an average map time divides.
    TimeSpan ActiveTime,
    double CurrentProfitEx,
    double TotalProfitEx,
    double PerHourEx,
    double DivineRate,
    int MapCount,
    int[] Kills,
    IReadOnlyList<LootLine> Loot,
    IReadOnlyList<MapSummary> Maps,
    DateTime PriceUpdatedUtc,
    PriceSyncStatus PriceStatus,
    string PriceError);

internal sealed class ActiveSessionState
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public DateTime StartUtc { get; set; }
    public string League { get; set; } = string.Empty;
    public double PausedSeconds { get; set; }
    public bool TrackingPaused { get; set; }
    public Dictionary<string, string> ItemNames { get; set; } = new(StringComparer.Ordinal);
    public List<MapRun> Runs { get; set; } = new();
}
