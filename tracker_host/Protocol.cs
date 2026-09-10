using System.Text.Json;
using System.Text.Json.Serialization;

namespace LootTracker.App;

internal sealed record ProtocolEnvelope(
    [property: JsonPropertyName("v")] int Version,
    [property: JsonPropertyName("id")] string? Id,
    [property: JsonPropertyName("type")] string Type,
    [property: JsonPropertyName("payload")] JsonElement Payload);

internal static class ProtocolJson
{
    public static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web)
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    static ProtocolJson() => Options.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));

    public static string Message(string type, object payload, string? id = null) => JsonSerializer.Serialize(
        new { v = 1, id, type, payload }, Options);
}
