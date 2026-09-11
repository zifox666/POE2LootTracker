import 'package:flutter/services.dart';

/// Windows-side interaction support for the click-through overlay.
///
/// A fully transparent window cannot receive the hover that reveals its controls. The native
/// runner therefore keeps the window transparent everywhere except a small controls hot zone.
class OverlayInteraction {
  const OverlayInteraction();

  static const _channel = MethodChannel(
    'poe2_loot_tracker/overlay_interaction',
  );

  static const double controlsTop = 0;
  static const double controlsRight = 0;
  static const double controlsWidth = 206;
  static const double controlsHeight = 38;

  Future<void> setClickThrough(
    bool enabled, {
    double top = controlsTop,
    double right = controlsRight,
    double width = controlsWidth,
    double height = controlsHeight,
  }) => _channel.invokeMethod<void>('setClickThrough', <String, dynamic>{
    'enabled': enabled,
    'top': top,
    'right': right,
    'width': width,
    'height': height,
  });

  /// Changes the native z-order without activating the overlay.
  Future<void> setAlwaysOnTop(bool enabled) =>
      _channel.invokeMethod<void>('setAlwaysOnTop', enabled);

  /// Shows this engine's own native window and confirms that Windows considers it visible.
  ///
  /// The owner waits for this acknowledgement before hiding the main window. This prevents a
  /// stale or failed reused overlay from leaving the user with no visible window.
  Future<bool> ensureVisible() async =>
      await _channel.invokeMethod<bool>('ensureVisible') ?? false;
}
