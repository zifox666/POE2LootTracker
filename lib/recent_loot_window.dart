import 'dart:async';
import 'dart:collection';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:window_manager/window_manager.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'overlay_interaction.dart';
import 'widgets/common.dart';

const double _recentLootWindowWidth = 420;
const double _recentLootWindowHeight = 360;
const double _recentLootBaseHeight = 48;
const double _recentLootToastHeight = 58;

Future<void> configureRecentLootWindow() async {
  const options = WindowOptions(
    size: Size(_recentLootWindowWidth, _recentLootWindowHeight),
    minimumSize: Size(_recentLootWindowWidth, _recentLootWindowHeight),
    maximumSize: Size(
      _recentLootWindowWidth,
      _recentLootBaseHeight + 10 * _recentLootToastHeight,
    ),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    alwaysOnTop: true,
  );
  try {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
      await windowManager.setResizable(false);
      await windowManager.setTitle('POE2LootTracker - Pickup Notifications');
      await windowManager.setPreventClose(true);
    });
  } catch (error) {
    debugPrint('pickup notifications: window configuration failed: $error');
  }
}

class RecentLootApplication extends StatefulWidget {
  const RecentLootApplication({
    required this.currentWindow,
    required this.ownerId,
    super.key,
  });

  final WindowController currentWindow;
  final String ownerId;

  @override
  State<RecentLootApplication> createState() => _RecentLootApplicationState();
}

class _RecentLootApplicationState extends State<RecentLootApplication>
    with WindowListener {
  static const interaction = OverlayInteraction();
  final app = AppController(startHost: false);
  late final owner = WindowController.fromWindowId(widget.ownerId);
  late final Future<void> initialization;
  Timer? saveTimer;
  Timer? previewInteractionTimer;
  DateTime? previewUntil;
  bool restored = false;
  bool? appliedAlwaysOnTop;
  bool? appliedClickThrough;
  int? appliedMaxVisible;

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
        await initialization;
        await interaction.refreshRenderSurface();
        return interaction.ensureVisible();
      }
      if (call.method == 'preview') {
        final duration =
            (app.settings['pickupToastDurationSeconds'] as num?)?.toDouble() ??
            2.5;
        previewInteractionTimer?.cancel();
        await _setClickThrough(false);
        appliedClickThrough = false;
        previewInteractionTimer = Timer(
          Duration(milliseconds: (duration * 1000).round()),
          () {
            final clickThrough = app.settings['clickThrough'] as bool? ?? false;
            appliedClickThrough = clickThrough;
            unawaited(_setClickThrough(clickThrough));
          },
        );
        setState(() {
          previewUntil = DateTime.now().toUtc().add(
            Duration(milliseconds: (duration * 1000).round()),
          );
        });
        return interaction.ensureVisible();
      }
      return true;
    });
    initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      final state = await owner.invokeMethod<dynamic>('getState');
      if (state is Map) app.applyForwardedState(state.cast<String, dynamic>());
    } catch (_) {}

    var hasSavedPosition = false;
    try {
      final state = await owner.invokeMethod<dynamic>(
        'getWindowState',
        'recent-loot-left-center',
      );
      if (state is Map && state.isNotEmpty) {
        final x = (state['x'] as num?)?.toDouble();
        final y = (state['y'] as num?)?.toDouble();
        if (x != null && y != null) {
          await _windowOption(() => windowManager.setPosition(Offset(x, y)));
          hasSavedPosition = true;
        }
      }
    } catch (_) {}
    if (!hasSavedPosition) {
      await _windowOption(
        () => windowManager.setAlignment(Alignment.centerLeft),
      );
    }
    restored = true;
    if (mounted) setState(() {});
  }

  void _changed() {
    final alwaysOnTop =
        (app.settings['alwaysOnTop'] as bool? ?? true) &&
        !app.screenCaptureActive;
    if (alwaysOnTop != appliedAlwaysOnTop) {
      appliedAlwaysOnTop = alwaysOnTop;
      unawaited(_windowOption(() => interaction.setAlwaysOnTop(alwaysOnTop)));
    }
    final clickThrough = app.settings['clickThrough'] as bool? ?? false;
    if (clickThrough != appliedClickThrough) {
      appliedClickThrough = clickThrough;
      unawaited(_windowOption(() => _setClickThrough(clickThrough)));
    }
    final maxVisible =
        (app.settings['pickupToastMaxVisible'] as num?)?.toInt().clamp(1, 10) ??
        3;
    if (maxVisible != appliedMaxVisible) {
      appliedMaxVisible = maxVisible;
      unawaited(
        _windowOption(
          () => windowManager.setSize(
            Size(
              _recentLootWindowWidth,
              (_recentLootBaseHeight + maxVisible * _recentLootToastHeight)
                  .clamp(_recentLootWindowHeight, double.infinity)
                  .toDouble(),
            ),
          ),
        ),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _setClickThrough(bool enabled) => interaction.setClickThrough(
    enabled,
    top: 0,
    right: _recentLootWindowWidth - 72,
    width: 72,
    height: 48,
  );

  Future<void> _windowOption(Future<void> Function() apply) async {
    try {
      await apply();
    } catch (error) {
      debugPrint('pickup notifications: window option failed: $error');
    }
  }

  void _scheduleSave() {
    if (!restored) return;
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 350), _saveWindowState);
  }

  Future<void> _saveWindowState() async {
    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();
    await owner.invokeMethod('saveWindowState', {
      'windowKey': 'recent-loot-left-center',
      'x': position.dx,
      'y': position.dy,
      'width': size.width,
      'height': size.height,
    });
  }

  void _closeRecentLoot() {
    previewInteractionTimer?.cancel();
    final clickThrough = app.settings['clickThrough'] as bool? ?? false;
    appliedClickThrough = clickThrough;
    unawaited(_setClickThrough(clickThrough));
    setState(() => previewUntil = null);
    unawaited(widget.currentWindow.hide());
  }

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowClose() => unawaited(widget.currentWindow.hide());

  @override
  void dispose() {
    saveTimer?.cancel();
    previewInteractionTimer?.cancel();
    windowManager.removeListener(this);
    app.removeListener(_changed);
    app.dispose();
    super.dispose();
  }

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
      home: RecentLootSurface(
        app: app,
        canHide: restored,
        previewUntil: previewUntil,
        onIdle: () => widget.currentWindow.hide(),
        onClose: _closeRecentLoot,
      ),
    );
  }
}

