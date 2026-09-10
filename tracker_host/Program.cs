using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace LootTracker.App;

internal static class Program
{
    public static async Task<int> Main(string[] args)
    {
        // Flutter's process pipe writes and reads JSON as UTF-8. Windows may otherwise give a
        // redirected Console its active-code-page encoding, which turns Chinese preset names such
        // as "默认" into mojibake before the settings store ever receives them.
        Console.InputEncoding = Encoding.UTF8;
        Console.OutputEncoding = Encoding.UTF8;

        using var store = new SqliteStore(AppSettings.DatabasePath);
        var settings = AppSettings.Load(store);
        settings.Save(store);
        store.SaveOffsetProfile(settings.Offsets, "active");

        if (args.Contains("--smoke", StringComparer.Ordinal))
        {
            Console.WriteLine(ProtocolJson.Message("result", new { ok = true, data = new { database = AppSettings.DatabasePath } }, "smoke"));
            return 0;
        }

        try
        {
            using var game = new GameHost();
            using var engine = new LootTrackerEngine(settings, store);
            var server = new HostServer(game, engine, settings, store);
            await server.RunAsync();
            return 0;
        }
        catch (Exception exception)
        {
            Console.WriteLine(ProtocolJson.Message("hostError", new
            {
                code = "host_start_failed",
                message = exception.Message,
            }));
            return 1;
        }
    }
}

internal sealed class HostServer
{
    private readonly GameHost game;
    private readonly LootTrackerEngine engine;
    private readonly AppSettings settings;
    private readonly SqliteStore store;
    private readonly object engineGate = new();
    private readonly object outputGate = new();
    private MemoryOffsetProfile? pendingOffsets;
    private DateTime nextSnapshotUtc;
    private DateTime nextPendingValidationUtc;
    private DateTime nextScreenCaptureCheckUtc;
    private bool? screenCaptureActive;

    public HostServer(GameHost game, LootTrackerEngine engine, AppSettings settings, SqliteStore store)
    {
        this.game = game;
        this.engine = engine;
        this.settings = settings;
        this.store = store;
        var pendingJson = store.GetSetting("pending_offsets");
        if (!string.IsNullOrWhiteSpace(pendingJson))
        {
            try { pendingOffsets = JsonSerializer.Deserialize<MemoryOffsetProfile>(pendingJson, ProtocolJson.Options); }
            catch { pendingOffsets = null; }
        }
    }

    public async Task RunAsync()
    {
        using var cancellation = new CancellationTokenSource();
        var pump = PumpAsync(cancellation.Token);
        try
        {
            while (await Console.In.ReadLineAsync(cancellation.Token) is { } line)
            {
                if (string.IsNullOrWhiteSpace(line)) continue;
                HandleLine(line);
            }
        }
        catch (OperationCanceledException)
        {
        }
        finally
        {
            cancellation.Cancel();
            try { await pump; } catch (OperationCanceledException) { }
        }
    }

