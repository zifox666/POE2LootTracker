import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:poe2_loot_tracker/app_controller.dart';
import 'package:poe2_loot_tracker/app_theme.dart';
import 'package:poe2_loot_tracker/l10n/app_localizations.dart';
import 'package:poe2_loot_tracker/overlay_window.dart';
import 'package:poe2_loot_tracker/recent_loot_window.dart';

void main() {
  test('overlay mode toggles in both directions', () {
    expect(nextOverlayMode('floating'), 'minimal');
    expect(nextOverlayMode('minimal'), 'floating');
  });

  test('normal overlay window style is opt-in', () {
    expect(overlayWindowStyle('normal'), 'normal');
    expect(overlayWindowStyle('frameless'), 'frameless');
    expect(overlayWindowStyle(null), 'frameless');
  });

  test('pickup notification fades over its final 0.6 seconds', () {
    final shown = DateTime.utc(2026, 9, 11, 10);
    expect(
      pickupToastOpacity(
        shown,
        shown.add(const Duration(milliseconds: 2200)),
        2.5,
        .6,
      ),
      closeTo(.5, .001),
    );
    expect(
      pickupToastOpacity(
        shown,
        shown.add(const Duration(milliseconds: 2500)),
        2.5,
        .6,
      ),
      0,
    );
  });

  testWidgets('minimal overlay renders exactly two information rows', (
    tester,
  ) async {
    final controller = AppController(startHost: false);
    controller.applyForwardedState({
      'divineRmbPrice': 0.2,
      'snapshot': const <String, dynamic>{
        'divineRate': 100,
        'currentProfitEx': 100,
        'totalProfitEx': 200,
        'perHourEx': 300,
      },
    });
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
    expect(find.text('Total revenue'), findsOneWidget);
    expect(find.text('Average map time'), findsOneWidget);
    expect(find.text('¥0.20'), findsOneWidget);
    expect(find.text('¥0.40'), findsOneWidget);
    expect(find.text('¥0.60'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    controller.dispose();
  });

  testWidgets('recent loot window renders a standalone pickup toast', (
    tester,
  ) async {
    final controller = AppController(startHost: false);
    final pickedUp = DateTime.now().toUtc();
    controller.applyForwardedState({
      'settings': <String, dynamic>{
        ...controller.settings,
        'pickupToastsEnabled': true,
        'pickupToastMaxVisible': 3,
        'pickupToastDurationSeconds': 2.5,
      },
      'snapshot': <String, dynamic>{
        'divineRate': 120,
        'recentPickups': [
          {
            'key': 'divine',
            'name': 'Divine Orb',
            'count': 2,
            'unitEx': 120,
            'totalEx': 240,
            'priced': true,
            'iconUrl': '',
            'pickedUpUtc': pickedUp.toIso8601String(),
          },
        ],
      },
    });
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
        home: SizedBox(
          width: 340,
          height: 360,
          child: RecentLootSurface(
            app: controller,
            onIdle: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Divine Orb ×2'), findsOneWidget);
    expect(find.text('+2 D'), findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.text('Divine Orb ×2')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('recent-loot-drag')).hitTestable(),
      findsOneWidget,
    );
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
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
