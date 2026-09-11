import 'package:flutter/services.dart';

/// Windows-side interaction support for the click-through overlay.
///
/// A fully transparent window cannot receive the hover that reveals its controls. The native
/// runner therefore keeps the window transparent everywhere except a small top-right hot zone.
/// That zone works in both overlay layouts because it is anchored to the current client width.
class OverlayInteraction {
  const OverlayInteraction();

  static const _channel = MethodChannel(
    'poe2_loot_tracker/overlay_interaction',
  );

  static const double controlsTop = 0;
  static const double controlsRight = 0;
  static const double controlsWidth = 206;
  static const double controlsHeight = 38;

  Future<void> setClickThrough(bool enabled) =>
      _channel.invokeMethod<void>('setClickThrough', <String, dynamic>{
        'enabled': enabled,
        'top': controlsTop,
        'right': controlsRight,
        'width': controlsWidth,
        'height': controlsHeight,
      });

  /// Shows this engine's own native window and confirms that Windows considers it visible.
  ///
  /// The owner waits for this acknowledgement before hiding the main window. This prevents a
  /// stale or failed reused overlay from leaving the user with no visible window.
  Future<bool> ensureVisible() async =>
      await _channel.invokeMethod<bool>('ensureVisible') ?? false;
}
