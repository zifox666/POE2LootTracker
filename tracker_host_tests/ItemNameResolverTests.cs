using System.Text.Json;
using LootTracker.App;

namespace TrackerHost.Tests;

public sealed class ItemNameResolverTests
{
    private static readonly IReadOnlyDictionary<string, string> EmptyNames =
        new Dictionary<string, string>(StringComparer.Ordinal);

    public static TheoryData<string, string, string> AbnormalItems => new()
    {
        { "Metadata/Items/Belts/FourBelt9", "Heavy Belt", "重革腰带" },
        { "Metadata/Items/Armours/BodyArmours/FourBodyDex8Endgame", "Wyrmscale Coat", "巨龙鳞外套" },
        { "Metadata/Items/Armours/BodyArmours/FourBodyDexInt2Endgame", "Sleek Jacket", "滑布外衣" },
        { "Metadata/Items/Armours/Helmets/FourHelmetStrDex6Endgame", "Gladiatorial Helm", "角斗士头盔" },
        { "Metadata/Items/Rings/FourRing1", "Iron Ring", "锻铁戒指" },
        { "Metadata/Items/Rings/FourRing9", "Prismatic Ring", "三相戒指" },
        { "Metadata/Items/Weapons/OneHandWeapons/Sceptres/FourSceptre6c", "Shrine Sceptre", "圣地权杖" },
        { "Metadata/Items/Gems/SkillGemAnimusExchange", "Animus Exchange", "命源交换" },
        { "Metadata/Items/Gems/SkillGemFrostflameNova", "Frostflame Nova", "霜焰新星" },
        { "Metadata/Items/Gems/SkillGemPoweredByVerisium", "Powered by Verisium", "维金供能" },
    };

    public static TheoryData<string, string> TabletItems => new()
    {
        { "Metadata/Items/TowerAugment/AbyssAugment", "深渊石板" },
        { "Metadata/Items/TowerAugment/BreachAugment", "裂隙石板" },
        { "Metadata/Items/TowerAugment/DeliriumAugment", "惊悸迷雾石板" },
        { "Metadata/Items/TowerAugment/ExpeditionAugment", "先祖秘藏石板" },
        { "Metadata/Items/TowerAugment/GenericAugment", "能量辐照石板" },
        { "Metadata/Items/TowerAugment/IncursionAugment", "神庙石板" },
        { "Metadata/Items/TowerAugment/MapBossAugment", "霸主石板" },
        { "Metadata/Items/TowerAugment/RitualAugment", "驱灵仪式石板" },
    };

    public static TheoryData<string, string> CurrentEconomyItems => new()
    {
        { "Metadata/Items/Expedition/Expedition2LogbookVorana", "沃拉娜之传说" },
        { "Metadata/Items/Currency/CurrencyVerisiumMetal1", "维金" },
    };

    [Theory]
    [MemberData(nameof(AbnormalItems))]
    public void BundledPathsResolveToEnglishAndChinese(string path, string english, string chinese)
    {
        var baseNames = LoadBundledBaseNames();
        var translations = LoadBundledTranslations();

        Assert.Equal(english, Resolve(path, preferChinese: false, baseNames, translations));
        Assert.Equal(chinese, Resolve(path, preferChinese: true, baseNames, translations));
    }

    [Theory]
    [MemberData(nameof(TabletItems))]
    public void AllCurrentTabletPathsResolveToChinese(string path, string chinese)
    {
        Assert.Equal(chinese, Resolve(path, true, LoadBundledBaseNames(), LoadBundledTranslations()));
    }

    [Theory]
    [MemberData(nameof(CurrentEconomyItems))]
    public void CurrentEconomyItemsResolveToChinese(string path, string chinese)
    {
        Assert.Equal(chinese, Resolve(path, true, LoadBundledBaseNames(), LoadBundledTranslations()));
    }

    [Fact]
    public void RaritySuffixesApplyWithoutChangingUniquePriority()
    {
        const string path = "Metadata/Items/Rings/FourRing1";
        var baseNames = new Dictionary<string, string> { [path] = "Iron Ring" };
        var translations = new Dictionary<string, string> { ["Iron Ring"] = "锻铁戒指", ["Blackheart"] = "幽暗之语" };

        Assert.Equal("Iron Ring", Resolve(path, false, baseNames, translations, rarity: 0));
        Assert.Equal("Iron Ring (Magic)", Resolve(path, false, baseNames, translations, rarity: 1));
        Assert.Equal("锻铁戒指（稀有）", Resolve(path, true, baseNames, translations, rarity: 2));
        Assert.Equal(
            "幽暗之语",
            ItemNameResolver.Resolve(3, path, "BlackheartArt", "Runtime Name", "Blackheart", true, baseNames, translations));
    }

