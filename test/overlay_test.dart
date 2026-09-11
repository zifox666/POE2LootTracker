import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/gestures.dart';
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

  for (final mode in ['floating', 'minimal']) {
    testWidgets('$mode overlay reveals top-right controls only on hover', (
      tester,
    ) async {
      final controller = AppController(startHost: false);
      controller.applyForwardedState({
        'settings': <String, dynamic>{
          ...controller.settings,
          'overlayMode': mode,
          'clickThrough': true,
        },
      });
      final theme = buildForuiTheme(true);
      final size = mode == 'minimal'
          ? const Size(380, 96)
          : const Size(520, 460);
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
          home: Center(
            child: SizedBox.fromSize(
              size: size,
              child: OverlaySurface(
                app: controller,
                owner: WindowController.fromWindowId('test-owner'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('overlay-controls')), findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getTopRight(find.byType(OverlaySurface)) + const Offset(-10, 10),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('overlay-controls')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('toggle-click-through')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('toggle-click-through')));
      await tester.pump();
      expect(controller.settings['clickThrough'], isFalse);
      await mouse.removePointer();
      controller.dispose();
    });
  }
}
