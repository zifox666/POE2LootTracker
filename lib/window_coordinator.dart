import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'app_controller.dart';

class WindowCoordinator {
  WindowCoordinator({required this.currentWindow, required this.app});
  final WindowController currentWindow;
  final AppController app;
  WindowController? overlayWindow;
  WindowController? recentLootWindow;
  String? lastPresentedPickup;
  bool? pickupToastsEnabled;

  /// How the overlay's own "new session" button starts one, when the shell has wired it up.
  ///
  /// The button used to call [AppController.newSession] straight through, which skipped the
  /// confirmation the main window asks before discarding an active session -- the same setting the
  /// settings tab exposes as "confirm a new session". Only a `State` can show that dialog, because
  /// it needs a `Navigator`, so the shell installs its own handler here.
  Future<void> Function()? onNewSession;

  Future<void> initialize() async {
    await currentWindow.setWindowMethodHandler(_handleCall);
    app.addListener(_forwardState);
  }

  /// Enters small-window mode: create-once, show the overlay, hand it the current state, then put
  /// the main window away. Order matters -- the main window is only hidden *after* the overlay has
  /// actually been shown, so a failed overlay never leaves the user with no window at all.
  ///
  /// Returns whether the overlay is now up. Every step is checked because this used to fail
  /// silently: `WindowController.create` reports a failed window/engine creation as an *empty*
  /// window id rather than as an error, and the follow-up `show()` on that id answers
  /// "failed to find target window" -- a PlatformException on a future nobody awaited, which from
  /// the outside is indistinguishable from the button not being wired up at all. The reason is now
  /// pushed to [AppController.setError] so the shell can show it.
  Future<bool> showOverlay({bool hideMain = true}) async {
    try {
      var overlay = overlayWindow;
      if (overlay == null) {
        overlay = await WindowController.create(
          WindowConfiguration(
            arguments: jsonEncode({
              'kind': 'overlay',
              'ownerId': currentWindow.windowId,
            }),
            hiddenAtLaunch: true,
          ),
        );
        if (overlay.windowId.isEmpty) {
          throw StateError(
            'the multi-window plugin returned an empty window id, so the overlay window was not '
            'created (engine creation failed)',
          );
        }
        overlayWindow = overlay;
      }
      await overlay.show();
      // The child shows and verifies its own HWND before the main window is put away. In
      // particular this makes reopening a previously hidden overlay reliable: WindowController's
      // fire-and-forget SW_SHOW call alone cannot tell us whether the native window became visible.
      final ready = await _prepareWindow(overlay, 'overlay');
      if (ready != true) {
        throw StateError(
          'the overlay did not confirm that its window is visible',
        );
      }
      if (hideMain) await _hideMainWindow();
      return true;
    } catch (exception) {
      app.setError('overlay: $exception');
      return false;
    }
  }

  /// Shows the configured overlay while leaving the main window available for first-run setup.
  Future<bool> previewOverlay() => showOverlay(hideMain: false);

  Future<void> hideOverlay() async {
    await overlayWindow?.hide();
  }

