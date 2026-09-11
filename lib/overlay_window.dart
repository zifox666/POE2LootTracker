import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:window_manager/window_manager.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'dialogs.dart';
import 'l10n/app_localizations.dart';
import 'overlay_interaction.dart';
import 'widgets/common.dart';

Future<void> configureOverlayWindow() async {
  const options = WindowOptions(
    // Tall enough for the pickups/costs list; the layout still degrades to the minimal bar on its
    // own if the window is made shorter than that.
    size: Size(400, 460),
    // 96 is the minimal bar's own height, so the minimum must not exceed it or that mode could not
    // be reached.
    minimumSize: Size(320, 96),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    alwaysOnTop: true,
  );
  // Best effort. window_manager is initialised here rather than in main() so that a failure to
  // bring it up cannot stop the overlay from rendering: this exception used to escape main() before
  // runApp ever ran, which left the overlay window blank instead of showing the panel.
  //
  // Note the deliberate absence of a `windowManager.show()` in the callback: the overlay window is
  // shown by WindowController.show() on the multi-window plugin, and window_manager running inside
  // a window that was created at runtime is not guaranteed to resolve to *that* window -- asking it
  // to show could put the main window back on screen instead.
  try {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
      // WindowOptions has no `resizable` field in window_manager 0.5.2, so the WS_THICKFRAME bit has
      // to be asked for separately -- and it has to come after setAsFrameless(), which is what
      // removes the title bar. Without it the overlay could only be dragged, never resized.
      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(const Size(320, 96));
      // desktop_multi_window creates child windows with an empty native title. A stable title lets
      // screenshot tools identify this surface as a complete window even though its title bar is
      // hidden.
      await windowManager.setTitle('POE2LootTracker - Overlay');
      // Alt+F4 on a taskbar-visible small window returns to the main window, matching the
      // overlay's own close control instead of leaving tracking running with no UI.
      await windowManager.setPreventClose(true);
    });
  } catch (error) {
    debugPrint('overlay: window_manager configuration failed: $error');
  }
}

class OverlayApplication extends StatefulWidget {
  const OverlayApplication({
    required this.currentWindow,
    required this.ownerId,
    super.key,
  });
  final WindowController currentWindow;
  final String ownerId;
  @override
  State<OverlayApplication> createState() => _OverlayApplicationState();
}

