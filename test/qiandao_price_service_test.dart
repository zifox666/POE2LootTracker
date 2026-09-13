import 'package:flutter_test/flutter_test.dart';
import 'package:poe2_loot_tracker/qiandao_price_service.dart';

void main() {
  test(
    'default needs its bundled key while a custom server key is optional',
    () {
      final service = QiandaoPriceService(
        baseUrl: 'https://default.example',
        token: '',
      );
      expect(service.configured(), isFalse);
      expect(
        service.configured(baseUrl: 'https://custom.example', token: ''),
        isTrue,
      );
      service.close();
    },
  );

  test('reads the Divine Orb RMB quote from the Qiandao envelope', () {
    expect(
      parseDivineRmbPrice('''
        {"code":"0","data":{"items":[
          {"spuName":"崇高石","rmbPrice":0.0017},
          {"spuName":"神圣石","rmbPrice":0.1922}
        ]}}
      '''),
      0.1922,
    );
  });

  test('rejects an envelope without a usable Divine Orb quote', () {
    expect(
      () => parseDivineRmbPrice(
        '{"code":"0","data":{"items":[{"spuName":"神圣石","rmbPrice":0}]}}',
      ),
      throwsFormatException,
    );
  });
}