  /// A newly created Flutter engine may need a moment to install its Dart method handler. Waiting
  /// here also gives reused windows the same verified show path without hiding the main window on
  /// a failed first call.
  Future<bool> _prepareWindow(WindowController window, String label) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        final ready = await window.invokeMethod<bool>(
          'prepareToShow',
          app.forwardedState(),
        );
        if (ready == true) return true;
      } catch (error) {
        if (attempt == 19) {
          debugPrint('$label: prepareToShow failed: $error');
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  /// Makes the transparent pickup-toast surface visible without changing the main/overlay window.
  Future<bool> _showRecentLoot() async {
    try {
      var window = recentLootWindow;
      if (window == null) {
        window = await WindowController.create(
          WindowConfiguration(
            arguments: jsonEncode({
              'kind': 'recentLoot',
              'ownerId': currentWindow.windowId,
            }),
            hiddenAtLaunch: true,
          ),
        );
        if (window.windowId.isEmpty) {
          throw StateError('the recent-pickup window was not created');
        }
        recentLootWindow = window;
      }
      if (!await _prepareWindow(window, 'recent loot')) {
        throw StateError('the recent-pickup window is not visible');
      }
      app.setError(null);
      return true;
    } catch (exception) {
      app.setError('recent loot: $exception');
      return false;
    }
  }

  Future<bool> previewRecentLoot() async {
    if (!await _showRecentLoot()) return false;
    try {
      return await recentLootWindow?.invokeMethod<bool>('preview') == true;
    } catch (exception) {
      app.setError('recent loot preview: $exception');
      return false;
    }
  }

  /// Puts the main window away now that the overlay is actually up.
  ///
  /// window_manager goes first because it is the path this app already drives successfully -- the
  /// title bar's close button hides the window with `windowManager.hide` and that demonstrably
  /// works -- with the multi-window plugin's own `window_hide` kept as a second attempt. The
  /// result is then read back, because a hide that silently does nothing is precisely the reported
  /// symptom: the overlay opens and the main window just stays where it is.
  Future<void> _hideMainWindow() async {
    try {
      await windowManager.hide();
    } catch (error) {
      debugPrint('overlay: windowManager.hide failed: $error');
    }
    try {
      await currentWindow.hide();
    } catch (error) {
      debugPrint('overlay: currentWindow.hide failed: $error');
    }
    try {
      if (await windowManager.isVisible()) {
        app.setError('overlay: the main window is still visible after hide()');
      } else {
        app.setError(null);
      }
    } catch (error) {
      debugPrint('overlay: could not read the main window visibility: $error');
    }
  }

  /// Brings the main window back and puts the overlay away.
  ///
  /// The main window is shown through window_manager rather than the multi-window plugin:
  /// `window_show`/`window_hide` on the main window have no visible effect here, while
  /// window_manager is the path the window's own controls already drive successfully. The overlay
  /// is a window this plugin created itself, so its show/hide are the correct ones to use there.
  Future<void> showMain() async {
    try {
      await overlayWindow?.hide();
    } catch (error) {
      debugPrint('overlay: hiding the overlay failed: $error');
    }
    try {
      await windowManager.show();
    } catch (error) {
      debugPrint('main: windowManager.show failed: $error');
    }
    try {
      await currentWindow.show();
    } catch (error) {
      debugPrint('main: currentWindow.show failed: $error');
    }
    try {
      await windowManager.focus();
    } catch (error) {
      debugPrint('main: windowManager.focus failed: $error');
    }
  }

  Future<void> toggleWindows() async {
    if (await windowManager.isVisible()) {
      await showOverlay();
    } else {
      await showMain();
    }
  }

  Future<dynamic> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'getState':
        return app.forwardedState();
      case 'showMain':
        // The overlay's own "back to the main window" controls arrive here, so they have to take
        // the same reliable path as the tray does.
        await showMain();
        return true;
      case 'pauseOrResume':
        await app.pauseOrResume();
        return true;
      case 'newSession':
        final handler = onNewSession;
        if (handler == null) {
          await app.newSession();
          return true;
        }
        // That handler asks for confirmation in the main window's own `Navigator`, and the main
        // window is hidden while the overlay is up -- clicking the button there would look like it
        // did nothing at all. Only needed when the question is actually going to be asked.
        if (app.settings['confirmNewSession'] == true) await showMain();
        await handler();
        return true;
      case 'setManualPrice':
        // Priced from the overlay's own loot list. That window's controller has no tracker host, so
        // the write has to be performed here, by the engine that does.
        if (call.arguments is Map) {
          final value = (call.arguments as Map).cast<String, dynamic>();
          final price = (value['priceEx'] as num?)?.toDouble() ?? 0;
          if (price > 0) {
            await app.setManualPrice(value['itemKey']?.toString() ?? '', price);
          }
        }
        return true;
      case 'clearManualPrice':
        if (call.arguments is Map) {
          final value = (call.arguments as Map).cast<String, dynamic>();
          await app.clearManualPrice(value['itemKey']?.toString() ?? '');
        }
        return true;
      case 'selectCostPreset':
        if (call.arguments is Map) {
          final value = (call.arguments as Map).cast<String, dynamic>();
          await app.selectCostPreset(value['presetId']?.toString());
        }
        return true;
      case 'updateOverlaySettings':
        if (call.arguments is Map) {
          await app.updateSettings(
            (call.arguments as Map).cast<String, dynamic>(),
          );
        }
        // Return the new state on the same child -> owner request. Depending on a second, reverse
        // method-channel call here made mode switching fragile: the child could finish its click
        // without ever receiving the notification that tells it to rebuild. Snapshot broadcasts
        // still use [_sendState], but a user action gets its authoritative result directly.
        return app.forwardedState();
      case 'getWindowState':
        return app.getWindowState(call.arguments?.toString() ?? 'overlay');
      case 'saveWindowState':
        if (call.arguments is Map) {
          final value = (call.arguments as Map).cast<String, dynamic>();
          await app.saveWindowState(
            value['windowKey']?.toString() ?? 'overlay',
            (value['x'] as num).toDouble(),
            (value['y'] as num).toDouble(),
            (value['width'] as num).toDouble(),
            (value['height'] as num).toDouble(),
          );
        }
        return true;
    }
    return null;
  }

  void _forwardState() {
    unawaited(_sendState());
    final enabled = app.settings['pickupToastsEnabled'] as bool? ?? true;
    if (!enabled) {
      lastPresentedPickup = null;
      if (pickupToastsEnabled == true) {
        unawaited(recentLootWindow?.hide());
      }
      pickupToastsEnabled = false;
      return;
    }
    final pickup = app.snapshot.recentPickups.isEmpty
        ? null
        : app.snapshot.recentPickups.first;
    final signature = pickup == null
        ? null
        : '${pickup.key}|${pickup.count}|${pickup.pickedUpUtc}';
    if (pickupToastsEnabled != true) {
      pickupToastsEnabled = true;
      lastPresentedPickup = signature;
      return;
    }
    if (signature == null) return;
    if (signature == lastPresentedPickup) return;
    lastPresentedPickup = signature;
    unawaited(_showRecentLoot());
  }

  Future<void> _sendState() async {
    try {
      await overlayWindow?.invokeMethod('state', app.forwardedState());
    } catch (_) {}
    try {
      await recentLootWindow?.invokeMethod('state', app.forwardedState());
    } catch (_) {}
  }

  void dispose() => app.removeListener(_forwardState);
}
