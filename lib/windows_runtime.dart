import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'app_controller.dart';
import 'l10n/app_localizations.dart';
import 'window_coordinator.dart';

class WindowsRuntime with TrayListener, WindowListener {
  WindowsRuntime({required this.app, required this.windows});
  final AppController app;
  final WindowCoordinator windows;
  late final HotKey toggleHotKey = HotKey(
    key: PhysicalKeyboardKey.keyL,
    modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );
  Timer? saveTimer;
  bool restored = false;

  /// Set by the shell. Closing the window -- Alt+F4, the taskbar entry, or the title bar button --
  /// is routed through the confirm dialog instead of destroying the window outright.
  Future<void> Function()? onCloseRequested;

  /// Set by the shell, so the tray's "new session" goes through the same confirmation as the
  /// buttons do. Falls back to starting one directly when nobody is listening.
  Future<void> Function()? onNewSessionRequested;

  Future<void> initialize() async {
    trayManager.addListener(this);
    windowManager.addListener(this);
    // Take over the close so it can become a choice (quit vs keep tracking in the small window)
    // rather than an unconditional exit; the shell's handler decides what actually happens.
    await windowManager.setPreventClose(true);
    final separator = Platform.pathSeparator;
    final iconPath =
        '${File(Platform.resolvedExecutable).parent.path}${separator}data${separator}flutter_assets${separator}assets${separator}icons${separator}tray_icon.ico';
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('POE2 LootTracker');
    await hotKeyManager.register(
      toggleHotKey,
      keyDownHandler: (_) => unawaited(windows.toggleWindows()),
    );
  }

  Future<void> restoreMainState() async {
    if (restored || !app.startHost) return;
    restored = true;
    final state = await app.getWindowState('main');
    if (state.isEmpty) return;
    final width = (state['width'] as num?)?.toDouble() ?? 0;
    final height = (state['height'] as num?)?.toDouble() ?? 0;
    if (width >= 980 && height >= 680) {
      await windowManager.setSize(Size(width, height));
    }
    await windowManager.setPosition(
      Offset(
        (state['x'] as num?)?.toDouble() ?? 10,
        (state['y'] as num?)?.toDouble() ?? 10,
      ),
    );
  }

  void _scheduleSave() {
    if (!restored) return;
    saveTimer?.cancel();
    saveTimer = Timer(const Duration(milliseconds: 350), () async {
      final position = await windowManager.getPosition();
      final size = await windowManager.getSize();
      await app.saveWindowState(
        'main',
        position.dx,
        position.dy,
        size.width,
        size.height,
      );
    });
  }

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowResized() => _scheduleSave();

  String? menuSignature;

  Future<void> updateMenu(AppLocalizations l) async {
    // The tray menu has no incremental update: the native plugin rebuilds it from scratch (it
    // clears every item off one shared HMENU and re-appends the whole list) on each call. The
    // controller notifies on every `trackerSnapshot`, which the host pushes every 250 ms, so an
    // unconditional update here issued ~4 native menu rebuilds per second for a menu whose visible
    // text only changes with the language or the paused state.
    final signature = '${l.localeName}|${app.snapshot.trackingPaused}';
    if (signature == menuSignature) return;
    menuSignature = signature;
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'main',
            label: l.showMain,
            onClick: (_) => unawaited(windows.showMain()),
          ),
          MenuItem(
            key: 'overlay',
            label: l.showOverlay,
            onClick: (_) => unawaited(windows.showOverlay()),
          ),
          MenuItem(
            key: 'recentLoot',
            label: l.previewPickupNotifications,
            onClick: (_) => unawaited(windows.previewRecentLoot()),
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'pause',
            label: app.snapshot.trackingPaused ? l.resume : l.pause,
            onClick: (_) => unawaited(app.pauseOrResume()),
          ),
          MenuItem(
            key: 'newSession',
            label: l.newSession,
            onClick: (_) => unawaited(_requestNewSession()),
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit',
            label: l.exitApp,
            onClick: (_) => unawaited(shutdown()),
          ),
        ],
      ),
    );
  }

  Future<void> shutdown() async {
    await app.host.dispose();
    await trayManager.destroy();
    await windowManager.destroy();
  }

  /// The tray's "new session": the same question the title bar and the settings tab ask.
  ///
  /// The question is put by the main window's `Navigator`, and the tray is reachable while the main
  /// window is hidden in small-window mode, so it has to be brought back first -- otherwise the
  /// click would look like it did nothing. Skipped when the user turned the confirmation off.
  Future<void> _requestNewSession() async {
    final handler = onNewSessionRequested;
    if (handler == null) {
      await app.newSession();
      return;
    }
    if (app.settings['confirmNewSession'] == true) await windows.showMain();
    await handler();
  }

  @override
  void onTrayIconMouseDown() => unawaited(windows.showMain());

  @override
  void onWindowClose() {
    final handler = onCloseRequested;
    if (handler != null) unawaited(handler());
  }

  /// tray_manager never shows the menu by itself: the native side only reports the click, so a
  /// right-click did nothing at all.
  ///
  /// Deliberately *not* paired with an `onTrayMenuItemClick` override: tray_manager invokes both
  /// that listener and the item's own `onClick` closure, so handling the keys in both places would
  /// run every action twice -- pausing would toggle straight back, and exit would shut down twice.
  /// The actions live in the `MenuItem.onClick` closures built by [updateMenu].
  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  Future<void> dispose() async {
    saveTimer?.cancel();
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await hotKeyManager.unregister(toggleHotKey);
    await trayManager.destroy();
  }
}
