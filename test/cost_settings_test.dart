import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:poe2_loot_tracker/app_theme.dart';
import 'package:poe2_loot_tracker/data/endgame_maps.dart';
import 'package:poe2_loot_tracker/l10n/app_localizations.dart';
import 'package:poe2_loot_tracker/models.dart';
import 'package:poe2_loot_tracker/widgets/common.dart';

void main() {
  test('POE2DB map options join three languages by unique key', () {
    expect(endgameMaps.length, 159);
    expect(
      endgameMaps.map((map) => map.key).toSet().length,
      endgameMaps.length,
    );
    final iron = mapOptionsForAliases(const ['The Iron Citadel']).single;
    expect(iron.zhCn, '钢铁城塞');
    expect(iron.zhTw, '鋼鐵城塞');
    expect(
      aliasesForMapKeys([iron.key]),
      containsAll(<String>['钢铁城塞', '鋼鐵城塞', 'The Iron Citadel']),
    );
    expect(
      endgameMaps
          .expand((map) => map.aliases)
          .where((name) => name.contains('DNT-UNUSED')),
      isEmpty,
    );
  });

  test('legacy single map settings migrate in the Flutter model', () {
    final preset = CostPreset.fromJson({
      'id': 'old',
      'name': '旧成本',
      'amount': 2,
      'currency': 'D',
      'mapName': '钢铁城塞',
      'isDefault': true,
    });
    expect(preset.mapNames, ['钢铁城塞']);
    expect(preset.isDefault, isTrue);
  });

  testWidgets('cost selector exposes none and all named presets', (
    tester,
  ) async {
    String? selected;
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
          body: CostPresetSelector(
            presets: const [
              CostPreset(
                id: 'scarabs',
                name: '甲虫组合',
                amount: 1.5,
                currency: 'D',
                mapNames: ['钢铁城塞', '鋼鐵城塞', 'The Iron Citadel'],
                isDefault: true,
              ),
            ],
            selectedId: '',
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('不扣成本'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('甲虫组合 · 1.5 D').last);
    await tester.pumpAndSettle();
    expect(selected, 'scarabs');
  });
}
