import 'package:flutter_test/flutter_test.dart';
import 'package:poe2_loot_tracker/widgets/common.dart';

void main() {
  test('amount unit uses strict per-value threshold', () {
    expect(formatAmount(0, 100), (value: '0', unit: 'E'));
    expect(formatAmount(30, 100), (value: '30', unit: 'E'));
    expect(formatAmount(30.001, 100).unit, 'D');
    expect(formatAmount(-31, 100), (value: '-0.31', unit: 'D'));
    expect(formatAmount(500, 0), (value: '500', unit: 'E'));
  });

  test('duration uses compact tabular format', () {
    expect(formatDuration(const Duration(seconds: 65)), '01:05');
    expect(
      formatDuration(const Duration(hours: 2, minutes: 3, seconds: 4)),
      '2:03:04',
    );
  });
}
