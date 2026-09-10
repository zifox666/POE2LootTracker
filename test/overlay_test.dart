import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:poe2_loot_tracker/app_controller.dart';
import 'package:poe2_loot_tracker/app_theme.dart';
import 'package:poe2_loot_tracker/l10n/app_localizations.dart';
import 'package:poe2_loot_tracker/overlay_window.dart';

void main() {
  test('overlay mode toggles in both directions', () {
    expect(nextOverlayMode('floating'), 'minimal');
    expect(nextOverlayMode('minimal'), 'floating');
  });

  testWidgets('minimal overlay renders exactly two information rows', (
    tester,
  ) async {
    final controller = AppController(startHost: false);
    final theme = buildForuiTheme(true);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...FLocalizations.localizationsDelegates,
        ],
        theme: theme.toApproximateMaterialTheme(),
        builder: (context, child) => FTheme(
          data: theme,
          platform: FPlatformVariant.macOS,
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 380,
            height: 96,
            child: MinimalOverlay(app: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Map time'), findsOneWidget);
    expect(find.text('Current map'), findsOneWidget);
    expect(find.text('Average map time'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    controller.dispose();
  });
}