class _OverlayApplicationState extends State<OverlayApplication>
    with WindowListener {
  final app = AppController(startHost: false);
  late final owner = WindowController.fromWindowId(widget.ownerId);
  String lastMode = '';
  Timer? saveTimer;
  bool restored = false;
  int restoreRequest = 0;
  bool? appliedClickThrough;
  bool? appliedAlwaysOnTop;
  String? appliedWindowStyle;
  static const interaction = OverlayInteraction();

  @override
  void initState() {
    super.initState();
    app.addListener(_changed);
    windowManager.addListener(this);
    widget.currentWindow.setWindowMethodHandler((call) async {
      if ((call.method == 'state' || call.method == 'prepareToShow') &&
          call.arguments is Map) {
        app.applyForwardedState(
          (call.arguments as Map).cast<String, dynamic>(),
        );
      }
      if (call.method == 'prepareToShow') {
        return interaction.ensureVisible();
      }
      return true;
    });
    unawaited(_loadInitialState());
  }

  Future<void> _loadInitialState() async {
    try {
      final state = await owner.invokeMethod<dynamic>('getState');
      if (state is Map) app.applyForwardedState(state.cast<String, dynamic>());
    } catch (_) {
      // A late state push will still initialise the current mode. Keep the overlay usable if the
      // owner window is temporarily unavailable while it starts.
    }

    restored = true;
    await _restoreModeWindowState(
      lastMode.isEmpty ? 'floating' : lastMode,
      useLegacyState: true,
    );
  }

  /// Switches between the full-width minimal bar and the floating card. These are only *initial*
  /// sizes: the user can resize either window freely afterwards, and the surface picks its layout
  /// from the height it actually gets.
  static const _minimalSize = Size(380, 96);
  static const _floatingSize = Size(400, 460);
  static const _windowStatePrefix = 'overlay-';

  Size _defaultSizeFor(String mode) =>
      mode == 'minimal' ? _minimalSize : _floatingSize;

  String _windowStateKey(String mode) => '$_windowStatePrefix$mode';

  void _changed() {
    final settings = app.settings;
    final windowStyle = overlayWindowStyle(settings['overlayWindowStyle']);
    if (windowStyle != appliedWindowStyle) {
      appliedWindowStyle = windowStyle;
      unawaited(_applyWindowStyle(windowStyle));
    }
    final mode = settings['overlayMode']?.toString() ?? 'floating';
    if (mode != lastMode) {
      final previousMode = lastMode;
      lastMode = mode;
      if (restored) {
        saveTimer?.cancel();
        if (previousMode.isNotEmpty) unawaited(_saveWindowState(previousMode));
        unawaited(_restoreModeWindowState(mode));
      }
    }
    final alwaysOnTop =
        (settings['alwaysOnTop'] as bool? ?? true) && !app.screenCaptureActive;
    // Tracker snapshots rebuild this window regularly. Reasserting HWND_TOPMOST on every rebuild
    // raises the overlay above QQ/WeChat's screenshot selection surface, which then cannot receive
    // the pointer or snap to this window. Touch the z-order only when the requested state changes.
    if (alwaysOnTop != appliedAlwaysOnTop) {
      appliedAlwaysOnTop = alwaysOnTop;
      unawaited(_windowOption(() => interaction.setAlwaysOnTop(alwaysOnTop)));
    }
    final clickThrough = settings['clickThrough'] as bool? ?? false;
    if (clickThrough != appliedClickThrough) {
      appliedClickThrough = clickThrough;
      unawaited(_windowOption(() => interaction.setClickThrough(clickThrough)));
    }
    setState(() {});
  }

  /// Taskbar visibility is independent from the native title bar: both choices retain the
  /// frameless overlay surface, while only the normal choice gets a taskbar entry.
  Future<void> _applyWindowStyle(String style) async {
    final normal = style == 'normal';
    await _windowOption(
      () => windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      ),
    );
    await _windowOption(() => windowManager.setSkipTaskbar(!normal));
    await _windowOption(() => windowManager.setHasShadow(false));
    await _windowOption(() => windowManager.setResizable(true));
    await _windowOption(
      () => windowManager.setMinimumSize(const Size(320, 96)),
    );
  }

  /// Window options are applied best effort: this runs on every state push, and one failing call
  /// must not abort the rebuild that follows it.
  Future<void> _windowOption(Future<void> Function() apply) async {
    try {
      await apply();
    } catch (error) {
      debugPrint('overlay: window option failed: $error');
    }
  }

  Future<void> _restoreModeWindowState(
    String mode, {
    bool useLegacyState = false,
  }) async {
    final request = ++restoreRequest;
    Map<dynamic, dynamic>? windowState;
    try {
      final state = await owner.invokeMethod<dynamic>(
        'getWindowState',
        _windowStateKey(mode),
      );
      if (state is Map && state.isNotEmpty) {
        windowState = state;
      } else if (useLegacyState) {
        // Versions before per-mode persistence stored one shared overlay state. Use it only when
        // opening the initial mode: applying its short/tall dimensions again after a mode switch
        // makes both modes render alike.
        final legacyState = await owner.invokeMethod<dynamic>(
          'getWindowState',
          'overlay',
        );
        if (legacyState is Map && legacyState.isNotEmpty) {
          windowState = legacyState;
        }
      }
    } catch (_) {
      // Fall through to the default size below.
    }
    if (!mounted || request != restoreRequest || lastMode != mode) return;

    final width = (windowState?['width'] as num?)?.toDouble() ?? 0;
    final height = (windowState?['height'] as num?)?.toDouble() ?? 0;
    // A legacy or previously mis-saved 96px-high state is the minimal bar. It cannot restore the
    // floating mode, whose layout deliberately needs at least 260px of height.
    final usableForMode =
        width >= 320 && height >= 96 && (mode == 'minimal' || height >= 260);
    if (usableForMode) {
      await _windowOption(() => windowManager.setSize(Size(width, height)));
    } else {
      await _windowOption(() => windowManager.setSize(_defaultSizeFor(mode)));
    }

    final x = (windowState?['x'] as num?)?.toDouble();
    final y = (windowState?['y'] as num?)?.toDouble();
    if (x != null && y != null) {
      await _windowOption(() => windowManager.setPosition(Offset(x, y)));
    }
  }

  Future<void> _saveWindowState(String mode) async {
    try {
      final position = await windowManager.getPosition();
      final size = await windowManager.getSize();
      await owner.invokeMethod('saveWindowState', {
        'windowKey': _windowStateKey(mode),
        'x': position.dx,
        'y': position.dy,
        'width': size.width,
        'height': size.height,
      });
    } catch (error) {
      debugPrint('overlay: saving the window state failed: $error');
    }
  }

  @override
  void dispose() {
    saveTimer?.cancel();
    windowManager.removeListener(this);
    app.removeListener(_changed);
    app.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    if (!restored) return;
    saveTimer?.cancel();
    final mode = lastMode.isEmpty ? 'floating' : lastMode;
    saveTimer = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_saveWindowState(mode)),
    );
  }

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowClose() => _invokeOwnerSafely(owner, 'showMain');

  @override
  Widget build(BuildContext context) {
    final theme = buildForuiTheme(app.darkMode);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: app.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...FLocalizations.localizationsDelegates,
      ],
      color: Colors.transparent,
      theme: theme.toApproximateMaterialTheme().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      builder: (context, child) =>
          FTheme(data: theme, platform: FPlatformVariant.macOS, child: child!),
      home: Builder(
        builder: (context) => OverlaySurface(app: app, owner: owner),
      ),
    );
  }
}

