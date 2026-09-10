using LootTracker.App;

namespace TrackerHost.Tests;

public sealed class MemoryOffsetProfileTests
{
    [Fact]
    public void ParsesHexadecimalProfile()
    {
        var values = MemoryOffsetProfile.Defaults().AsDictionary()
            .ToDictionary(pair => pair.Key, pair => $"0x{pair.Value:X}");
        values[nameof(MemoryOffsetProfile.StackCount)] = "20";

        Assert.True(MemoryOffsetProfile.TryParse(values, out var profile, out var error), error);
        Assert.Equal(0x20, profile.StackCount);
        Assert.True(profile.IsStructurallyValid(out _));
    }

    [Fact]
    public void RejectsMalformedAndZeroStride()
    {
        Assert.False(MemoryOffsetProfile.TryParse(
            new Dictionary<string, string> { [nameof(MemoryOffsetProfile.StackCount)] = "xyz" },
            out _, out _));
        var profile = MemoryOffsetProfile.Defaults();
        profile.InventoryArrayStride = 0;
        Assert.False(profile.IsStructurallyValid(out _));
    }
}
