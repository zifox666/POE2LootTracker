import 'package:flutter_test/flutter_test.dart';
import 'package:poe2_loot_tracker/widgets/common.dart';

void main() {
  test('amount unit switches to Divine at 0.3 of one', () {
    expect(formatAmount(0, 100), (value: '0', unit: 'E'));
    // Exactly 0.3 Divine counts as Divine, because `formatAmount` and the price editor's unit
    // toggle both go through `amountUsesDivine`. This is the boundary that used to disagree.
    expect(formatAmount(30, 100), (value: '0.3', unit: 'D'));
    expect(formatAmount(29, 100), (value: '29', unit: 'E'));
    expect(formatAmount(30.001, 100).unit, 'D');
    expect(formatAmount(-31, 100), (value: '-0.31', unit: 'D'));
    expect(formatAmount(500, 0), (value: '500', unit: 'E'));
  });

  test('the shared unit rule agrees with the unit formatAmount renders', () {
    expect(amountUsesDivine(30, 100), isTrue);
    expect(amountUsesDivine(29.99, 100), isFalse);
    // No rate means no conversion, so even a large amount stays in Exalted on both sides.
    expect(amountUsesDivine(500, 0), isFalse);

    for (final amount in <double>[0, 29.99, 30, 30.001, 250, -31]) {
      expect(
        amountUsesDivine(amount, 100),
        formatAmount(amount, 100).unit == 'D',
        reason: 'formatAmount and amountUsesDivine disagree at $amount',
      );
    }
  });

  test('RMB revenue uses the live Divine Orb quote', () {
    expect(formatRmbRevenue(520.4, 100, 0.1922), '¥1.00');
    expect(formatRmbRevenue(-260.2, 100, 0.1922), '-¥0.50');
    expect(formatRmbRevenue(100, 0, 0.1922), isNull);
    expect(formatRmbRevenue(100, 100, null), isNull);
  });

  test('duration uses compact tabular format', () {
    expect(formatDuration(const Duration(seconds: 65)), '01:05');
    expect(
      formatDuration(const Duration(hours: 2, minutes: 3, seconds: 4)),
      '2:03:04',
    );
  });
}
