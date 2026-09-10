using LootTracker.App;

namespace TrackerHost.Tests;

public sealed class CurrencyFormatterTests
{
    [Theory]
    [InlineData(0, 100, 0, "E")]
    [InlineData(30, 100, 30, "E")]
    [InlineData(30.001, 100, 0.30001, "D")]
    [InlineData(-31, 100, -0.31, "D")]
    [InlineData(500, 0, 500, "E")]
    public void UsesStrictAutomaticThreshold(double exalted, double rate, double expected, string unit)
    {
        var result = CurrencyFormatter.Format(exalted, rate);
        Assert.Equal(unit, result.Unit);
        Assert.Equal(expected, result.Value, 5);
    }

    [Fact]
    public void FormatsAtMostThreeFractionDigits()
    {
        Assert.Equal("1.235", CurrencyFormatter.Format(123.456, 100).Text);
        Assert.Equal("12.5", CurrencyFormatter.Format(12.5, 0).Text);
    }
}
