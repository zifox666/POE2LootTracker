using System.Text.Json;

namespace LootTracker.App;

internal sealed class AppSettings
{
    public double BackgroundOpacity { get; set; } = 0.94;
    public double TextOpacity { get; set; } = 1.0;
    public bool AlwaysOnTop { get; set; } = true;
    public bool ClickThrough { get; set; }
    public string OverlayMode { get; set; } = "floating";
    public string OverlayWindowStyle { get; set; } = "frameless";
    public double FloatingFontScale { get; set; } = 1.0;
    public double MinimalFontScale { get; set; } = 1.0;
    public double MainFontScale { get; set; } = 1.0;
    public bool TransparentOverlayBorder { get; set; }
    public bool FrostedGlass { get; set; } = true;
    public bool PickupToastsEnabled { get; set; } = true;
    public int PickupToastMaxVisible { get; set; } = 3;
    public double PickupToastDurationSeconds { get; set; } = 2.5;
    public string ThemeMode { get; set; } = "dark";
    // Mark newly created settings so older files that predate this flag are normalized once.
    public bool ThemeModeConfigured { get; set; } = true;
    public string Language { get; set; } = string.Empty;
    public string League { get; set; } = "Standard";
    public int PriceCacheMinutes { get; set; } = 30;
    public bool RiskAcknowledged { get; set; }

    /// Ask before starting a new session. The dialogs offer to remember the answer, so this is how
    /// "don't ask again" is stored.
    public bool ConfirmNewSession { get; set; } = true;

    /// What closing the main window should do, remembered from the close dialog:
    /// "" asks every time, "exit" quits, "overlay" keeps tracking in the small window.
    public string CloseAction { get; set; } = string.Empty;

    /// How the Flutter updater reaches GitHub: "cdn", "native", or "custom".
    public string UpdateSource { get; set; } = "cdn";
    public string CustomUpdateCdn { get; set; } = string.Empty;

    public List<CostPreset> CostPresets { get; set; } = new();

    /// Legacy/default-id mirror kept for compatibility with settings written by the first cost
    /// implementation. [CostPreset.IsDefault] is authoritative after normalization.
    public string SelectedCostPresetId { get; set; } = string.Empty;

    public MemoryOffsetProfile Offsets { get; set; } = MemoryOffsetProfile.Defaults();

