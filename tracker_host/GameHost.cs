using System.Reflection;
using Coroutine;
using GameHelper;
using GameHelper.CoroutineEvents;

namespace LootTracker.App;

internal sealed class GameHost : IDisposable
{
    private readonly Event perFrameEvent;
    private readonly Event postPerFrameEvent;
    private readonly System.Diagnostics.Stopwatch clock = System.Diagnostics.Stopwatch.StartNew();
    private TimeSpan lastTick;
    private bool disposed;

    public GameHost()
    {
        _ = Core.Process;
        Core.Initialize();

        var initialize = typeof(Core).GetMethod("InitializeCororutines", BindingFlags.NonPublic | BindingFlags.Static)
            ?? throw new MissingMethodException(typeof(Core).FullName, "InitializeCororutines");
        initialize.Invoke(null, null);

        this.perFrameEvent = GetEvent("PerFrameDataUpdate");
        this.postPerFrameEvent = GetEvent("PostPerFrameDataUpdate");
    }

    public bool IsConnected => Core.Process.Pid != 0;

    public void Pump()
    {
        if (this.disposed)
        {
            return;
        }

        var now = this.clock.Elapsed;
        var elapsed = now - this.lastTick;
        this.lastTick = now;
        var seconds = (float)Math.Clamp(elapsed.TotalSeconds, 0.001, 0.25);

        CoroutineHandler.Tick(seconds);
        CoroutineHandler.RaiseEvent(this.perFrameEvent);
        CoroutineHandler.RaiseEvent(this.postPerFrameEvent);
    }

    public void Dispose()
    {
        this.disposed = true;
        var dispose = typeof(Core).GetMethod("Dispose", BindingFlags.NonPublic | BindingFlags.Static);
        dispose?.Invoke(null, null);
    }

    private static Event GetEvent(string name)
    {
        var field = typeof(GameHelperEvents).GetField(name, BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static)
            ?? throw new MissingFieldException(typeof(GameHelperEvents).FullName, name);
        return (Event)(field.GetValue(null) ?? throw new InvalidOperationException($"Event {name} is unavailable."));
    }
}