    [Fact]
    public void MissingMappingUsesOnlyAValidRuntimeDisplayName()
    {
        const string path = "Metadata/Items/Test/InternalId";

        Assert.Equal("Readable Name", ItemNameResolver.Resolve(0, path, "ArtId", "Readable Name", "", false, EmptyNames, EmptyNames));
        Assert.Equal("Unknown item (InternalId)", ItemNameResolver.Resolve(0, path, "ArtId", path, "", false, EmptyNames, EmptyNames));
        Assert.Equal("未知物品（InternalId）（稀有）", ItemNameResolver.Resolve(2, path, "ArtId", "InternalId", "", true, EmptyNames, EmptyNames));
        Assert.Equal("Unknown item (InternalId) (Magic)", ItemNameResolver.Resolve(1, path, "ArtId", "ArtId", "", false, EmptyNames, EmptyNames));
    }

    [Fact]
    public void CorruptResourceReportsFailureAndFallsBackToEmptyMapping()
    {
        string path = Path.Combine(Path.GetTempPath(), $"item-base-names-{Guid.NewGuid():N}.json");
        try
        {
            File.WriteAllText(path, "{not-json");
            var diagnostics = new List<string>();

            var result = ItemNameResolver.LoadBaseNames(path, diagnostics.Add);

            Assert.Empty(result);
            Assert.Single(diagnostics);
            Assert.Contains("Failed to load item base-name resource", diagnostics[0]);
        }
        finally
        {
            File.Delete(path);
        }
    }

    [Fact]
    public void BundledResourceIsSortedNonEmptyAndCopiedToTestOutput()
    {
        string path = Path.Combine(AppContext.BaseDirectory, "item-base-names.json");
        Assert.True(File.Exists(path), $"Missing copied resource: {path}");

        using var document = JsonDocument.Parse(File.ReadAllText(path));
        var entries = document.RootElement.EnumerateObject().ToList();
        Assert.NotEmpty(entries);
        Assert.All(entries, entry =>
        {
            Assert.False(string.IsNullOrWhiteSpace(entry.Name));
            Assert.False(string.IsNullOrWhiteSpace(entry.Value.GetString()));
        });
        Assert.Equal(entries.Select(entry => entry.Name).OrderBy(name => name, StringComparer.Ordinal), entries.Select(entry => entry.Name));
    }

    [Fact]
    public void BundledChineseNamesCoverMostReleasedBasePaths()
    {
        var baseNames = LoadBundledBaseNames();
        var translations = LoadBundledTranslations();
        int covered = baseNames.Values.Count(translations.ContainsKey);

        Assert.True(translations.Count >= 8_000, $"Only {translations.Count} Chinese item names were bundled.");
        Assert.True(covered >= baseNames.Count * 0.70, $"Only {covered}/{baseNames.Count} released paths have Chinese names.");
    }

    [Fact]
    public void DisplayNameResolutionDoesNotAlterItemKeyFormat()
    {
        const string path = "Metadata/Items/Rings/FourRing1";
        string key = LootTrackerEngine.BuildItemKey(2, path, "RareArt");

        _ = Resolve(path, true, new Dictionary<string, string> { [path] = "Iron Ring" }, EmptyNames, rarity: 2);

        Assert.Equal($"2\u001f{path}\u001fRareArt", key);
        Assert.Equal((2, path, "RareArt"), LootTrackerEngine.SplitItemKey(key));
    }

    private static string Resolve(
        string path,
        bool preferChinese,
        IReadOnlyDictionary<string, string> baseNames,
        IReadOnlyDictionary<string, string> translations,
        int rarity = 0) =>
        ItemNameResolver.Resolve(rarity, path, string.Empty, string.Empty, string.Empty, preferChinese, baseNames, translations);

    private static Dictionary<string, string> LoadBundledBaseNames() =>
        ItemNameResolver.LoadBaseNames(Path.Combine(AppContext.BaseDirectory, "item-base-names.json"));

    private static Dictionary<string, string> LoadBundledTranslations() =>
        JsonSerializer.Deserialize<Dictionary<string, string>>(
            File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Localization", "item-names.zh-CN.json")))!;
}
