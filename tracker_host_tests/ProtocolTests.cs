using System.Text.Json;
using LootTracker.App;

namespace TrackerHost.Tests;

public sealed class ProtocolTests
{
    [Fact]
    public void WritesVersionedCorrelatedEnvelope()
    {
        using var document = JsonDocument.Parse(ProtocolJson.Message("result", new { ok = true }, "request-1"));
        var root = document.RootElement;
        Assert.Equal(1, root.GetProperty("v").GetInt32());
        Assert.Equal("request-1", root.GetProperty("id").GetString());
        Assert.Equal("result", root.GetProperty("type").GetString());
        Assert.True(root.GetProperty("payload").GetProperty("ok").GetBoolean());
    }

    [Fact]
    public void OverlayModeDoesNotInvalidateCostSettings()
    {
        var settings = new AppSettings
        {
            OverlayMode = "floating",
            CostPresets =
            [
                new CostPreset
                {
                    Id = "default",
                    Name = "Default",
                    Amount = 5,
                    Currency = "E",
                    IsDefault = true,
                    MapNames = ["钢铁城塞", "鋼鐵城塞", "The Iron Citadel"],
                },
            ],
            SelectedCostPresetId = "default",
        };
        string before = HostServer.CostSettingsSignature(settings);

        settings.OverlayMode = "minimal";

        Assert.Equal(before, HostServer.CostSettingsSignature(settings));
        settings.CostPresets[0].Amount = 6;
        Assert.NotEqual(before, HostServer.CostSettingsSignature(settings));
    }

    [Fact]
    public void UiOnlySettingsDoNotRequireTheTrackingEngineGate()
    {
        var current = new AppSettings { OverlayMode = "floating", RiskAcknowledged = false };
        var incoming = new AppSettings
        {
            OverlayMode = "minimal",
            RiskAcknowledged = true,
            UpdateSource = "custom",
            CustomUpdateCdn = "https://mirror.example/",
        };

        Assert.False(HostServer.RequiresEngineGate(current, incoming));
        current.ApplyUiOnly(incoming);
        Assert.Equal("custom", current.UpdateSource);
        Assert.Equal("https://mirror.example/", current.CustomUpdateCdn);

        incoming.Language = "zh";
        Assert.True(HostServer.RequiresEngineGate(current, incoming));
    }
}