class OverlaySurface extends StatefulWidget {
  const OverlaySurface({required this.app, required this.owner, super.key});
  final AppController app;
  final WindowController owner;
  @override
  State<OverlaySurface> createState() => _OverlaySurfaceState();
}

class _OverlaySurfaceState extends State<OverlaySurface> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final settings = widget.app.settings;
    final backgroundOpacity =
        ((settings['backgroundOpacity'] as num?)?.toDouble().clamp(0, 1) ?? .94)
            .toDouble();
    final textOpacity =
        ((settings['textOpacity'] as num?)?.toDouble().clamp(0, 1) ?? 1)
            .toDouble();
    final minimalMode = settings['overlayMode'] == 'minimal';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onEnter: (_) => setState(() => hovering = true),
        onExit: (_) => setState(() => hovering = false),
        child: Stack(
          children: [
            Positioned.fill(
              child: DragToMoveArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Follow the window that actually exists, not just the saved mode. The two can
                    // disagree -- a 760x96 window rendering the floating layout is exactly what
                    // produced "A RenderFlex overflowed by 99 pixels on the bottom" -- and the
                    // floating layout needs this much height before it stops fitting.
                    final compact = minimalMode || constraints.maxHeight < 260;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.colors.background.withValues(
                          alpha: backgroundOpacity,
                        ),
                        border: Border.all(
                          color: context.colors.border.withValues(
                            alpha: backgroundOpacity,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(compact ? 8 : 12),
                      ),
                      child: ClipRect(
                        child: Opacity(
                          opacity: textOpacity,
                          child: compact
                              ? MinimalOverlay(app: widget.app)
                              : FloatingOverlay(
                                  app: widget.app,
                                  owner: widget.owner,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned.fill(
              // Above the content so the edges are grabbable, below the controls so the buttons
              // still win where they overlap the top-right corner.
              child: _OverlayResizeFrame(),
            ),
            if (hovering)
              Positioned(
                top: 5,
                right: 5,
                child: _OverlayControls(
                  key: const ValueKey('overlay-controls'),
                  app: widget.app,
                  owner: widget.owner,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Edge and corner grips that start a native resize.
///
/// A frameless window has no non-client area left for Windows to hit-test, which is why dragging an
/// edge used to do nothing at all. window_manager's startResizing re-enters the native resize loop
/// for the requested edge, so this is what makes both overlay modes resizable by hand.
class _OverlayResizeFrame extends StatelessWidget {
  const _OverlayResizeFrame();

  static const double _edge = 6;
  static const double _corner = 14;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      _grip(
        ResizeEdge.top,
        SystemMouseCursors.resizeUp,
        top: 0,
        left: 0,
        right: 0,
        height: _edge,
      ),
      _grip(
        ResizeEdge.bottom,
        SystemMouseCursors.resizeDown,
        bottom: 0,
        left: 0,
        right: 0,
        height: _edge,
      ),
      _grip(
        ResizeEdge.left,
        SystemMouseCursors.resizeLeft,
        top: 0,
        bottom: 0,
        left: 0,
        width: _edge,
      ),
      _grip(
        ResizeEdge.right,
        SystemMouseCursors.resizeRight,
        top: 0,
        bottom: 0,
        right: 0,
        width: _edge,
      ),
      // Corners last, so they win wherever they overlap an edge.
      _grip(
        ResizeEdge.topLeft,
        SystemMouseCursors.resizeUpLeft,
        top: 0,
        left: 0,
        width: _corner,
        height: _corner,
      ),
      _grip(
        ResizeEdge.topRight,
        SystemMouseCursors.resizeUpRight,
        top: 0,
        right: 0,
        width: _corner,
        height: _corner,
      ),
      _grip(
        ResizeEdge.bottomLeft,
        SystemMouseCursors.resizeDownLeft,
        bottom: 0,
        left: 0,
        width: _corner,
        height: _corner,
      ),
      _grip(
        ResizeEdge.bottomRight,
        SystemMouseCursors.resizeDownRight,
        bottom: 0,
        right: 0,
        width: _corner,
        height: _corner,
      ),
    ],
  );

  Widget _grip(
    ResizeEdge edge,
    MouseCursor cursor, {
    double? top,
    double? bottom,
    double? left,
    double? right,
    double? width,
    double? height,
  }) => Positioned(
    top: top,
    bottom: bottom,
    left: left,
    right: right,
    width: width,
    height: height,
    child: MouseRegion(
      cursor: cursor,
      // A raw pointer listener rather than a gesture: onPanStart only fires once the drag slop is
      // exceeded, and the resize has to start on the first down event so the native loop can take
      // the mouse capture and follow it.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => unawaited(windowManager.startResizing(edge)),
      ),
    ),
  );
}

/// The in-map clock.
///
/// The overlay receives its clock inside the pushed state, which lands a few times a second at best,
/// so this ticks itself between pushes through [AppController.liveMapTime] -- and it does so on its
/// own subtree, instead of a timer at the top of the overlay rebuilding everything twice a second.
class _LiveMapTime extends StatefulWidget {
  const _LiveMapTime({
    required this.app,
    this.fontSize,
    this.textAlign = TextAlign.start,
  });

  final AppController app;
  final double? fontSize;
  final TextAlign textAlign;

  @override
  State<_LiveMapTime> createState() => _LiveMapTimeState();
}

class _LiveMapTimeState extends State<_LiveMapTime> {
  Timer? ticker;

  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    formatDuration(widget.app.liveMapTime),
    textAlign: widget.textAlign,
    style: context.numberStyle.copyWith(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w600,
    ),
  );
}

class FloatingOverlay extends StatefulWidget {
  const FloatingOverlay({required this.app, required this.owner, super.key});
  final AppController app;

  /// The main window's controller. Session actions have to go through its engine: this overlay's
  /// own controller runs with startHost: false and has no tracker host to ask.
  final WindowController owner;
  @override
  State<FloatingOverlay> createState() => _FloatingOverlayState();
}

class _FloatingOverlayState extends State<FloatingOverlay> {
  /// Which of the two lists the tabs are showing. Pickups and costs are one list on the host side:
  /// every line carries a signed count, positive for what was picked up and negative for what was
  /// spent, which is exactly how the WinForms version split its two tabs.
  bool showCosts = false;

  Widget _footerAction(String icon, Color? color, VoidCallback onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 24,
          child: Center(child: AppSvg(icon, size: 13, color: color)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.app.snapshot;
    final l = AppLocalizations.of(context);
    final paused = s.trackingPaused;
    final pickups = [
      for (final entry in s.loot)
        if (entry.count > 0) entry,
    ];
    final costs = [
      for (final entry in s.loot)
        if (entry.count < 0) entry,
    ];

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 78),
            child: Row(
              children: [
                const AppLogo(size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.mapName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _OverlayMetric(
                  label: l.currentMap,
                  amount: s.currentProfitEx,
                  rate: s.divineRate,
                  fontSize: 16,
                ),
              ),
              Expanded(
                child: _OverlayMetric(
                  label: l.totalRevenue,
                  amount: s.totalProfitEx,
                  rate: s.divineRate,
                  fontSize: 16,
                ),
              ),
              // Was missing from this layout, even though the minimal bar and the main window both
              // show it.
              Expanded(
                child: _OverlayMetric(
                  label: l.revenuePerHour,
                  amount: s.perHourEx,
                  rate: s.divineRate,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OverlayTextMetric(
                  label: l.mapTime,
                  child: _LiveMapTime(app: widget.app, fontSize: 14),
                ),
              ),
              Expanded(
                child: _OverlayTextMetric(
                  label: l.sessionTime,
                  value: formatDuration(s.sessionTime),
                ),
              ),
              Expanded(
                child: _OverlayTextMetric(
                  label: l.averageMapTime,
                  value: formatDuration(s.averageMapTime),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 15,
            runSpacing: 8,
            children: [
              IconCount(
                icon: 'monster_normal',
                count: s.kills[0],
                compact: true,
              ),
              IconCount(
                icon: 'monster_magic',
                count: s.kills[1],
                compact: true,
              ),
              IconCount(icon: 'monster_rare', count: s.kills[2], compact: true),
              IconCount(
                icon: 'monster_unique',
                count: s.kills[3],
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final tabs = LootTabs(
                pickups: pickups.length,
                costs: costs.length,
                showCosts: showCosts,
                onSelect: (value) => setState(() => showCosts = value),
              );
              final selector = CostPresetSelector(
                presets: widget.app.costPresets,
                selectedId: s.inMap
                    ? s.currentCostPresetId
                    : widget.app.selectedCostPresetId,
                compact: true,
                onChanged: (id) => _invokeOwnerSafely(
                  widget.owner,
                  'selectCostPreset',
                  {'presetId': id ?? ''},
                ),
              );
              if (constraints.maxWidth < 350) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [tabs, const SizedBox(height: 8), selector],
                );
              }
              return Row(
                children: [
                  tabs,
                  const Spacer(),
                  SizedBox(width: 190, child: selector),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Expanded(
            child: LootList(
              rows: showCosts ? costs : pickups,
              divineRate: s.divineRate,
              empty: showCosts ? l.noCosts : l.waitingForPickups,
              // Priced from inside the overlay as well. The write cannot go through this window's
              // own controller -- it runs with startHost: false and owns no tracker host -- so it is
              // forwarded to the main engine, and the new price comes back on the next state push.
              onPrice: (entry) => showManualPriceDialog(
                context,
                itemKey: entry.key,
                name: entry.name,
                divineRate: s.divineRate,
                onApply: (value) async {
                  await widget.owner.invokeMethod('setManualPrice', {
                    'itemKey': entry.key,
                    'priceEx': value,
                  });
                },
                onClear: () async {
                  await widget.owner.invokeMethod('clearManualPrice', {
                    'itemKey': entry.key,
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.gameConnected
                      ? tradingGreen
                      : context.colors.mutedForeground,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                s.gameConnected ? l.trackingActive : l.waitingForGame,
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.mutedForeground,
                ),
              ),
              const Spacer(),
              // Always-visible session controls, matching what the WinForms overlay drew in both
              // of its modes: the hover strip is easy to miss mid-run.
              _footerAction(
                paused ? 'play' : 'pause',
                paused ? brandYellow : null,
                () => widget.owner.invokeMethod('pauseOrResume'),
              ),
              const SizedBox(width: 2),
              _footerAction(
                'plus',
                null,
                () => widget.owner.invokeMethod('newSession'),
              ),
              const SizedBox(width: 10),
              Text(
                '${s.mapCount}',
                style: context.numberStyle.copyWith(fontSize: 12),
              ),
              const SizedBox(width: 5),
              Text(
                l.mapCount,
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MinimalOverlay extends StatelessWidget {
  const MinimalOverlay({required this.app, super.key});
  final AppController app;
  @override
  Widget build(BuildContext context) {
    final s = app.snapshot;
    final l = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The compact default is deliberately narrow. Put a metric's label above its value there
        // so the three bottom metrics retain enough room for their numbers.
        final stackBottomMetrics = constraints.maxWidth <= 500;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 80),
                        child: Text(
                          s.mapName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    _InlineLabel(
                      label: l.mapTime,
                      child: _LiveMapTime(app: app, textAlign: TextAlign.start),
                    ),
                    const SizedBox(width: 18),
                    IconCount(
                      icon: 'monster_normal',
                      count: s.kills[0],
                      compact: true,
                    ),
                    const SizedBox(width: 10),
                    IconCount(
                      icon: 'monster_magic',
                      count: s.kills[1],
                      compact: true,
                    ),
                    const SizedBox(width: 10),
                    IconCount(
                      icon: 'monster_rare',
                      count: s.kills[2],
                      compact: true,
                    ),
                    const SizedBox(width: 10),
                    IconCount(
                      icon: 'monster_unique',
                      count: s.kills[3],
                      compact: true,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.colors.border),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _InlineLabel(
                        label: l.currentMap,
                        stacked: stackBottomMetrics,
                        child: AmountView(
                          s.currentProfitEx,
                          s.divineRate,
                          fontSize: 14,
                          color: s.currentProfitEx < 0
                              ? tradingRed
                              : tradingGreen,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _InlineLabel(
                        label: l.totalRevenue,
                        stacked: stackBottomMetrics,
                        child: AmountView(
                          s.totalProfitEx,
                          s.divineRate,
                          fontSize: 14,
                          color: s.totalProfitEx < 0
                              ? tradingRed
                              : tradingGreen,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _InlineLabel(
                        label: l.revenuePerHour,
                        stacked: stackBottomMetrics,
                        child: AmountView(
                          s.perHourEx,
                          s.divineRate,
                          fontSize: 14,
                          color: s.perHourEx < 0 ? tradingRed : tradingGreen,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _InlineLabel(
                        label: l.averageMapTime,
                        stacked: stackBottomMetrics,
                        child: Text(
                          formatDuration(s.averageMapTime),
                          style: context.numberStyle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OverlayMetric extends StatelessWidget {
  const _OverlayMetric({
    required this.label,
    required this.amount,
    required this.rate,
    this.fontSize = 18,
  });
  final String label;
  final double amount;
  final double rate;
  final double fontSize;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 10, color: context.colors.mutedForeground),
      ),
      const SizedBox(height: 5),
      AmountView(
        amount,
        rate,
        fontSize: fontSize,
        color: amount < 0 ? tradingRed : tradingGreen,
      ),
    ],
  );
}

class _OverlayTextMetric extends StatelessWidget {
  const _OverlayTextMetric({required this.label, this.value, this.child});
  final String label;
  final String? value;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 9, color: context.colors.mutedForeground),
      ),
      const SizedBox(height: 4),
      child ??
          Text(
            value!,
            style: context.numberStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
    ],
  );
}

class _InlineLabel extends StatelessWidget {
  const _InlineLabel({
    required this.label,
    required this.child,
    this.stacked = false,
  });
  final String label;
  final Widget child;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 10, color: context.colors.mutedForeground),
    );
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelWidget,
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: child,
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [labelWidget, const SizedBox(width: 7), child],
    );
  }
}

class _OverlayControls extends StatelessWidget {
  const _OverlayControls({required this.app, required this.owner, super.key});
  final AppController app;
  final WindowController owner;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.card,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The way back to the main window, and it deliberately routes through the owner engine:
          // that engine drives the main window with window_manager, whereas the multi-window plugin's
          // own show/hide has no visible effect on it.
          _control('maximize', () => _invokeOwnerSafely(owner, 'showMain')),
          _control('overlay', _toggleMode),
          _control('settings', () => _showQuickSettings(context)),
          _control(
            'mouse',
            _toggleClickThrough,
            key: const ValueKey('toggle-click-through'),
            color: app.settings['clickThrough'] == true ? brandYellow : null,
          ),
          // Session controls. These cannot call AppController directly: this engine's controller runs
          // with startHost: false and has no tracker host of its own, so the owner engine -- which
          // does -- performs the action and pushes the resulting state back.
          _control(
            app.snapshot.trackingPaused ? 'play' : 'pause',
            () => _invokeOwnerSafely(owner, 'pauseOrResume'),
            color: app.snapshot.trackingPaused ? brandYellow : null,
          ),
          _control('plus', () => _invokeOwnerSafely(owner, 'newSession')),
          // No minimize control: the overlay is a skipTaskbar window, so minimizing it left no way
          // back to it (and SW_SHOW does not restore a minimized window, so the tray could not bring
          // it back either). Collapsing is what the middle control is for.
          _control('close', () => _invokeOwnerSafely(owner, 'showMain')),
        ],
      ),
    );
  }

  Widget _control(
    String icon,
    VoidCallback callback, {
    Key? key,
    Color? color,
  }) => InkWell(
    key: key,
    onTap: callback,
    child: SizedBox.square(
      dimension: 28,
      child: Center(child: AppSvg(icon, size: 15, color: color)),
    ),
  );

  void _toggleMode() {
    final previous = app.settings['overlayMode']?.toString() ?? 'floating';
    final next = nextOverlayMode(previous);
    _updateSettings({'overlayMode': next});
  }

  void _toggleClickThrough() {
    final enabled = app.settings['clickThrough'] as bool? ?? false;
    _updateSettings({'clickThrough': !enabled});
  }

  void _updateSettings(Map<String, dynamic> changes) {
    // Apply the click immediately. Waiting for the owner to push state back over a second channel
    // invocation made the controls appear inert even when the setting had been saved successfully.
    app.applyForwardedState({
      'settings': <String, dynamic>{...app.settings, ...changes},
    });

    unawaited(() async {
      try {
        final state = await owner.invokeMethod<dynamic>(
          'updateOverlaySettings',
          changes,
        );
        if (state is Map) {
          app.applyForwardedState(state.cast<String, dynamic>());
        }
      } catch (error, stackTrace) {
        // Keep the local window in the mode the user selected. Reverting after the 20-second host
        // timeout is the exact "flashes once and changes back" symptom; a later authoritative
        // state push can still reconcile it after the host becomes responsive.
        debugPrint('overlay owner call failed (updateOverlaySettings): $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }());
  }

  void _showQuickSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _OverlayQuickSettings(app: app, owner: owner),
    );
  }
}

/// The overlay cannot rely on the main window being visible, so its hover strip includes this
/// compact version of the appearance controls needed mid-map.
class _OverlayQuickSettings extends StatefulWidget {
  const _OverlayQuickSettings({required this.app, required this.owner});
  final AppController app;
  final WindowController owner;

  @override
  State<_OverlayQuickSettings> createState() => _OverlayQuickSettingsState();
}

class _OverlayQuickSettingsState extends State<_OverlayQuickSettings> {
  String? adjustingOpacity;

  void _update(Map<String, dynamic> changes) {
    widget.app.applyForwardedState({
      'settings': <String, dynamic>{...widget.app.settings, ...changes},
    });
    setState(() {});
    unawaited(() async {
      try {
        final state = await widget.owner.invokeMethod<dynamic>(
          'updateOverlaySettings',
          changes,
        );
        if (state is Map) {
          widget.app.applyForwardedState(state.cast<String, dynamic>());
        }
      } catch (error, stackTrace) {
        debugPrint('overlay owner call failed (updateOverlaySettings): $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = widget.app.settings;
    final mode = settings['overlayMode']?.toString() ?? 'floating';
    final windowStyle = overlayWindowStyle(settings['overlayWindowStyle']);
    final backgroundOpacity =
        ((settings['backgroundOpacity'] as num?)?.toDouble().clamp(0, 1) ?? .94)
            .toDouble();
    final textOpacity =
        ((settings['textOpacity'] as num?)?.toDouble().clamp(0, 1) ?? 1.0)
            .toDouble();
    final adjusting = adjustingOpacity != null;
    return Dialog(
      backgroundColor: adjusting ? Colors.transparent : context.colors.card,
      elevation: 0,
      child: SizedBox(
        width: adjusting ? 300 : 270,
        child: Padding(
          padding: EdgeInsets.all(adjusting ? 0 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!adjusting) ...[
                Text(l.settings, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Text(l.overlayMode)),
                    DropdownButton<String>(
                      value: mode,
                      items: [
                        DropdownMenuItem(
                          value: 'floating',
                          child: Text(l.floating),
                        ),
                        DropdownMenuItem(
                          value: 'minimal',
                          child: Text(l.minimal),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) _update({'overlayMode': value});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(l.windowAppearance)),
                    DropdownButton<String>(
                      value: windowStyle,
                      items: [
                        DropdownMenuItem(
                          value: 'frameless',
                          child: Text(l.framelessWindow),
                        ),
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text(l.normalWindow),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _update({'overlayWindowStyle': value});
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (adjustingOpacity == null || adjustingOpacity == 'text')
                _opacitySlider(
                  key: const ValueKey('text-opacity'),
                  value: textOpacity,
                  onChanged: (value) => _update({'textOpacity': value}),
                  onStart: () => setState(() => adjustingOpacity = 'text'),
                  onEnd: (value) {
                    _update({'textOpacity': value});
                    setState(() => adjustingOpacity = null);
                  },
                ),
              if (adjustingOpacity == null || adjustingOpacity == 'background')
                _opacitySlider(
                  key: const ValueKey('background-opacity'),
                  value: backgroundOpacity,
                  onChanged: (value) => _update({'backgroundOpacity': value}),
                  onStart: () =>
                      setState(() => adjustingOpacity = 'background'),
                  onEnd: (value) {
                    _update({'backgroundOpacity': value});
                    setState(() => adjustingOpacity = null);
                  },
                ),
              if (!adjusting) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(l.clickThrough)),
                    FSwitch(
                      value: settings['clickThrough'] as bool? ?? false,
                      onChange: (value) {
                        _update({'clickThrough': value});
                        if (value) Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).closeButtonLabel,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _opacitySlider({
    required Key key,
    required double value,
    required ValueChanged<double> onChanged,
    required VoidCallback onStart,
    required ValueChanged<double> onEnd,
  }) => KeyedSubtree(
    key: key,
    child: Slider(
      value: value,
      activeColor: brandYellow,
      onChangeStart: (_) => onStart(),
      onChanged: onChanged,
      onChangeEnd: onEnd,
    ),
  );
}

@visibleForTesting
String nextOverlayMode(Object? current) =>
    current == 'minimal' ? 'floating' : 'minimal';

/// Keep old or malformed persisted values compatible with the original presentation.
String overlayWindowStyle(Object? value) =>
    value == 'normal' ? 'normal' : 'frameless';

void _invokeOwnerSafely(
  WindowController owner,
  String method, [
  dynamic arguments,
]) {
  unawaited(() async {
    try {
      await owner.invokeMethod(method, arguments);
    } catch (error, stackTrace) {
      debugPrint('overlay owner call failed ($method): $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }());
}
