using System.Text.Json;

namespace LootTracker.App;

internal static class ItemNameResolver
{
    internal static Dictionary<string, string> LoadBaseNames(string path, Action<string>? reportError = null)
    {
        try
        {
            var values = JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(path));
            if (values == null)
            {
                throw new JsonException("The item base-name resource is empty.");
            }

            return values
                .Where(entry => !string.IsNullOrWhiteSpace(entry.Key) && !string.IsNullOrWhiteSpace(entry.Value))
                .ToDictionary(entry => entry.Key.Trim(), entry => entry.Value.Trim(), StringComparer.Ordinal);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException or JsonException)
        {
            reportError?.Invoke($"Failed to load item base-name resource '{path}': {exception.Message}");
            return new Dictionary<string, string>(StringComparer.Ordinal);
        }
    }

    internal static string Resolve(
        int rarity,
        string path,
        string renderArt,
        string runtimeName,
        string marketUniqueName,
        bool preferChinese,
        IReadOnlyDictionary<string, string> baseNamesByPath,
        IReadOnlyDictionary<string, string> chineseNames)
    {
        string internalId = LastSegment(path);
        if (internalId.Length == 0)
        {
            internalId = renderArt.Trim();
        }

        string name;
        if (rarity == 3)
        {
            name = !string.IsNullOrWhiteSpace(marketUniqueName)
                ? marketUniqueName.Trim()
                : !string.IsNullOrWhiteSpace(renderArt) ? renderArt.Trim() : Unknown(internalId, preferChinese);
        }
        else if (baseNamesByPath.TryGetValue(path, out var mappedName) && !string.IsNullOrWhiteSpace(mappedName))
        {
            name = mappedName.Trim();
        }
        else if (IsValidRuntimeName(runtimeName, path, renderArt))
        {
            name = runtimeName.Trim();
        }
        else
        {
            name = Unknown(internalId, preferChinese);
        }

        if (preferChinese && chineseNames.TryGetValue(name, out var translated) && !string.IsNullOrWhiteSpace(translated))
        {
            name = translated.Trim();
        }

        return rarity switch
        {
            1 => name + (preferChinese ? "（魔法）" : " (Magic)"),
            2 => name + (preferChinese ? "（稀有）" : " (Rare)"),
            _ => name,
        };
    }

    internal static bool IsValidRuntimeName(string name, string path, string renderArt)
    {
        string value = name.Trim();
        if (value.Length == 0 || value.StartsWith("Metadata/", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return !string.Equals(value, LastSegment(path), StringComparison.OrdinalIgnoreCase)
            && !string.Equals(value, renderArt.Trim(), StringComparison.OrdinalIgnoreCase);
    }

    private static string Unknown(string internalId, bool preferChinese)
    {
        string id = internalId.Length > 0 ? internalId : "?";
        return preferChinese ? $"未知物品（{id}）" : $"Unknown item ({id})";
    }

    private static string LastSegment(string path)
    {
        int slash = path.LastIndexOf('/');
        return slash >= 0 ? path[(slash + 1)..].Trim() : path.Trim();
    }
}