    public static string ConfigDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "POE2LootTracker");

    public static string DatabasePath => Path.Combine(ConfigDirectory, "loot_tracker.sqlite3");
    public static string CacheDirectory => Path.Combine(ConfigDirectory, "cache");

    public static AppSettings Load(SqliteStore store)
    {
        var json = store.GetSetting("application");
        if (string.IsNullOrWhiteSpace(json)) return new AppSettings();
        try
        {
            var value = JsonSerializer.Deserialize<AppSettings>(json) ?? new AppSettings();
            value.Normalize();
            return value;
        }
        catch
        {
            return new AppSettings();
        }
    }

    public void Save(SqliteStore store)
    {
        Normalize();
        store.SetSetting("application", JsonSerializer.Serialize(this));
    }

    public void Apply(AppSettings value)
    {
        BackgroundOpacity = value.BackgroundOpacity;
        TextOpacity = value.TextOpacity;
        AlwaysOnTop = value.AlwaysOnTop;
        ClickThrough = value.ClickThrough;
        OverlayMode = value.OverlayMode;
        OverlayWindowStyle = value.OverlayWindowStyle;
        FloatingFontScale = value.FloatingFontScale;
        MinimalFontScale = value.MinimalFontScale;
        MainFontScale = value.MainFontScale;
        TransparentOverlayBorder = value.TransparentOverlayBorder;
        FrostedGlass = value.FrostedGlass;
        PickupToastsEnabled = value.PickupToastsEnabled;
        PickupToastMaxVisible = value.PickupToastMaxVisible;
        PickupToastDurationSeconds = value.PickupToastDurationSeconds;
        ThemeMode = value.ThemeMode;
        ThemeModeConfigured = value.ThemeModeConfigured;
        Language = value.Language;
        League = value.League;
        PriceCacheMinutes = value.PriceCacheMinutes;
        RiskAcknowledged = value.RiskAcknowledged;
        ConfirmNewSession = value.ConfirmNewSession;
        CloseAction = value.CloseAction;
        UpdateSource = value.UpdateSource;
        CustomUpdateCdn = value.CustomUpdateCdn;
        CostPresets = (value.CostPresets ?? new()).Select(CopyCostPreset).ToList();
        SelectedCostPresetId = value.SelectedCostPresetId;
        Normalize();
    }

    /// Applies fields that are consumed only by the Flutter shell. Keeping this separate means a
    /// disclaimer acknowledgement or overlay resize never has to replace collections and offsets
    /// that the tracking pump may currently be reading.
    public void ApplyUiOnly(AppSettings value)
    {
        BackgroundOpacity = value.BackgroundOpacity;
        TextOpacity = value.TextOpacity;
        AlwaysOnTop = value.AlwaysOnTop;
        ClickThrough = value.ClickThrough;
        OverlayMode = value.OverlayMode;
        OverlayWindowStyle = value.OverlayWindowStyle;
        FloatingFontScale = value.FloatingFontScale;
        MinimalFontScale = value.MinimalFontScale;
        MainFontScale = value.MainFontScale;
        TransparentOverlayBorder = value.TransparentOverlayBorder;
        FrostedGlass = value.FrostedGlass;
        PickupToastsEnabled = value.PickupToastsEnabled;
        PickupToastMaxVisible = value.PickupToastMaxVisible;
        PickupToastDurationSeconds = value.PickupToastDurationSeconds;
        ThemeMode = value.ThemeMode;
        ThemeModeConfigured = value.ThemeModeConfigured;
        RiskAcknowledged = value.RiskAcknowledged;
        ConfirmNewSession = value.ConfirmNewSession;
        CloseAction = value.CloseAction;
        UpdateSource = value.UpdateSource;
        CustomUpdateCdn = value.CustomUpdateCdn;
        NormalizeUiOnly();
    }

    private void Normalize()
    {
        NormalizeUiOnly();
        PriceCacheMinutes = Math.Clamp(PriceCacheMinutes, 1, 1440);
        Language = Language is "en" or "zh" ? Language : string.Empty;
        Offsets ??= MemoryOffsetProfile.Defaults();
        CostPresets ??= new();
        var ids = new HashSet<string>(StringComparer.Ordinal);
        CostPresets = CostPresets
            .Where(preset => preset != null && !string.IsNullOrWhiteSpace(preset.Name) &&
                preset.Amount > 0 && !double.IsNaN(preset.Amount) && !double.IsInfinity(preset.Amount))
            .Select(preset =>
            {
                preset.Id = string.IsNullOrWhiteSpace(preset.Id) || !ids.Add(preset.Id)
                    ? Guid.NewGuid().ToString("N")
                    : preset.Id;
                ids.Add(preset.Id);
                preset.Name = preset.Name.Trim();
                preset.MapNames ??= new();
                preset.MapNames = preset.MapNames
                    .Append(preset.MapName ?? string.Empty)
                    .Select(name => name.Trim())
                    .Where(name => name.Length > 0)
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList();
                preset.MapName = string.Empty;
                preset.Currency = string.Equals(preset.Currency, "D", StringComparison.OrdinalIgnoreCase) ? "D" : "E";
                return preset;
            })
            .ToList();
        string defaultId = CostPresets.FirstOrDefault(preset => preset.IsDefault)?.Id ?? string.Empty;
        if (defaultId.Length == 0 && CostPresets.Any(
            preset => string.Equals(preset.Id, SelectedCostPresetId, StringComparison.Ordinal)))
        {
            defaultId = SelectedCostPresetId;
        }
        foreach (var preset in CostPresets)
        {
            preset.IsDefault = string.Equals(preset.Id, defaultId, StringComparison.Ordinal);
        }
        SelectedCostPresetId = defaultId;
    }

    private void NormalizeUiOnly()
    {
        if (!ThemeModeConfigured)
        {
            ThemeMode = "dark";
            ThemeModeConfigured = true;
        }
        BackgroundOpacity = Math.Clamp(BackgroundOpacity, 0, 1);
        TextOpacity = Math.Clamp(TextOpacity, 0, 1);
        OverlayMode = OverlayMode == "minimal" ? "minimal" : "floating";
        OverlayWindowStyle = OverlayWindowStyle == "normal" ? "normal" : "frameless";
        FloatingFontScale = Math.Clamp(FloatingFontScale, 0.75, 1.5);
        MinimalFontScale = Math.Clamp(MinimalFontScale, 0.75, 1.5);
        MainFontScale = Math.Clamp(MainFontScale, 0.75, 1.5);
        PickupToastMaxVisible = Math.Clamp(PickupToastMaxVisible, 1, 10);
        PickupToastDurationSeconds = Math.Clamp(PickupToastDurationSeconds, 1, 10);
        ThemeMode = ThemeMode is "light" or "dark" or "system" ? ThemeMode : "system";
        CloseAction = CloseAction is "exit" or "overlay" ? CloseAction : string.Empty;
        UpdateSource = UpdateSource is "cdn" or "native" or "custom" ? UpdateSource : "cdn";
        CustomUpdateCdn = (CustomUpdateCdn ?? string.Empty).Trim();
    }

    private static CostPreset CopyCostPreset(CostPreset preset) => new()
    {
        Id = preset.Id,
        Name = preset.Name,
        Amount = preset.Amount,
        Currency = preset.Currency,
        MapNames = new List<string>(preset.MapNames ?? new()),
        IsDefault = preset.IsDefault,
        MapName = preset.MapName,
    };
}
