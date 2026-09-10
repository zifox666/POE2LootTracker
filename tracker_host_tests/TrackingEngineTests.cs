using LootTracker.App;

namespace TrackerHost.Tests;

public sealed class TrackingEngineTests
{
    [Fact]
    public void InventoryDiffTracksDropsConsumptionAndRemoval()
    {
        var baseline = new Dictionary<string, long> { ["orb"] = 10, ["map"] = 1, ["gone"] = 4 };
        var current = new Dictionary<string, long> { ["orb"] = 13, ["map"] = 0, ["new"] = 2 };

        var diff = LootTrackerEngine.Diff(current, baseline);

        Assert.Equal(3, diff["orb"]);
        Assert.Equal(-1, diff["map"]);
        Assert.Equal(-4, diff["gone"]);
        Assert.Equal(2, diff["new"]);
    }

    [Fact]
    public void MapSpecificCostWinsAndConvertsDivinesAtEntryRate()
    {
        var selected = new CostPreset { Id = "selected", Name = "Generic", Amount = 8, Currency = "E", IsDefault = true };
        var mapped = new CostPreset
        {
            Id = "mapped",
            Name = "Boss setup",
            Amount = 1.5,
            Currency = "D",
            MapNames = ["钢铁城塞", "鋼鐵城塞", "The Iron Citadel"],
        };

        foreach (string areaName in mapped.MapNames)
        {
            Assert.Same(mapped, LootTrackerEngine.ResolveCostPreset([selected, mapped], areaName));
        }
        var resolved = LootTrackerEngine.ResolveCostPreset([selected, mapped], "鋼鐵城塞");
        var run = new MapRun();
        LootTrackerEngine.ApplyCostPreset(run, resolved, 100);

        Assert.Same(mapped, resolved);
        Assert.Equal("mapped", run.CostPresetId);
        Assert.Equal("Boss setup", run.CostName);
        Assert.Equal(150, run.CostEx);
    }

    [Fact]
    public void SelectedCostIsFallbackAndCanBeCleared()
    {
        var selected = new CostPreset { Id = "selected", Name = "Generic", Amount = 8, Currency = "E", IsDefault = true };
        var run = new MapRun();

        LootTrackerEngine.ApplyCostPreset(
            run,
            LootTrackerEngine.ResolveCostPreset([selected], "Different Map"),
            100);
        Assert.Equal(8, run.CostEx);

        LootTrackerEngine.ApplyCostPreset(run, null, 100);
        Assert.Equal(string.Empty, run.CostPresetId);
        Assert.Equal(0, run.CostEx);
    }
}
