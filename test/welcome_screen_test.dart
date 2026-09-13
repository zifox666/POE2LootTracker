import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:poe2_loot_tracker/app_controller.dart';
import 'package:poe2_loot_tracker/app_theme.dart';
import 'package:poe2_loot_tracker/l10n/app_localizations.dart';
import 'package:poe2_loot_tracker/screens/welcome_screen.dart';

void main() {
  testWidgets('welcome flow exposes all three required setup steps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController(startHost: false);
    var overlayPreviews = 0;
    final theme = buildForuiTheme(true);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
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
        home: WelcomeScreen(
          controller: controller,
          onShowOverlayPreview: () async {
            overlayPreviews++;
            return true;
          },
          onFinish: () async {},
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('选择语言和外观'), findsOneWidget);
    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();
    expect(find.text('选择当前联赛'), findsOneWidget);

    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();
    expect(find.text('设置小窗'), findsOneWidget);
    expect(find.text('悬浮小窗'), findsOneWidget);
    expect(find.text('极简小窗'), findsOneWidget);
    expect(find.text('窗口置顶'), findsOneWidget);
    expect(find.text('点击穿透'), findsOneWidget);
    expect(overlayPreviews, 1);
    expect(tester.takeException(), isNull);

    controller.dispose();
  });
}
