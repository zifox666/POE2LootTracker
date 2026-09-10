import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

const brandYellow = Color(0xFFFCD535);
const tradingGreen = Color(0xFF0ECB81);
const tradingRed = Color(0xFFF6465D);

/// 思源黑体 (Source Han Sans -- the same typeface Google ships as Noto Sans CJK), bundled under
/// `assets/fonts` so the UI never depends on a system CJK font being installed.
const appFontFamily = 'Source Han Sans SC';

FThemeData buildForuiTheme(bool dark) {
  final colors = dark
      ? const FColors(
          brightness: Brightness.dark,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          barrier: Color(0x99000000),
          background: Color(0xFF0B0E11),
          foreground: Color(0xFFEAECEF),
          primary: brandYellow,
          primaryForeground: Color(0xFF181A20),
          secondary: Color(0xFF1E2329),
          secondaryForeground: Color(0xFFEAECEF),
          muted: Color(0xFF2B3139),
          mutedForeground: Color(0xFF929AA5),
          destructive: tradingRed,
          destructiveForeground: Colors.white,
          error: tradingRed,
          errorForeground: Colors.white,
          card: Color(0xFF1E2329),
          border: Color(0xFF2B3139),
        )
      : const FColors(
          brightness: Brightness.light,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          barrier: Color(0x33000000),
          background: Colors.white,
          foreground: Color(0xFF181A20),
          primary: brandYellow,
          primaryForeground: Color(0xFF181A20),
          secondary: Color(0xFFF5F5F5),
          secondaryForeground: Color(0xFF181A20),
          muted: Color(0xFFFAFAFA),
          mutedForeground: Color(0xFF707A8A),
          destructive: tradingRed,
          destructiveForeground: Colors.white,
          error: tradingRed,
          errorForeground: Colors.white,
          card: Colors.white,
          border: Color(0xFFEAECEF),
        );
  return FThemeData(
    colors: colors,
    touch: false,
    debugLabel: dark ? 'LootTracker Dark' : 'LootTracker Light',
    typography: FTypography.inherit(
      colors: colors,
      touch: false,
      // One place sets the font for the whole app: FThemeData.toApproximateMaterialTheme() carries
      // this family into the Material theme too, so Forui and Material widgets both follow it.
      fontFamily: appFontFamily,
    ),
  );
}

extension AppTheme on BuildContext {
  FColors get colors => FTheme.of(this).colors;

  /// Numbers use the same bundled family, with tabular figures so columns of digits line up.
  TextStyle get numberStyle => const TextStyle(
    fontFamily: appFontFamily,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
