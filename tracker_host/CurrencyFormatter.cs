using System.Globalization;

namespace LootTracker.App;

internal sealed record CurrencyAmount(double Value, string Unit)
{
    public string Text => Value.ToString("0.###", CultureInfo.InvariantCulture);
}

internal static class CurrencyFormatter
{
    public static CurrencyAmount Format(double exalted, double divineRate)
    {
        if (divineRate > 0 && Math.Abs(exalted / divineRate) > 0.3)
        {
            return new CurrencyAmount(exalted / divineRate, "D");
        }
        return new CurrencyAmount(exalted, "E");
    }
}