class RecentLootSurface extends StatefulWidget {
  const RecentLootSurface({
    required this.app,
    this.canHide = true,
    required this.onIdle,
    required this.onClose,
    this.previewUntil,
    super.key,
  });

  final AppController app;
  final bool canHide;
  final DateTime? previewUntil;
  final VoidCallback onIdle;
  final VoidCallback onClose;

  @override
  State<RecentLootSurface> createState() => _RecentLootSurfaceState();
}

class _RecentLootSurfaceState extends State<RecentLootSurface> {
  static const fadeDuration = .6;
  final active = <_VisiblePickup>[];
  final pending = Queue<RecentPickupEntry>();
  final seen = <String>{};
  Timer? ticker;
  DateTime now = DateTime.now().toUtc();
  bool idleReported = false;
  bool hovering = false;
  bool previewHeld = false;
  bool dragging = false;
  bool draggingPreview = false;
  DateTime? dragFinishedUntil;
  String? sessionId;

  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    now = DateTime.now().toUtc();
    final life = _life;
    if (!dragging) {
      active.removeWhere(
        (toast) => now.difference(toast.shownUtc).inMilliseconds >= life * 1000,
      );
    }
    _promote();
    if (mounted) setState(() {});
  }

  double get _life =>
      (widget.app.settings['pickupToastDurationSeconds'] as num?)
          ?.toDouble()
          .clamp(1, 10) ??
      2.5;

  int get _limit =>
      (widget.app.settings['pickupToastMaxVisible'] as num?)?.toInt().clamp(
        1,
        10,
      ) ??
      3;

  void _ingest() {
    final currentSessionId = widget.app.snapshot.activeSessionId;
    if (sessionId != null && currentSessionId != sessionId) {
      active.clear();
      pending.clear();
      seen.clear();
    }
    sessionId = currentSessionId;
    final enabled = widget.app.settings['pickupToastsEnabled'] as bool? ?? true;
    for (final pickup in widget.app.snapshot.recentPickups.reversed) {
      final id = _pickupId(pickup);
      if (!seen.add(id) || !enabled) continue;
      final pickedUp = pickup.pickedUpUtc;
      if (pickedUp == null ||
          now.difference(pickedUp).inMilliseconds > _life * 1000) {
        continue;
      }
      pending.add(pickup);
    }
    if (!enabled) {
      active.clear();
      pending.clear();
    }
    while (pending.length > 30) {
      pending.removeFirst();
    }
    _promote();

    if (seen.length > 100) {
      final retained = <String>{
        for (final pickup in widget.app.snapshot.recentPickups)
          _pickupId(pickup),
        for (final toast in active) _pickupId(toast.pickup),
        for (final pickup in pending) _pickupId(pickup),
      };
      seen
        ..clear()
        ..addAll(retained);
    }
  }

  void _promote() {
    while (active.length > _limit) {
      pending.addFirst(active.removeLast().pickup);
    }
    while (active.length < _limit && pending.isNotEmpty) {
      active.add(_VisiblePickup(pending.removeFirst(), now));
    }
  }

  @override
  Widget build(BuildContext context) {
    _ingest();
    final preview =
        (widget.previewUntil?.isAfter(now) ?? false) ||
        previewHeld ||
        (draggingPreview &&
            (dragging || (dragFinishedUntil?.isAfter(now) ?? false)));
    final previewExpires = draggingPreview && dragFinishedUntil != null
        ? dragFinishedUntil
        : widget.previewUntil;
    if (active.isEmpty && !preview) {
      if (widget.canHide && !idleReported) {
        idleReported = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _hideIfIdle());
      }
      return const SizedBox.expand();
    }
    idleReported = false;

    final opacity =
        ((widget.app.settings['backgroundOpacity'] as num?)?.toDouble() ?? .94)
            .clamp(0, 1)
            .toDouble();
    final textOpacity =
        ((widget.app.settings['textOpacity'] as num?)?.toDouble() ?? 1)
            .clamp(0, 1)
            .toDouble();
    final toasts = <Widget>[
      for (final toast in active)
        _PickupToast(
          entry: toast.pickup,
          divineRate: widget.app.snapshot.divineRate,
          opacity: pickupToastOpacity(toast.shownUtc, now, _life, fadeDuration),
          backgroundOpacity: opacity,
          textOpacity: textOpacity,
        ),
      if (preview)
        _PickupToast(
          label: AppLocalizations.of(context).previewPickupNotifications,
          amount: '+20 E',
          opacity: previewHeld || dragging
              ? 1
              : pickupToastOpacity(
                  previewExpires!.subtract(
                    Duration(milliseconds: (_life * 1000).round()),
                  ),
                  now,
                  _life,
                  fadeDuration,
                ),
          backgroundOpacity: opacity,
          textOpacity: textOpacity,
        ),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onEnter: (_) => setState(() {
          hovering = true;
          previewHeld = widget.previewUntil?.isAfter(now) ?? false;
        }),
        onExit: (_) => setState(() {
          hovering = false;
          previewHeld = false;
        }),
        child: Stack(
          children: [
            Positioned.fill(
              child: _RecentLootDragArea(
                onDraggingChanged: _draggingChanged,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: toasts,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IgnorePointer(
                ignoring: !hovering,
                child: Opacity(
                  opacity: hovering ? 1 : 0,
                  child: _RecentLootControls(
                    onClose: widget.onClose,
                    onDraggingChanged: _draggingChanged,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _hideIfIdle() {
    if (!mounted) return;
    now = DateTime.now().toUtc();
    final preview =
        (widget.previewUntil?.isAfter(now) ?? false) ||
        previewHeld ||
        (draggingPreview &&
            (dragging || (dragFinishedUntil?.isAfter(now) ?? false)));
    if (active.isEmpty && pending.isEmpty && !preview) {
      widget.onIdle();
    } else {
      idleReported = false;
    }
  }

  void _draggingChanged(bool value) {
    if (dragging == value) return;
    setState(() {
      now = DateTime.now().toUtc();
      dragging = value;
      if (value) {
        draggingPreview =
            (widget.previewUntil?.isAfter(now) ?? false) || previewHeld;
      } else {
        dragFinishedUntil = now.add(
          Duration(milliseconds: (_life * 1000).round()),
        );
        for (var index = 0; index < active.length; index++) {
          active[index] = _VisiblePickup(active[index].pickup, now);
        }
      }
    });
  }
}

class _VisiblePickup {
  const _VisiblePickup(this.pickup, this.shownUtc);

  final RecentPickupEntry pickup;
  final DateTime shownUtc;
}

class _RecentLootControls extends StatelessWidget {
  const _RecentLootControls({
    required this.onClose,
    required this.onDraggingChanged,
  });

  final VoidCallback onClose;
  final ValueChanged<bool> onDraggingChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.card,
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.move,
          child: _RecentLootDragArea(
            key: const ValueKey('recent-loot-drag'),
            onDraggingChanged: onDraggingChanged,
            child: SizedBox.square(
              dimension: 28,
              child: Center(
                child: AppSvg(
                  'drag',
                  size: 18,
                  color: context.colors.mutedForeground,
                ),
              ),
            ),
          ),
        ),
        InkWell(
          onTap: onClose,
          child: const SizedBox.square(
            dimension: 28,
            child: Center(child: AppSvg('close', size: 13)),
          ),
        ),
      ],
    ),
  );
}

class _RecentLootDragArea extends StatelessWidget {
  const _RecentLootDragArea({
    required this.onDraggingChanged,
    required this.child,
    super.key,
  });

  final ValueChanged<bool> onDraggingChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onPanStart: (_) async {
      onDraggingChanged(true);
      try {
        await windowManager.startDragging();
      } finally {
        onDraggingChanged(false);
      }
    },
    child: child,
  );
}

class _PickupToast extends StatelessWidget {
  const _PickupToast({
    required this.opacity,
    required this.backgroundOpacity,
    required this.textOpacity,
    this.entry,
    this.divineRate = 0,
    this.label,
    this.amount,
  });

  final RecentPickupEntry? entry;
  final double divineRate;
  final String? label;
  final String? amount;
  final double opacity;
  final double backgroundOpacity;
  final double textOpacity;

  @override
  Widget build(BuildContext context) {
    final pickup = entry;
    final displayLabel =
        label ??
        (pickup!.count > 1 ? '${pickup.name} ×${pickup.count}' : pickup.name);
    final formattedAmount = pickup != null && pickup.priced
        ? formatAmount(pickup.totalEx, divineRate)
        : null;
    final displayAmount =
        amount ??
        (formattedAmount == null
            ? '—'
            : '+${formattedAmount.value} ${formattedAmount.unit}');
    final showIcon = pickup?.iconUrl.isNotEmpty ?? false;
    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52, maxWidth: 704),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.colors.background.withValues(
              alpha: backgroundOpacity,
            ),
            border: Border.all(
              color: context.colors.border.withValues(alpha: backgroundOpacity),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Opacity(
            opacity: textOpacity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showIcon) ...[
                  NetworkItemIcon(pickup!.iconUrl, size: 24),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  displayAmount,
                  style: context.numberStyle.copyWith(
                    color: formattedAmount == null && amount == null
                        ? context.colors.mutedForeground
                        : tradingGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _pickupId(RecentPickupEntry pickup) =>
    '${pickup.key}|${pickup.count}|${pickup.pickedUpUtc?.toIso8601String()}';

double pickupToastOpacity(
  DateTime shownUtc,
  DateTime nowUtc,
  double lifeSeconds,
  double fadeSeconds,
) {
  final age = nowUtc.difference(shownUtc).inMilliseconds / 1000;
  if (age <= lifeSeconds - fadeSeconds) return 1;
  return ((lifeSeconds - age) / fadeSeconds).clamp(0, 1).toDouble();
}
