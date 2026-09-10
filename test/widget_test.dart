import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:poe2_loot_tracker/app_controller.dart';
import 'package:poe2_loot_tracker/app_theme.dart';
import 'package:poe2_loot_tracker/l10n/app_localizations.dart';
import 'package:poe2_loot_tracker/screens/main_shell.dart';

void main() {
  testWidgets('shows all four localized product tabs', (tester) async {
    final controller = AppController(startHost: false);
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
        home: MainShell(
          controller: controller,
          onShowOverlay: () {},
          onNewSession: () {},
          onCloseWindow: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('掉落统计'), findsWidgets);
    expect(find.text('市场价格'), findsOneWidget);
    expect(find.text('成本设置'), findsOneWidget);
    expect(find.text('设置'), findsWidgets);
    expect(find.text('当前成本'), findsOneWidget);
    await tester.tap(find.text('成本设置'));
    await tester.pumpAndSettle();
    expect(find.text('添加成本'), findsOneWidget);
    expect(find.text('暂无成本设置'), findsOneWidget);
    await tester.tap(find.text('添加成本'));
    await tester.pumpAndSettle();
    expect(find.text('默认成本'), findsWidgets);
    await tester.tap(find.text('选择地图'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Iron Citadel');
    await tester.pumpAndSettle();
    expect(find.text('钢铁城塞'), findsOneWidget);
    expect(find.text('鋼鐵城塞 · The Iron Citadel'), findsOneWidget);
    await tester.tap(find.text('钢铁城塞'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用').last);
    await tester.pumpAndSettle();
    expect(find.text('钢铁城塞'), findsOneWidget);
    controller.dispose();
  });
}
