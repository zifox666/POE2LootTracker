using System.Text.Json;
using Microsoft.Data.Sqlite;

namespace LootTracker.App;

internal sealed class SqliteStore : IDisposable
{
    private readonly SqliteConnection connection;
    private readonly object gate = new();

    public SqliteStore(string path)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        connection = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = path,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Cache = SqliteCacheMode.Shared,
            Pooling = false,
        }.ToString());
        connection.Open();
        Initialize();
    }

    public string? GetSetting(string key)
    {
        lock (gate)
        {
            using var command = connection.CreateCommand();
            command.CommandText = "SELECT value_json FROM app_settings WHERE key = $key";
            command.Parameters.AddWithValue("$key", key);
            return command.ExecuteScalar() as string;
        }
    }

    public void SetSetting(string key, string value)
    {
        lock (gate)
        {
            using var command = connection.CreateCommand();
            command.CommandText = """
                INSERT INTO app_settings(key, value_json, updated_utc) VALUES($key, $value, $now)
                ON CONFLICT(key) DO UPDATE SET value_json = excluded.value_json, updated_utc = excluded.updated_utc
                """;
            command.Parameters.AddWithValue("$key", key);
            command.Parameters.AddWithValue("$value", value);
            command.Parameters.AddWithValue("$now", Utc(DateTime.UtcNow));
            command.ExecuteNonQuery();
        }
    }

    public Dictionary<string, double> LoadManualPrices()
    {
        lock (gate)
        {
            var result = new Dictionary<string, double>(StringComparer.Ordinal);
            using var command = connection.CreateCommand();
            command.CommandText = "SELECT item_key, price_ex FROM manual_prices";
            using var reader = command.ExecuteReader();
            while (reader.Read()) result[reader.GetString(0)] = reader.GetDouble(1);
            return result;
        }
    }

    public void SetManualPrice(string itemKey, double? priceEx)
    {
        lock (gate)
        {
            using var command = connection.CreateCommand();
            if (priceEx is null)
            {
                command.CommandText = "DELETE FROM manual_prices WHERE item_key = $key";
            }
            else
            {
                command.CommandText = """
                    INSERT INTO manual_prices(item_key, price_ex, updated_utc) VALUES($key, $price, $now)
                    ON CONFLICT(item_key) DO UPDATE SET price_ex = excluded.price_ex, updated_utc = excluded.updated_utc
                    """;
                command.Parameters.AddWithValue("$price", priceEx.Value);
                command.Parameters.AddWithValue("$now", Utc(DateTime.UtcNow));
            }
            command.Parameters.AddWithValue("$key", itemKey);
            command.ExecuteNonQuery();
        }
    }

    public void SaveOffsetProfile(MemoryOffsetProfile profile, string validation = "unverified")
    {
        lock (gate)
        using (var transaction = connection.BeginTransaction())
        {
            foreach (var pair in profile.AsDictionary())
            {
                using var command = connection.CreateCommand();
                command.Transaction = transaction;
                command.CommandText = """
                    INSERT INTO memory_offset_profiles(name, value, default_value, validation, updated_utc)
                    VALUES($name, $value, $default, $validation, $now)
                    ON CONFLICT(name) DO UPDATE SET value = excluded.value, validation = excluded.validation, updated_utc = excluded.updated_utc
                    """;
                command.Parameters.AddWithValue("$name", pair.Key);
                command.Parameters.AddWithValue("$value", pair.Value);
                command.Parameters.AddWithValue("$default", MemoryOffsetProfile.Defaults().AsDictionary()[pair.Key]);
                command.Parameters.AddWithValue("$validation", validation);
                command.Parameters.AddWithValue("$now", Utc(DateTime.UtcNow));
                command.ExecuteNonQuery();
            }
            transaction.Commit();
        }
    }

    public ActiveSessionState? LoadActiveSession()
    {
        lock (gate)
        {
            using var sessionCommand = connection.CreateCommand();
            sessionCommand.CommandText = """
                SELECT id, started_utc, paused_seconds, tracking_paused, item_names_json
                FROM sessions WHERE status = 'active' ORDER BY started_utc DESC LIMIT 1
                """;
            using var reader = sessionCommand.ExecuteReader();
            if (!reader.Read()) return null;
            var state = new ActiveSessionState
            {
                Id = reader.GetString(0),
                StartUtc = DateTime.Parse(reader.GetString(1), null, System.Globalization.DateTimeStyles.RoundtripKind),
                PausedSeconds = reader.GetDouble(2),
                TrackingPaused = reader.GetInt32(3) != 0,
                ItemNames = JsonSerializer.Deserialize<Dictionary<string, string>>(reader.GetString(4)) ?? new(),
            };
            reader.Close();

            using var maps = connection.CreateCommand();
            maps.CommandText = """
                SELECT id, name, area_hash, area_level, started_utc, ended_utc, active_ms,
                       closing_divine_rate, kills_normal, kills_magic, kills_rare, kills_unique, profit_ex,
                       cost_preset_id, cost_name, cost_ex
                FROM map_runs WHERE session_id = $session ORDER BY started_utc
                """;
            maps.Parameters.AddWithValue("$session", state.Id);
            using var mapReader = maps.ExecuteReader();
            while (mapReader.Read())
            {
                var run = new MapRun
                {
                    Id = mapReader.GetString(0),
                    SessionId = state.Id,
                    Name = mapReader.GetString(1),
                    Hash = mapReader.GetString(2),
                    AreaLevel = mapReader.GetInt32(3),
                    StartedUtc = DateTime.Parse(mapReader.GetString(4), null, System.Globalization.DateTimeStyles.RoundtripKind),
                    EndedUtc = mapReader.IsDBNull(5) ? null : DateTime.Parse(mapReader.GetString(5), null, System.Globalization.DateTimeStyles.RoundtripKind),
                    ActiveTime = TimeSpan.FromMilliseconds(mapReader.GetInt64(6)),
                    ClosingDivineRate = mapReader.GetDouble(7),
                    Kills = [mapReader.GetInt32(8), mapReader.GetInt32(9), mapReader.GetInt32(10), mapReader.GetInt32(11)],
                    FrozenProfitEx = mapReader.IsDBNull(12) ? null : mapReader.GetDouble(12),
                    CostPresetId = mapReader.GetString(13),
                    CostName = mapReader.GetString(14),
                    CostEx = mapReader.GetDouble(15),
                };
                state.Runs.Add(run);
            }
            mapReader.Close();
            foreach (var run in state.Runs) run.Gained = LoadLootCounts(run.Id);
            return state;
        }
    }

    public void SaveActiveSession(ActiveSessionState state, Func<MapRun, IReadOnlyList<LootLine>> lootBuilder)
    {
        lock (gate)
        using (var transaction = connection.BeginTransaction())
        {
            UpsertSession(state, "active", null, transaction);
            foreach (var run in state.Runs)
            {
                bool frozen = IsFrozen(run.Id, transaction);
                UpsertMap(run, state.Id, transaction);
                if (!frozen || run.EndedUtc is null) ReplaceLoot(run.Id, run.Gained, lootBuilder(run), transaction);
            }
            transaction.Commit();
        }
    }

    public void ArchiveSession(ActiveSessionState state, Func<MapRun, IReadOnlyList<LootLine>> lootBuilder)
    {
        lock (gate)
        using (var transaction = connection.BeginTransaction())
        {
            foreach (var run in state.Runs)
            {
                bool frozen = IsFrozen(run.Id, transaction);
                run.EndedUtc ??= DateTime.UtcNow;
                UpsertMap(run, state.Id, transaction);
                if (!frozen) ReplaceLoot(run.Id, run.Gained, lootBuilder(run), transaction);
            }
            UpsertSession(state, "archived", DateTime.UtcNow, transaction);
            transaction.Commit();
        }
    }

    public IReadOnlyList<object> ListSessions()
    {
        lock (gate)
        {
            var rows = new List<object>();
            using var command = connection.CreateCommand();
            command.CommandText = """
                SELECT s.id, s.started_utc, s.ended_utc, s.status, s.league,
                       COUNT(m.id), COALESCE(SUM(m.active_ms), 0), COALESCE(SUM(m.profit_ex), 0)
                FROM sessions s LEFT JOIN map_runs m ON m.session_id = s.id
                GROUP BY s.id ORDER BY s.started_utc DESC
                """;
            using var reader = command.ExecuteReader();
            while (reader.Read()) rows.Add(new
            {
                id = reader.GetString(0), startedUtc = reader.GetString(1), endedUtc = reader.IsDBNull(2) ? null : reader.GetString(2),
                status = reader.GetString(3), league = reader.GetString(4), mapCount = reader.GetInt32(5),
                activeMs = reader.GetInt64(6), profitEx = reader.GetDouble(7),
            });
            return rows;
        }
    }

    public IReadOnlyList<object> ListMaps(string sessionId)
    {
        lock (gate)
        {
            var rows = new List<object>();
            using var command = connection.CreateCommand();
            command.CommandText = """
                SELECT m.id, m.name, m.area_level, m.started_utc, m.ended_utc, m.active_ms, m.profit_ex,
                       m.kills_normal, m.kills_magic, m.kills_rare, m.kills_unique,
                       COALESCE((SELECT -SUM(l.total_ex) FROM loot_entries l
                                 WHERE l.map_id = m.id AND l.total_ex < 0), 0) AS cost_ex
                FROM map_runs m WHERE m.session_id = $session ORDER BY m.started_utc DESC
                """;
            command.Parameters.AddWithValue("$session", sessionId);
            using var reader = command.ExecuteReader();
            while (reader.Read()) rows.Add(new
            {
                id = reader.GetString(0), name = reader.GetString(1), areaLevel = reader.GetInt32(2),
                startedUtc = reader.GetString(3), endedUtc = reader.IsDBNull(4) ? null : reader.GetString(4),
                activeMs = reader.GetInt64(5), profitEx = reader.GetDouble(6),
                kills = new[] { reader.GetInt32(7), reader.GetInt32(8), reader.GetInt32(9), reader.GetInt32(10) },
                // Same sign convention as the live snapshot: a positive figure for what the map consumed.
                costEx = reader.GetDouble(11),
            });
            return rows;
        }
    }

    public object? GetMapDetail(string mapId)
    {
        lock (gate)
        {
            using var command = connection.CreateCommand();
            command.CommandText = """
                SELECT id, name, area_level, active_ms, profit_ex, closing_divine_rate,
                       kills_normal, kills_magic, kills_rare, kills_unique
                FROM map_runs WHERE id = $id
                """;
            command.Parameters.AddWithValue("$id", mapId);
            using var reader = command.ExecuteReader();
            if (!reader.Read()) return null;
            var header = new
            {
                id = reader.GetString(0), name = reader.GetString(1), areaLevel = reader.GetInt32(2),
                activeMs = reader.GetInt64(3), profitEx = reader.GetDouble(4), divineRate = reader.GetDouble(5),
                kills = new[] { reader.GetInt32(6), reader.GetInt32(7), reader.GetInt32(8), reader.GetInt32(9) },
            };
            reader.Close();
            using var loot = connection.CreateCommand();
            loot.CommandText = """
                SELECT item_key, display_name, count, unit_ex, total_ex, priced, icon_url, rarity
                FROM loot_entries WHERE map_id = $id ORDER BY total_ex DESC
                """;
            loot.Parameters.AddWithValue("$id", mapId);
            var items = new List<object>();
            using var lootReader = loot.ExecuteReader();
            while (lootReader.Read()) items.Add(new
            {
                key = lootReader.GetString(0), name = lootReader.GetString(1), count = lootReader.GetInt64(2),
                unitEx = lootReader.GetDouble(3), totalEx = lootReader.GetDouble(4), priced = lootReader.GetInt32(5) != 0,
                iconUrl = lootReader.GetString(6), rarity = lootReader.GetInt32(7),
            });
            return new { map = header, loot = items };
        }
    }

    /// Every cached price for a league, with its manual override attached.
    ///
    /// Filtering, sorting and limiting deliberately live in LootTrackerEngine.ListMarketPrices
    /// instead of here: the search box has to match the *localized* name, and a query for a Chinese
    /// item name would never match the English poe.ninja name this table stores.
    public IReadOnlyList<MarketPriceLine> ListMarketPrices(string league)
    {
        lock (gate)
        {
            var rows = new List<MarketPriceLine>();
            using var command = connection.CreateCommand();
            command.CommandText = """
                SELECT p.item_key, p.display_name, p.price_ex, p.icon_url, p.fetched_utc, p.category, m.price_ex
                FROM market_prices p LEFT JOIN manual_prices m ON m.item_key = p.item_key
                WHERE p.league = $league
                ORDER BY p.price_ex DESC
                """;
            command.Parameters.AddWithValue("$league", league);
            using var reader = command.ExecuteReader();
            while (reader.Read()) rows.Add(new MarketPriceLine(
                reader.GetString(0), reader.GetString(1), reader.GetDouble(2), reader.GetString(3),
                reader.GetString(4), reader.GetString(5),
                reader.IsDBNull(6) ? (double?)null : reader.GetDouble(6)));
            return rows;
        }
    }

    public void ReplaceMarketPrices(string league, IEnumerable<MarketPriceRow> prices, DateTime fetchedUtc, double divineRate)
    {
        lock (gate)
        using (var transaction = connection.BeginTransaction())
        {
            using (var delete = connection.CreateCommand())
            {
                delete.Transaction = transaction;
                delete.CommandText = "DELETE FROM market_prices WHERE league = $league";
                delete.Parameters.AddWithValue("$league", league);
                delete.ExecuteNonQuery();
            }
            foreach (var price in prices)
            {
                using var insert = connection.CreateCommand();
                insert.Transaction = transaction;
                insert.CommandText = """
                    INSERT INTO market_prices(league, item_key, display_name, price_ex, icon_url, fetched_utc, lookup_kind, category)
                    VALUES($league, $key, $name, $price, $icon, $fetched, $kind, $category)
                    """;
                insert.Parameters.AddWithValue("$league", league);
                insert.Parameters.AddWithValue("$key", price.Key);
                insert.Parameters.AddWithValue("$name", price.Name);
                insert.Parameters.AddWithValue("$price", price.PriceEx);
                insert.Parameters.AddWithValue("$icon", price.IconUrl);
                insert.Parameters.AddWithValue("$fetched", Utc(fetchedUtc));
                insert.Parameters.AddWithValue("$kind", price.Kind);
                insert.Parameters.AddWithValue("$category", price.Category);
                insert.ExecuteNonQuery();
            }
            using (var sync = connection.CreateCommand())
            {
                sync.Transaction = transaction;
                sync.CommandText = """
                    INSERT INTO market_sync(league, divine_rate, fetched_utc) VALUES($league, $rate, $fetched)
                    ON CONFLICT(league) DO UPDATE SET divine_rate=excluded.divine_rate, fetched_utc=excluded.fetched_utc
                    """;
                sync.Parameters.AddWithValue("$league", league);
                sync.Parameters.AddWithValue("$rate", divineRate);
                sync.Parameters.AddWithValue("$fetched", Utc(fetchedUtc));
                sync.ExecuteNonQuery();
            }
            transaction.Commit();
        }
    }

    public MarketSnapshot? LoadMarketSnapshot(string league)
    {
        lock (gate)
        {
            using var sync = connection.CreateCommand();
            sync.CommandText = "SELECT divine_rate, fetched_utc FROM market_sync WHERE league = $league";
            sync.Parameters.AddWithValue("$league", league);
            using var syncReader = sync.ExecuteReader();
            if (!syncReader.Read()) return null;
            double rate = syncReader.GetDouble(0);
            DateTime fetched = DateTime.Parse(syncReader.GetString(1), null, System.Globalization.DateTimeStyles.RoundtripKind);
            syncReader.Close();
            var prices = new List<MarketPriceRow>();
            using var command = connection.CreateCommand();
            command.CommandText = "SELECT item_key, display_name, price_ex, icon_url, lookup_kind, category FROM market_prices WHERE league = $league";
            command.Parameters.AddWithValue("$league", league);
            using var reader = command.ExecuteReader();
            while (reader.Read()) prices.Add(new MarketPriceRow(reader.GetString(0), reader.GetString(1), reader.GetDouble(2), reader.GetString(3), reader.GetString(4), reader.GetString(5)));
            return new MarketSnapshot(rate, fetched, prices);
        }
    }

    public object? GetWindowState(string key)
    {
        lock (gate)
        {
            using var command = connection.CreateCommand();
            command.CommandText = "SELECT x, y, width, height FROM window_states WHERE window_key = $key";
            command.Parameters.AddWithValue("$key", key);
            using var reader = command.ExecuteReader();
            return reader.Read() ? new { x = reader.GetDouble(0), y = reader.GetDouble(1), width = reader.GetDouble(2), height = reader.GetDouble(3) } : null;
        }
    }

    public void SetWindowState(string key, double x, double y, double width, double height)
    {
        if (string.IsNullOrWhiteSpace(key) || width <= 0 || height <= 0) return;
        lock (gate)
        {
            using var command = connection.CreateCommand();
            command.CommandText = """
                INSERT INTO window_states(window_key, x, y, width, height, updated_utc)
                VALUES($key, $x, $y, $width, $height, $now)
                ON CONFLICT(window_key) DO UPDATE SET x=excluded.x, y=excluded.y, width=excluded.width,
                  height=excluded.height, updated_utc=excluded.updated_utc
                """;
            command.Parameters.AddWithValue("$key", key);
            command.Parameters.AddWithValue("$x", x);
            command.Parameters.AddWithValue("$y", y);
            command.Parameters.AddWithValue("$width", width);
            command.Parameters.AddWithValue("$height", height);
            command.Parameters.AddWithValue("$now", Utc(DateTime.UtcNow));
            command.ExecuteNonQuery();
        }
    }

    public void Dispose() => connection.Dispose();

    private void Initialize()
    {
        using var command = connection.CreateCommand();
        command.CommandText = """
            PRAGMA journal_mode = WAL;
            PRAGMA foreign_keys = ON;
            CREATE TABLE IF NOT EXISTS schema_info(version INTEGER NOT NULL);
            INSERT INTO schema_info(version) SELECT 1 WHERE NOT EXISTS(SELECT 1 FROM schema_info);
            CREATE TABLE IF NOT EXISTS app_settings(key TEXT PRIMARY KEY, value_json TEXT NOT NULL, updated_utc TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS sessions(
              id TEXT PRIMARY KEY, started_utc TEXT NOT NULL, ended_utc TEXT, status TEXT NOT NULL,
              league TEXT NOT NULL DEFAULT '', paused_seconds REAL NOT NULL DEFAULT 0,
              tracking_paused INTEGER NOT NULL DEFAULT 0, item_names_json TEXT NOT NULL DEFAULT '{}');
            CREATE TABLE IF NOT EXISTS map_runs(
              id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
              name TEXT NOT NULL, area_hash TEXT NOT NULL, area_level INTEGER NOT NULL,
              started_utc TEXT NOT NULL, ended_utc TEXT, active_ms INTEGER NOT NULL DEFAULT 0,
              profit_ex REAL NOT NULL DEFAULT 0, closing_divine_rate REAL NOT NULL DEFAULT 0,
              kills_normal INTEGER NOT NULL DEFAULT 0, kills_magic INTEGER NOT NULL DEFAULT 0,
              kills_rare INTEGER NOT NULL DEFAULT 0, kills_unique INTEGER NOT NULL DEFAULT 0,
              cost_preset_id TEXT NOT NULL DEFAULT '', cost_name TEXT NOT NULL DEFAULT '', cost_ex REAL NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS loot_entries(
              map_id TEXT NOT NULL REFERENCES map_runs(id) ON DELETE CASCADE, item_key TEXT NOT NULL,
              display_name TEXT NOT NULL, rarity INTEGER NOT NULL DEFAULT 0, count INTEGER NOT NULL,
              unit_ex REAL NOT NULL, total_ex REAL NOT NULL, priced INTEGER NOT NULL, icon_url TEXT NOT NULL DEFAULT '',
              PRIMARY KEY(map_id, item_key));
            CREATE TABLE IF NOT EXISTS market_prices(
              league TEXT NOT NULL, item_key TEXT NOT NULL, display_name TEXT NOT NULL,
              price_ex REAL NOT NULL, icon_url TEXT NOT NULL DEFAULT '', fetched_utc TEXT NOT NULL,
              lookup_kind TEXT NOT NULL DEFAULT 'art', category TEXT NOT NULL DEFAULT '',
              PRIMARY KEY(league, item_key));
            CREATE TABLE IF NOT EXISTS market_sync(
              league TEXT PRIMARY KEY, divine_rate REAL NOT NULL, fetched_utc TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS manual_prices(item_key TEXT PRIMARY KEY, price_ex REAL NOT NULL, updated_utc TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS memory_offset_profiles(
              name TEXT PRIMARY KEY, value INTEGER NOT NULL, default_value INTEGER NOT NULL,
              validation TEXT NOT NULL, updated_utc TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS window_states(
              window_key TEXT PRIMARY KEY, x REAL NOT NULL, y REAL NOT NULL, width REAL NOT NULL, height REAL NOT NULL,
              updated_utc TEXT NOT NULL);
            CREATE INDEX IF NOT EXISTS idx_maps_session ON map_runs(session_id, started_utc DESC);
            CREATE INDEX IF NOT EXISTS idx_loot_map ON loot_entries(map_id);
            """;
        command.ExecuteNonQuery();
        try
        {
            using var migration = connection.CreateCommand();
            migration.CommandText = "ALTER TABLE market_prices ADD COLUMN lookup_kind TEXT NOT NULL DEFAULT 'art';";
            migration.ExecuteNonQuery();
        }
        catch (SqliteException exception) when (exception.SqliteErrorCode == 1)
        {
        }
        try
        {
            using var migration = connection.CreateCommand();
            migration.CommandText = "ALTER TABLE market_prices ADD COLUMN category TEXT NOT NULL DEFAULT '';";
            migration.ExecuteNonQuery();
        }
        catch (SqliteException exception) when (exception.SqliteErrorCode == 1)
        {
        }
        foreach (var statement in new[]
        {
            "ALTER TABLE map_runs ADD COLUMN cost_preset_id TEXT NOT NULL DEFAULT '';",
            "ALTER TABLE map_runs ADD COLUMN cost_name TEXT NOT NULL DEFAULT '';",
            "ALTER TABLE map_runs ADD COLUMN cost_ex REAL NOT NULL DEFAULT 0;",
        })
        {
            try
            {
                using var migration = connection.CreateCommand();
                migration.CommandText = statement;
                migration.ExecuteNonQuery();
            }
            catch (SqliteException exception) when (exception.SqliteErrorCode == 1)
            {
            }
        }
        using var version = connection.CreateCommand();
        version.CommandText = "UPDATE schema_info SET version = 4";
        version.ExecuteNonQuery();
    }

    private Dictionary<string, long> LoadLootCounts(string mapId)
    {
        var result = new Dictionary<string, long>(StringComparer.Ordinal);
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT item_key, count FROM loot_entries WHERE map_id = $id AND item_key NOT LIKE $costPrefix";
        command.Parameters.AddWithValue("$id", mapId);
        command.Parameters.AddWithValue("$costPrefix", LootTrackerEngine.CostEntryPrefix + "%");
        using var reader = command.ExecuteReader();
        while (reader.Read()) result[reader.GetString(0)] = reader.GetInt64(1);
        return result;
    }

    private void UpsertSession(ActiveSessionState state, string status, DateTime? endedUtc, SqliteTransaction transaction)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO sessions(id, started_utc, ended_utc, status, league, paused_seconds, tracking_paused, item_names_json)
            VALUES($id, $started, $ended, $status, $league, $paused, $tracking, $names)
            ON CONFLICT(id) DO UPDATE SET ended_utc = excluded.ended_utc, status = excluded.status,
              league = excluded.league, paused_seconds = excluded.paused_seconds,
              tracking_paused = excluded.tracking_paused, item_names_json = excluded.item_names_json
            """;
        command.Parameters.AddWithValue("$id", state.Id);
        command.Parameters.AddWithValue("$started", Utc(state.StartUtc));
        command.Parameters.AddWithValue("$ended", endedUtc is null ? DBNull.Value : Utc(endedUtc.Value));
        command.Parameters.AddWithValue("$status", status);
        command.Parameters.AddWithValue("$league", state.League);
        command.Parameters.AddWithValue("$paused", state.PausedSeconds);
        command.Parameters.AddWithValue("$tracking", state.TrackingPaused ? 1 : 0);
        command.Parameters.AddWithValue("$names", JsonSerializer.Serialize(state.ItemNames));
        command.ExecuteNonQuery();
    }

    private void UpsertMap(MapRun run, string sessionId, SqliteTransaction transaction)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO map_runs(id, session_id, name, area_hash, area_level, started_utc, ended_utc, active_ms,
              profit_ex, closing_divine_rate, kills_normal, kills_magic, kills_rare, kills_unique,
              cost_preset_id, cost_name, cost_ex)
            VALUES($id, $session, $name, $hash, $level, $started, $ended, $active, $profit, $rate, $n, $m, $r, $u,
              $costPreset, $costName, $costEx)
            ON CONFLICT(id) DO UPDATE SET ended_utc = excluded.ended_utc, active_ms = excluded.active_ms,
              profit_ex = CASE WHEN excluded.ended_utc IS NULL OR map_runs.ended_utc IS NULL THEN excluded.profit_ex ELSE map_runs.profit_ex END,
              closing_divine_rate = excluded.closing_divine_rate, kills_normal = excluded.kills_normal,
              kills_magic = excluded.kills_magic, kills_rare = excluded.kills_rare, kills_unique = excluded.kills_unique,
              cost_preset_id = excluded.cost_preset_id, cost_name = excluded.cost_name, cost_ex = excluded.cost_ex
            """;
        command.Parameters.AddWithValue("$id", run.Id);
        command.Parameters.AddWithValue("$session", sessionId);
        command.Parameters.AddWithValue("$name", run.Name);
        command.Parameters.AddWithValue("$hash", run.Hash);
        command.Parameters.AddWithValue("$level", run.AreaLevel);
        command.Parameters.AddWithValue("$started", Utc(run.StartedUtc));
        command.Parameters.AddWithValue("$ended", run.EndedUtc is null ? DBNull.Value : Utc(run.EndedUtc.Value));
        command.Parameters.AddWithValue("$active", (long)run.ActiveTime.TotalMilliseconds);
        command.Parameters.AddWithValue("$profit", run.FrozenProfitEx ?? 0);
        command.Parameters.AddWithValue("$rate", run.ClosingDivineRate);
        command.Parameters.AddWithValue("$n", run.Kills.ElementAtOrDefault(0));
        command.Parameters.AddWithValue("$m", run.Kills.ElementAtOrDefault(1));
        command.Parameters.AddWithValue("$r", run.Kills.ElementAtOrDefault(2));
        command.Parameters.AddWithValue("$u", run.Kills.ElementAtOrDefault(3));
        command.Parameters.AddWithValue("$costPreset", run.CostPresetId);
        command.Parameters.AddWithValue("$costName", run.CostName);
        command.Parameters.AddWithValue("$costEx", run.CostEx);
        command.ExecuteNonQuery();
    }

    private bool IsFrozen(string mapId, SqliteTransaction transaction)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = "SELECT ended_utc IS NOT NULL FROM map_runs WHERE id = $id";
        command.Parameters.AddWithValue("$id", mapId);
        return command.ExecuteScalar() is long value && value != 0;
    }

    private void ReplaceLoot(string mapId, Dictionary<string, long> counts, IReadOnlyList<LootLine> lines, SqliteTransaction transaction)
    {
        using (var delete = connection.CreateCommand())
        {
            delete.Transaction = transaction;
            delete.CommandText = "DELETE FROM loot_entries WHERE map_id = $id";
            delete.Parameters.AddWithValue("$id", mapId);
            delete.ExecuteNonQuery();
        }
        foreach (var line in lines)
        {
            using var command = connection.CreateCommand();
            command.Transaction = transaction;
            command.CommandText = """
                INSERT INTO loot_entries(map_id, item_key, display_name, rarity, count, unit_ex, total_ex, priced, icon_url)
                VALUES($map, $key, $name, $rarity, $count, $unit, $total, $priced, $icon)
                """;
            command.Parameters.AddWithValue("$map", mapId);
            command.Parameters.AddWithValue("$key", line.Key);
            command.Parameters.AddWithValue("$name", line.Name);
            command.Parameters.AddWithValue("$rarity", line.Key.Length > 0 && char.IsDigit(line.Key[0]) ? line.Key[0] - '0' : 0);
            command.Parameters.AddWithValue("$count", line.Count);
            command.Parameters.AddWithValue("$unit", line.UnitEx);
            command.Parameters.AddWithValue("$total", line.TotalEx);
            command.Parameters.AddWithValue("$priced", line.Priced ? 1 : 0);
            command.Parameters.AddWithValue("$icon", line.IconUrl ?? string.Empty);
            command.ExecuteNonQuery();
        }
        using var update = connection.CreateCommand();
        update.Transaction = transaction;
        update.CommandText = "UPDATE map_runs SET profit_ex = COALESCE((SELECT SUM(total_ex) FROM loot_entries WHERE map_id = $id), 0) WHERE id = $id";
        update.Parameters.AddWithValue("$id", mapId);
        update.ExecuteNonQuery();
    }

    private static string Utc(DateTime value) => value.ToUniversalTime().ToString("O");
}

internal sealed record MarketPriceRow(string Key, string Name, double PriceEx, string IconUrl, string Kind, string Category);

internal sealed record MarketPriceLine(string Key, string Name, double PriceEx, string IconUrl, string FetchedUtc, string Category, double? ManualEx);

internal sealed record MarketSnapshot(double DivineRate, DateTime FetchedUtc, IReadOnlyList<MarketPriceRow> Prices);
