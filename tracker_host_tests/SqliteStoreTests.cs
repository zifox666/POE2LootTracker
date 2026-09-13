using LootTracker.App;

namespace TrackerHost.Tests;

public sealed class SqliteStoreTests
{
    [Fact]
    public void CreatesDatabaseAndFreezesEndedMapValuation()
    {
        string directory = Path.Combine(Path.GetTempPath(), "poe2-loottracker-tests", Guid.NewGuid().ToString("N"));
        string path = Path.Combine(directory, "test.sqlite3");
        Directory.CreateDirectory(directory);
        try
        {
            using (var store = new SqliteStore(path))
            {
            var run = new MapRun
            {
                SessionId = "session-1",
                Name = "Test Map",
                Hash = "hash",
                EndedUtc = DateTime.UtcNow,
                ActiveTime = TimeSpan.FromMinutes(2),
                ClosingDivineRate = 100,
                FrozenProfitEx = 15,
                CostPresetId = "cost-1",
                CostName = "Map device",
                CostEx = 5,
                Gained = new Dictionary<string, long> { ["item"] = 2 },
                Kills = [1, 2, 3, 4],
            };
            var state = new ActiveSessionState
            {
                Id = "session-1",
                League = "Standard",
                StartUtc = DateTime.UtcNow.AddMinutes(-2),
                Runs = [run],
            };

            store.SaveActiveSession(state, _ =>
            [
                new LootLine("item", "Item", 2, 10, 20, true, ""),
                new LootLine(LootTrackerEngine.CostEntryPrefix + "cost-1", "Map device", -1, 5, -5, true, ""),
            ]);
            run.FrozenProfitEx = 198;
            store.SaveActiveSession(state, _ => [new LootLine("item", "Item", 2, 99, 198, true, "")]);

            string json = System.Text.Json.JsonSerializer.Serialize(store.GetMapDetail(run.Id));
            Assert.Contains("\"profitEx\":15", json);
            Assert.Contains("\"unitEx\":10", json);
            Assert.Contains("\"name\":\"Map device\"", json);
            Assert.Contains("\"count\":-1", json);

            var restored = store.LoadActiveSession();
            Assert.NotNull(restored);
            Assert.Equal("cost-1", restored.Runs[0].CostPresetId);
            Assert.Equal(5, restored.Runs[0].CostEx);
            Assert.DoesNotContain(restored.Runs[0].Gained.Keys, key => key.StartsWith(LootTrackerEngine.CostEntryPrefix));
            Assert.True(File.Exists(path));
            }
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, true);
        }
    }

    [Fact]
    public void PersistsManualPricesAndSettings()
    {
        string directory = Path.Combine(Path.GetTempPath(), "poe2-loottracker-tests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try
        {
            using (var store = new SqliteStore(Path.Combine(directory, "test.sqlite3")))
            {
            store.SetSetting("key", "value");
            store.SetManualPrice("item", 42);
            Assert.Equal("value", store.GetSetting("key"));
            Assert.Equal(42, store.LoadManualPrices()["item"]);
            store.SetManualPrice("item", null);
            Assert.Empty(store.LoadManualPrices());
            }
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, true);
        }
    }

    [Fact]
    public void MigratesSingleMapPresetAndKeepsOnlyOneDefault()
    {
        string directory = Path.Combine(Path.GetTempPath(), "poe2-loottracker-tests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try
        {
            using (var store = new SqliteStore(Path.Combine(directory, "test.sqlite3")))
            {
                store.SetSetting("application", """
                    {"CostPresets":[
                      {"Id":"old","Name":"Old","Amount":2,"Currency":"D","MapName":"钢铁城塞"},
                      {"Id":"other","Name":"Other","Amount":5,"Currency":"E","IsDefault":true}
                    ],"SelectedCostPresetId":"old"}
                    """);

                var settings = AppSettings.Load(store);

                Assert.Contains("钢铁城塞", settings.CostPresets[0].MapNames);
                Assert.False(settings.CostPresets[0].IsDefault);
                Assert.True(settings.CostPresets[1].IsDefault);
                Assert.Equal("other", settings.SelectedCostPresetId);
            }
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, true);
        }
    }

    [Fact]
    public void AddsEditableDefaultGroupsOnceAndKeepsZeroCostPresets()
    {
        string directory = Path.Combine(Path.GetTempPath(), "poe2-loottracker-tests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try
        {
            using (var store = new SqliteStore(Path.Combine(directory, "test.sqlite3")))
            {
                store.SetSetting("application", """{"CostPresets":[]}""");

                var migrated = AppSettings.Load(store);

                Assert.Equal(3, migrated.CostPresets.Count);
                Assert.All(migrated.CostPresets, preset => Assert.Equal(0, preset.Amount));
                Assert.Contains(migrated.CostPresets, preset =>
                    preset.Id == "builtin_free_maps" &&
                    preset.MapNames.Contains("Atziri's Temple"));

                migrated.CostPresets.Clear();
                migrated.Save(store);
                Assert.Empty(AppSettings.Load(store).CostPresets);
            }
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, true);
        }
    }

    [Fact]
    public void PersistsAndReloadsMarketSnapshotFromSqlite()
    {
        string directory = Path.Combine(Path.GetTempPath(), "poe2-loottracker-tests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try
        {
            var fetched = DateTime.UtcNow;
            using (var store = new SqliteStore(Path.Combine(directory, "test.sqlite3")))
            {
                store.ReplaceMarketPrices("Standard", [new MarketPriceRow("art", "Orb", 12.5, "icon", "art", "Currency")], fetched, 100);
            }
            using (var reopened = new SqliteStore(Path.Combine(directory, "test.sqlite3")))
            {
                var snapshot = reopened.LoadMarketSnapshot("Standard");
                Assert.NotNull(snapshot);
                Assert.Equal(100, snapshot.DivineRate);
                Assert.Single(snapshot.Prices);
                Assert.Equal("art", snapshot.Prices[0].Kind);
                Assert.Equal("Currency", snapshot.Prices[0].Category);
            }
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, true);
        }
    }
}
