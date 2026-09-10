namespace LootTracker.App;

internal sealed class MemoryOffsetProfile
{
    public int ServerDataPlayerVector { get; set; } = 0x48;
    public int PlayerInventoriesVector { get; set; } = 0x320;
    public int InventoryArrayStride { get; set; } = 0x18;
    public int InventoryArrayId { get; set; } = 0x00;
    public int InventoryArrayPointer { get; set; } = 0x08;
    public int InventoryTotalBoxes { get; set; } = 0x150;
    public int InventoryItemList { get; set; } = 0x170;
    public int InventoryItemItem { get; set; } = 0x00;
    public int EntityDetailsPointer { get; set; } = 0x08;
    public int EntityDetailsName { get; set; } = 0x08;
    public int EntityComponentList { get; set; } = 0x10;
    public int EntityComponentLookup { get; set; } = 0x28;
    public int ComponentLookupBucket { get; set; } = 0x28;
    public int ComponentNameIndexStride { get; set; } = 0x10;
    public int StackCount { get; set; } = 0x18;
    public int ModsRarity { get; set; } = 0x94;
    public int RenderItemArt { get; set; } = 0x28;
    public int BaseDisplayNameRow { get; set; } = 0x10;
    public int BaseDisplayName { get; set; } = 0x30;
    public int MainInventoryId { get; set; } = 1;

    public static MemoryOffsetProfile Defaults() => new();

    public IReadOnlyDictionary<string, int> AsDictionary() => GetType().GetProperties()
        .ToDictionary(property => property.Name, property => (int)(property.GetValue(this) ?? 0), StringComparer.Ordinal);

    public bool IsStructurallyValid(out string error)
    {
        error = string.Empty;
        if (InventoryArrayStride <= 0)
        {
            error = "invalid_offset:InventoryArrayStride";
            return false;
        }
        if (ComponentNameIndexStride <= 0)
        {
            error = "invalid_offset:ComponentNameIndexStride";
            return false;
        }
        return true;
    }

    public static bool TryParse(IReadOnlyDictionary<string, string> values, out MemoryOffsetProfile profile, out string error)
    {
        profile = Defaults();
        error = string.Empty;
        foreach (var property in typeof(MemoryOffsetProfile).GetProperties())
        {
            if (!values.TryGetValue(property.Name, out var raw)) continue;
            raw = raw.Trim();
            var hex = raw.StartsWith("0x", StringComparison.OrdinalIgnoreCase) ? raw[2..] : raw;
            if (!int.TryParse(hex, System.Globalization.NumberStyles.HexNumber, null, out var parsed) || parsed < 0)
            {
                error = $"invalid_offset:{property.Name}";
                return false;
            }

            property.SetValue(profile, parsed);
        }

        return true;
    }
}

internal sealed record OffsetValidation(string Status, string Error);