    private async Task PumpAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                var now = DateTime.UtcNow;
                lock (engineGate)
                {
                    game.Pump();
                    engine.Tick();
                    if (now >= nextSnapshotUtc)
                    {
                        nextSnapshotUtc = now.AddMilliseconds(250);
                        Send("trackerSnapshot", engine.GetSnapshot());
                    }
                    if (pendingOffsets != null && now >= nextPendingValidationUtc)
                    {
                        nextPendingValidationUtc = now.AddSeconds(1);
                        ValidatePendingOffsets();
                    }
                }
                if (now >= nextScreenCaptureCheckUtc)
                {
                    nextScreenCaptureCheckUtc = now.AddMilliseconds(100);
                    var active = IsScreenCaptureActive();
                    if (screenCaptureActive != active)
                    {
                        screenCaptureActive = active;
                        Send("screenCaptureChanged", new { active });
                    }
                }
            }
            catch (Exception exception)
            {
                Send("hostError", new { code = "tracking_tick_failed", message = exception.Message });
            }
            await Task.Delay(16, cancellationToken);
        }
    }

    /// Windows creates ScreenClippingHost only while the Win+Shift+S selection layer is open.
    /// Dropping topmost for that short interval prevents an overlay from appearing in the capture
    /// or obstructing the selection handles, without changing the user's normal topmost setting.
    private static bool IsScreenCaptureActive()
    {
        if (!OperatingSystem.IsWindows()) return false;
        try
        {
            var processes = Process.GetProcessesByName("ScreenClippingHost");
            try { return processes.Length > 0; }
            finally
            {
                foreach (var process in processes) process.Dispose();
            }
        }
        catch
        {
            return false;
        }
    }

    private void ValidatePendingOffsets()
    {
        if (pendingOffsets == null) return;
        var validation = engine.TestOffsetProfile(pendingOffsets);
        if (validation.Status == "pending") return;
        if (validation.Status == "valid")
        {
            engine.ApplyOffsetProfile(pendingOffsets);
            store.SetSetting("pending_offsets", string.Empty);
            store.SaveOffsetProfile(pendingOffsets, "valid");
            pendingOffsets = null;
        }
        else
        {
            store.SaveOffsetProfile(pendingOffsets, "invalid");
            store.SetSetting("pending_offsets", string.Empty);
            pendingOffsets = null;
        }
        Send("offsetValidationChanged", validation);
    }

    private void HandleLine(string line)
    {
        ProtocolEnvelope? envelope;
        try
        {
            envelope = JsonSerializer.Deserialize<ProtocolEnvelope>(line, ProtocolJson.Options);
            if (envelope == null) throw new JsonException("Empty request.");
            if (envelope.Version != 1) throw new ProtocolException("unsupported_version", "Unsupported protocol version.");
            if (string.IsNullOrWhiteSpace(envelope.Id)) throw new ProtocolException("missing_id", "Request id is required.");
        }
        catch (Exception exception)
        {
            Send("result", Error("invalid_envelope", exception.Message));
            return;
        }

        try
        {
            object? data;
            // UI-only settings must remain responsive even if reading the game process stalls for
            // a while. UpdateSettings takes engineGate itself only when the incoming value changes
            // something consumed by the tracking engine.
            if (envelope.Type == "updateSettings") data = UpdateSettings(envelope.Payload);
            else lock (engineGate) data = Dispatch(envelope.Type, envelope.Payload);
            Send("result", new { ok = true, data }, envelope.Id);
        }
        catch (ProtocolException exception)
        {
            Send("result", Error(exception.Code, exception.Message), envelope.Id);
        }
        catch (Exception exception)
        {
            Send("result", Error("internal_error", exception.Message), envelope.Id);
        }
    }

    private object? Dispatch(string type, JsonElement payload)
    {
        switch (type)
        {
            case "getSnapshot": return engine.GetSnapshot();
            case "listSessions": return store.ListSessions();
            case "listMaps": return store.ListMaps(RequiredString(payload, "sessionId"));
            case "getMapDetail": return store.GetMapDetail(RequiredString(payload, "mapId"));
            case "listMarketPrices":
                return engine.ListMarketPrices(OptionalString(payload, "query"), OptionalInt(payload, "limit", 500));
            case "refreshMarketPrices": engine.RefreshPrices(); return new { started = true };
            case "setManualPrice":
                engine.SetManualPrice(RequiredString(payload, "itemKey"), RequiredDouble(payload, "priceEx"));
                return new { saved = true };
            case "clearManualPrice": engine.ClearManualPrice(RequiredString(payload, "itemKey")); return new { cleared = true };
            case "pauseTracking": engine.Pause(); return engine.GetSnapshot();
            case "resumeTracking": engine.Resume(); return engine.GetSnapshot();
            case "startNewSession": engine.ResetSession(); return engine.GetSnapshot();
            case "selectCostPreset":
                engine.SelectCostPreset(OptionalString(payload, "presetId"));
                Send("settingsChanged", SettingsPayload());
                return SettingsPayload();
            case "getSettings": return SettingsPayload();
            case "getOffsetProfile": return OffsetPayload();
            case "testOffsetProfile": return TestOffsetPayload(payload);
            case "applyOffsetProfile": return ApplyOffsetPayload(payload);
            case "restoreDefaultOffsets": return ApplyOffsets(MemoryOffsetProfile.Defaults());
            case "getWindowState": return store.GetWindowState(RequiredString(payload, "windowKey"));
            case "updateWindowState":
                store.SetWindowState(RequiredString(payload, "windowKey"), RequiredDouble(payload, "x"), RequiredDouble(payload, "y"), RequiredDouble(payload, "width"), RequiredDouble(payload, "height"));
                return new { saved = true };
            default: throw new ProtocolException("unknown_request", $"Unknown request type: {type}");
        }
    }

    private object SettingsPayload() => new
    {
        settings,
        leagues = engine.GetLeagues(),
        leagueStatus = engine.LeagueStatus.ToString().ToLowerInvariant(),
        leagueError = engine.LeagueError,
    };

    private object UpdateSettings(JsonElement payload)
    {
        var value = JsonSerializer.Deserialize<AppSettings>(payload.GetRawText(), ProtocolJson.Options)
            ?? throw new ProtocolException("invalid_settings", "Settings payload is required.");
        if (!RequiresEngineGate(settings, value))
        {
            settings.ApplyUiOnly(value);
            settings.Save(store);
            Send("settingsChanged", SettingsPayload());
            return SettingsPayload();
        }

        lock (engineGate)
        {
            string previousLeague = settings.League;
            string previousCosts = CostSettingsSignature(settings);
            settings.Apply(value);
            settings.Save(store);
            if (!string.Equals(previousCosts, CostSettingsSignature(settings), StringComparison.Ordinal))
            {
                engine.RefreshCostSettings();
            }
            if (!string.Equals(previousLeague, settings.League, StringComparison.OrdinalIgnoreCase))
            {
                string requestedLeague = settings.League;
                settings.League = previousLeague;
                engine.ChangeLeague(requestedLeague);
            }
        }
        Send("settingsChanged", SettingsPayload());
        return SettingsPayload();
    }

    /// A compact boundary around the only settings that can change the current map's charge.
    /// Overlay appearance, opacity and other preferences must not cause a full active-session save.
    internal static string CostSettingsSignature(AppSettings value) => JsonSerializer.Serialize(
        new { value.CostPresets, value.SelectedCostPresetId }, ProtocolJson.Options);

    /// The pump is the only writer/reader that needs engineGate. Flutter-only preferences can be
    /// persisted without waiting behind a potentially slow game memory read.
    internal static bool RequiresEngineGate(AppSettings current, AppSettings incoming) =>
        !string.Equals(current.League, incoming.League, StringComparison.OrdinalIgnoreCase) ||
        current.PriceCacheMinutes != incoming.PriceCacheMinutes ||
        !string.Equals(current.Language, incoming.Language, StringComparison.Ordinal) ||
        JsonSerializer.Serialize(current.Offsets, ProtocolJson.Options) !=
            JsonSerializer.Serialize(incoming.Offsets, ProtocolJson.Options) ||
        !string.Equals(CostSettingsSignature(current), CostSettingsSignature(incoming), StringComparison.Ordinal);

    private object OffsetPayload() => new
    {
        current = settings.Offsets.AsDictionary(),
        pending = pendingOffsets?.AsDictionary(),
        defaults = MemoryOffsetProfile.Defaults().AsDictionary(),
        status = pendingOffsets == null ? "active" : "pending",
    };

    private object TestOffsetPayload(JsonElement payload)
    {
        var profile = ParseOffsets(payload);
        var result = engine.TestOffsetProfile(profile);
        store.SaveOffsetProfile(profile, result.Status);
        Send("offsetValidationChanged", result);
        return result;
    }

    private object ApplyOffsetPayload(JsonElement payload) => ApplyOffsets(ParseOffsets(payload));

    private object ApplyOffsets(MemoryOffsetProfile profile)
    {
        var validation = engine.TestOffsetProfile(profile);
        store.SaveOffsetProfile(profile, validation.Status);
        if (validation.Status == "valid")
        {
            engine.ApplyOffsetProfile(profile);
            pendingOffsets = null;
            store.SetSetting("pending_offsets", string.Empty);
        }
        else if (validation.Status == "pending")
        {
            pendingOffsets = profile;
            store.SetSetting("pending_offsets", JsonSerializer.Serialize(profile, ProtocolJson.Options));
        }
        else
        {
            throw new ProtocolException("offset_validation_failed", validation.Error);
        }
        Send("offsetValidationChanged", validation);
        return new { validation, profile = profile.AsDictionary() };
    }

    private static MemoryOffsetProfile ParseOffsets(JsonElement payload)
    {
        if (payload.ValueKind == JsonValueKind.Object && payload.TryGetProperty("offsets", out var nested)) payload = nested;
        if (payload.ValueKind != JsonValueKind.Object) throw new ProtocolException("invalid_offsets", "Offsets object is required.");
        var values = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var property in payload.EnumerateObject()) values[property.Name] = property.Value.ValueKind == JsonValueKind.String
            ? property.Value.GetString() ?? string.Empty
            : property.Value.GetRawText();
        if (!MemoryOffsetProfile.TryParse(values, out var profile, out var error)) throw new ProtocolException("invalid_offsets", error);
        if (!profile.IsStructurallyValid(out error)) throw new ProtocolException("invalid_offsets", error);
        return profile;
    }

    private void Send(string type, object payload, string? id = null)
    {
        lock (outputGate)
        {
            Console.Out.WriteLine(ProtocolJson.Message(type, payload, id));
            Console.Out.Flush();
        }
    }

    private static object Error(string code, string message) => new { ok = false, error = new { code, message } };
    private static string RequiredString(JsonElement payload, string name)
    {
        string value = OptionalString(payload, name);
        return value.Length > 0 ? value : throw new ProtocolException("invalid_payload", $"{name} is required.");
    }
    private static string OptionalString(JsonElement payload, string name) =>
        payload.ValueKind == JsonValueKind.Object && payload.TryGetProperty(name, out var value) ? value.GetString() ?? string.Empty : string.Empty;
    private static int OptionalInt(JsonElement payload, string name, int fallback) =>
        payload.ValueKind == JsonValueKind.Object && payload.TryGetProperty(name, out var value) && value.TryGetInt32(out var parsed) ? parsed : fallback;
    private static double RequiredDouble(JsonElement payload, string name) =>
        payload.ValueKind == JsonValueKind.Object && payload.TryGetProperty(name, out var value) && value.TryGetDouble(out var parsed)
            ? parsed
            : throw new ProtocolException("invalid_payload", $"{name} is required.");
}

internal sealed class ProtocolException(string code, string message) : Exception(message)
{
    public string Code { get; } = code;
}
