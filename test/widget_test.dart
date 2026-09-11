import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:poe2_loot_tracker/app_controller.dart';
import 'package:poe2_loot_tracker/app_theme.dart';
import 'package:poe2_loot_tracker/app_version.dart';
import 'package:poe2_loot_tracker/dialogs.dart';
import 'package:poe2_loot_tracker/l10n/app_localizations.dart';
import 'package:poe2_loot_tracker/screens/main_shell.dart';
import 'package:poe2_loot_tracker/screens/settings_tab.dart';
import 'package:poe2_loot_tracker/update_service.dart';

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
          onShowRecentLoot: () {},
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

  testWidgets('settings show the current version and update control', (
    tester,
  ) async {
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
        home: Scaffold(
          body: SettingsTab(
            controller: controller,
            onShowOverlay: () {},
            onShowRecentLoot: () {},
            onNewSession: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('拾取通知'), findsOneWidget);
    expect(find.text('最多显示条数'), findsOneWidget);
    expect(find.text('显示时长'), findsOneWidget);
    expect(find.text('预览拾取通知'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.text('软件更新'), findsOneWidget);
    expect(find.text('CDN（推荐）'), findsOneWidget);
    expect(find.text('当前版本 $appVersionFull'), findsOneWidget);
    expect(find.text('检查更新'), findsWidgets);
    controller.dispose();
  });

  testWidgets('offers an automatically discovered update on the main UI', (
    tester,
  ) async {
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
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmUpdateAvailable(context, version: '1.2.0'),
            child: const Text('show'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('新版本 1.2.0 已可用。现在下载并安装吗？应用会自动关闭并重新启动。'), findsOneWidget);
    expect(find.text('稍后'), findsOneWidget);
    expect(find.text('下载并安装'), findsOneWidget);
  });

  testWidgets('shows download progress after accepting the startup update', (
    tester,
  ) async {
    final updateService = _ProgressUpdateService();
    final controller =
        AppController(startHost: false, updateService: updateService)
          ..availableUpdate = _testRelease
          ..updatePhase = UpdatePhase.available;
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
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showUpdateProgress(context, controller: controller),
            child: const Text('show progress'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show progress'));
    await tester.pump();
    await updateService.started.future;
    await tester.pump();

    expect(find.text('正在下载更新… 50%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
    );

    updateService.finish.complete();
    await tester.pumpAndSettle();
    expect(find.text('更新失败：test failure'), findsOneWidget);
    controller.dispose();
  });
}

final _testRelease = UpdateRelease(
  version: '1.2.0',
  tag: 'v1.2.0',
  archiveUrl: Uri.parse('https://example.test/release.zip'),
  checksumUrl: Uri.parse('https://example.test/release.zip.sha256'),
  releasePage: Uri.parse('https://example.test/release'),
  notes: '',
);

class _ProgressUpdateService extends UpdateService {
  final started = Completer<void>();
  final finish = Completer<void>();

  @override
  Future<void> downloadAndLaunch(
    UpdateRelease release, {
    String source = 'cdn',
    String customCdn = '',
    void Function(int received, int total)? onProgress,
  }) async {
    onProgress?.call(50, 100);
    started.complete();
    await finish.future;
    throw const UpdateException('test failure');
  }
}
