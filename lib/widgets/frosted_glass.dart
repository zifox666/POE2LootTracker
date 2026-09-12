import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Fraction of the background-opacity setting that reaches the frost tint.
///
/// The plate is meant to be looked *through*, so the glass keeps a third of the setting in reserve:
/// at the 0.94 default a full-strength tint would hide the game exactly as much as the flat panel
/// this replaces, and the sheen and the bloom would have nothing to sit on top of.
const double frostedTintScale = .68;

/// The tint's opacity for a 0..1 background-opacity setting.
double frostedTintAlpha(double opacity) =>
    (opacity.clamp(0, 1).toDouble() * frostedTintScale).clamp(0, 1).toDouble();

/// Grain speckles in plate-relative coordinates.
///
/// Built once from a fixed seed: the texture has to stay put while the window is resized or the
/// tracker repaints. Grain that moved every frame would read as shimmer rather than as glass.
final List<Offset> _grain = _buildGrain();

List<Offset> _buildGrain() {
  final random = math.Random(0x504F4532);
  return List<Offset>.generate(
    260,
    (_) => Offset(random.nextDouble(), random.nextDouble()),
    growable: false,
  );
}

/// A hand-rolled frosted-glass panel: a translucent frost, a bloom and sheen from the top-left, a
/// fine grain, and a bright inner edge.
///
/// The overlay window stays natively transparent, and Windows' own blur is deliberately *not* asked
/// for. On this window class -- a layered child window with per-pixel alpha -- the composition API
/// produced an opaque black plate instead of the desktop behind it, and the newer system-backdrop
/// path is Windows 11 only and equally unreliable there. A [BackdropFilter] cannot stand in either:
/// it samples this engine's own layer tree, and nothing of the game is ever in it.
///
/// So this paints the look of frosted glass instead of its physics. That is all the overlay needs:
/// it is a legibility layer drawn over the game, not a window material, and it has to behave the
/// same on every Windows version.
class FrostedGlassLayer extends StatelessWidget {
  const FrostedGlassLayer({
    required this.tint,
    required this.opacity,
    required this.radius,
    this.showBorder = true,
    this.child,
    super.key,
  });

  /// The plate's base colour, normally the theme's own window background.
  final Color tint;

  /// The 0..1 background-opacity setting. It scales the frost, so the existing slider keeps meaning
  /// "how much of the game the overlay hides".
  final double opacity;

  /// Corner radius of the plate, matched to the window it fills.
  final double radius;

  /// Whether to draw the bright inner edge. This is what the "transparent overlay border" setting
  /// turns off.
  final bool showBorder;

  /// The overlay content, clipped to the plate's rounded corners.
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    // `painter`, not `foregroundPainter`: the frost is the plate the content sits on.
    painter: _FrostPainter(
      tint: tint,
      opacity: opacity.clamp(0, 1).toDouble(),
      radius: radius,
      showBorder: showBorder,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: child,
    ),
  );
}

class _FrostPainter extends CustomPainter {
  const _FrostPainter({
    required this.tint,
    required this.opacity,
    required this.radius,
    required this.showBorder,
  });

  final Color tint;
  final double opacity;
  final double radius;
  final bool showBorder;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    // Inset by half a pixel so the rim, whose stroke straddles the path, is not clipped in half by
    // the window edge.
    final plate = RRect.fromRectAndRadius(
      rect.deflate(.5),
      Radius.circular(math.min(radius, size.shortestSide / 2)),
    );
    final strength = opacity.clamp(0, 1).toDouble();

    // 1. Frost. Everything else is decoration on top of this tint, and without it the plate would
    //    be an empty frame -- which is exactly how the overlay looked while the native blur was in
    //    place.
    canvas.drawRRect(
      plate,
      Paint()..color = tint.withValues(alpha: frostedTintAlpha(strength)),
    );

    canvas.save();
    canvas.clipRRect(plate);

    // 2. Bloom: light entering from outside the top-left corner, strongest at the corner itself.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * .06, -size.height * .12),
          size.longestSide * .9,
          [
            Colors.white.withValues(alpha: .13 * strength + .02),
            Colors.white.withValues(alpha: .015),
            Colors.transparent,
          ],
          const [0, .45, 1],
        ),
    );

    // 3. Sheen: a diagonal shade, so the sheet is not lit uniformly and the far corner stays the
    //    clearest part of the glass.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .05 * strength),
            Colors.transparent,
            Colors.black.withValues(alpha: .16 * strength),
          ],
          stops: const [0, .55, 1],
        ).createShader(rect),
    );

    // 4. Grain: a fine speckle, scaled with the plate so its density stays constant, and only
    //    enough of it to stop the sheet reading as flat cellophane.
    if (size.width > 12 && size.height > 12) {
      final visible = math.min(
        _grain.length,
        math.max(24, (size.width * size.height / 1500).round()),
      );
      canvas.drawPoints(
        ui.PointMode.points,
        [
          for (var i = 0; i < visible; i++)
            Offset(_grain[i].dx * size.width, _grain[i].dy * size.height),
        ],
        Paint()
          ..color = Colors.white.withValues(alpha: .03 + .05 * strength)
          ..strokeWidth = 1,
      );
    }

    canvas.restore();

    // 5. Rim: the edge catches the light along the top-left and fades towards the far corner.
    if (showBorder) {
      canvas.drawRRect(
        plate,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .34 + .12 * strength),
              Colors.white.withValues(alpha: .10),
              Colors.white.withValues(alpha: .05),
            ],
            stops: const [0, .5, 1],
          ).createShader(rect),
      );
      // A second, fainter rim just inside the first: light that has already bled through the glass.
      // Without it the edge reads as a flat one-pixel outline.
      canvas.drawRRect(
        plate.deflate(2.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: .03 + .04 * strength),
      );
    }
  }

  @override
  bool shouldRepaint(_FrostPainter oldDelegate) =>
      oldDelegate.tint != tint ||
      oldDelegate.opacity != opacity ||
      oldDelegate.radius != radius ||
      oldDelegate.showBorder != showBorder;
}
