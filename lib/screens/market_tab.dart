import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../app_controller.dart';
import '../app_theme.dart';
import '../dialogs.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../widgets/common.dart';

/// poe.ninja's economy sections in the order its own pages list them. The host tags every price
/// with the section it was fetched under, so the table can be grouped the way
/// `https://poe.ninja/poe2/economy/<league>/currency` is; sections the host reports that are missing
/// here keep their English label and sort to the end instead of disappearing.
const List<String> _categoryOrder = [
  'Currency',
  'Fragments',
  'Abyssal Bones',
  'Uncut Gems',
  'Lineage Support Gems',
  'Essences',
  'Soul Cores',
  'Idols',
  'Runes',
  'Omens',
  'Expedition',
  'Liquid Emotions',
  'Breach Catalysts',
  'Verisium',
  'Unique Weapons',
  'Unique Armours',
  'Unique Accessories',
  'Unique Flasks',
  'Unique Charms',
  'Unique Jewels',
  'Unique Sanctum Relics',
  'Unique Tablets',
  'Precursor Tablets',
];

/// Shown for rows whose category is empty -- a price cache written before the host recorded
/// sections, which resolves itself on the first price refresh.
const String _uncategorised = 'Other';

const Map<String, String> _categoryLabelsZh = {
  'Currency': '通货',
  'Fragments': '碎片',
  'Abyssal Bones': '深渊骸骨',
  'Uncut Gems': '未切割宝石',
  'Lineage Support Gems': '血脉辅助宝石',
  'Essences': '精华',
  'Soul Cores': '灵核',
  'Idols': '神像',
  'Runes': '符文',
  'Omens': '预兆',
  'Expedition': '远征',
  'Liquid Emotions': '液态情感',
  'Breach Catalysts': '裂隙催化剂',
  'Verisium': '维里西姆',
  'Unique Weapons': '传奇武器',
  'Unique Armours': '传奇护甲',
  'Unique Accessories': '传奇饰品',
  'Unique Flasks': '传奇药剂',
  'Unique Charms': '传奇护符',
  'Unique Jewels': '传奇珠宝',
  'Unique Sanctum Relics': '传奇圣所遗物',
  'Unique Tablets': '传奇石板',
  'Precursor Tablets': '先驱石板',
  'Other': '其他',
};

/// One row of the flattened table: either a section heading or a price.
class _TableEntry {
  _TableEntry.section(this.label, this.count) : price = null, last = false;
  _TableEntry.price(this.price, {required this.last}) : label = null, count = 0;

  final String? label;
  final int count;
  final MarketPrice? price;
  final bool last;
}

class MarketTab extends StatefulWidget {
  const MarketTab({required this.controller, super.key});
  final AppController controller;
  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab> {
  late final TextEditingController search = TextEditingController(
    text: widget.controller.marketQuery,
  );

  /// The section label selected in the left-hand filter, or null for "all categories".
  String? category;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final snapshot = widget.controller.snapshot;
    final prices = widget.controller.marketPrices;
    final categories = _categoryCounts(context, prices);
    // A language switch relabels every section, so a selection that no longer exists falls back to
    // "all" rather than filtering the whole table away.
    final selected = categories.any((entry) => entry.label == category)
        ? category
        : null;
    final visible = selected == null
        ? prices
        : [
            for (final price in prices)
              if (_label(context, price.category) == selected) price,
          ];
    // While a single category is selected the section headings would only repeat the filter.
    final entries = _tableEntries(context, visible, grouped: selected == null);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: _metrics(context, l, snapshot),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: 28),
              SizedBox(
                width: 208,
                child: _categoryPanel(
                  context,
                  l,
                  categories,
                  prices.length,
                  selected,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(child: _priceTable(context, l, visible, entries)),
              const SizedBox(width: 28),
            ],
          ),
        ),
      ],
    );
  }

  /// The left-hand filter: one entry per poe.ninja section plus "all", each with its row count.
  Widget _categoryPanel(
    BuildContext context,
    AppLocalizations l,
    List<({String label, int count})> categories,
    int total,
    String? selected,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.card,
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _categoryEntry(
          context,
          l.allCategories,
          total,
          selected == null,
          () => setState(() => category = null),
        ),
        for (final entry in categories)
          _categoryEntry(
            context,
            entry.label,
            entry.count,
            selected == entry.label,
            () => setState(() => category = entry.label),
          ),
      ],
    ),
  );

  Widget _categoryEntry(
    BuildContext context,
    String label,
    int count,
    bool selected,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? brandYellow.withValues(alpha: .12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? context.colors.foreground
                      : context.colors.mutedForeground,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                color: context.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// The price table itself. It is built lazily: index 0 is the search/heading block, so only rows
  /// scrolled into view are ever constructed.
  Widget _priceTable(
    BuildContext context,
    AppLocalizations l,
    List<MarketPrice> visible,
    List<_TableEntry> entries,
  ) => ListView.builder(
    padding: const EdgeInsets.only(bottom: 32),
    itemCount: visible.isEmpty ? 2 : entries.length + 1,
    itemBuilder: (context, index) {
      if (index == 0) return _tableHead(context, l);
      if (visible.isEmpty) return _emptyTable(context, l);
      final entry = entries[index - 1];
      final label = entry.label;
      if (label != null) return _sectionHeader(context, label, entry.count);
      return _priceRow(context, entry.price!, last: entry.last);
    },
  );

  /// Flattens the price list into section headings plus rows, in [_categoryOrder] and, inside a
  /// section, in the price-descending order the host already sorted by.
  List<_TableEntry> _tableEntries(
    BuildContext context,
    List<MarketPrice> prices, {
    required bool grouped,
  }) {
    if (!grouped) {
      return [
        for (var i = 0; i < prices.length; i++)
          _TableEntry.price(prices[i], last: i == prices.length - 1),
      ];
    }

    final sections = <String, List<MarketPrice>>{};
    for (final price in prices) {
      sections
          .putIfAbsent(_label(context, price.category), () => <MarketPrice>[])
          .add(price);
    }

    final labels = sections.keys.toList()..sort(_compareCategories);
    final entries = <_TableEntry>[];
    for (final section in labels) {
      final rows = sections[section]!;
      entries.add(_TableEntry.section(section, rows.length));
      for (var i = 0; i < rows.length; i++) {
        entries.add(_TableEntry.price(rows[i], last: i == rows.length - 1));
      }
    }
    return entries;
  }

  int _compareCategories(String a, String b) {
    final ia = _categoryOrder.indexOf(a);
    final ib = _categoryOrder.indexOf(b);
    return (ia < 0 ? _categoryOrder.length : ia).compareTo(
      ib < 0 ? _categoryOrder.length : ib,
    );
  }

  String _label(BuildContext context, String category) {
    final key = category.isEmpty ? _uncategorised : category;
    if (Localizations.localeOf(context).languageCode != 'zh') return key;
    return _categoryLabelsZh[key] ?? key;
  }

  List<({String label, int count})> _categoryCounts(
    BuildContext context,
    List<MarketPrice> prices,
  ) {
    final counts = <String, int>{};
    for (final price in prices) {
      final label = _label(context, price.category);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final labels = counts.keys.toList()..sort(_compareCategories);
    return [for (final label in labels) (label: label, count: counts[label]!)];
  }

  Widget _metrics(
    BuildContext context,
    AppLocalizations l,
    TrackerSnapshot snapshot,
  ) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      SizedBox(
        width: 240,
        child: MetricCard(
          label: l.league,
          value: widget.controller.settings['league']?.toString() ?? 'Standard',
        ),
      ),
      SizedBox(
        width: 210,
        child: MetricCard(
          label: l.syncStatus,
          value: _syncLabel(l, snapshot.priceStatus),
          valueColor: snapshot.priceStatus == 'error'
              ? tradingRed
              : tradingGreen,
        ),
      ),
      SizedBox(width: 210, child: _RateMetric(rate: snapshot.divineRate)),
      SizedBox(
        width: 240,
        child: MetricCard(
          label: l.lastUpdated,
          value: _updated(snapshot.priceUpdatedUtc),
        ),
      ),
    ],
  );

  Widget _tableHead(BuildContext context, AppLocalizations l) => _tableFrame(
    context,
    borderTop: true,
    borderBottom: true,
    first: true,
    last: true,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.background,
                    border: Border.all(color: context.colors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: search,
                    onSubmitted: widget.controller.refreshMarket,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: l.searchPrices,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(10),
                        child: AppSvg('search'),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FButton(
                onPress: widget.controller.requestPriceRefresh,
                mainAxisSize: MainAxisSize.min,
                prefix: const AppSvg('refresh', color: Color(0xFF181A20)),
                child: Text(l.refresh),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.colors.border),
        _columnHeadings(context),
      ],
    ),
  );

  /// Column widths are shared between the headings and the rows, and every column is a flex: the
  /// action column used to be a fixed 100 px box, which a localized button label could outgrow
  /// (that is the "RenderFlex overflowed by 12 pixels" this table threw).
  Widget _columnHeadings(BuildContext context) {
    final l = AppLocalizations.of(context);
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: context.colors.mutedForeground,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: DefaultTextStyle(
        style: style,
        child: Row(
          children: [
            Expanded(flex: 5, child: Text(l.item)),
            Expanded(flex: 2, child: Text(l.unitPrice)),
            Expanded(flex: 2, child: Text(l.manualPrice)),
            const Expanded(flex: 2, child: SizedBox()),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label, int count) =>
      Padding(
        // Separates one section's card from the previous one.
        padding: const EdgeInsets.only(top: 14),
        child: _tableFrame(
          context,
          borderTop: true,
          borderBottom: false,
          first: true,
          color: context.colors.background,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  /// Draws the card frame one segment at a time. Drawing a border and rounding a corner are
  /// deliberately separate: a middle row draws a top border but is not the card's top edge, so it
  /// must stay square. A section heading is `first`, the last row of a section is `last`.
  Widget _tableFrame(
    BuildContext context, {
    required Widget child,
    bool borderTop = true,
    bool borderBottom = false,
    bool first = false,
    bool last = false,
    Color? color,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) => Container(
    decoration: BoxDecoration(
      color: color ?? context.colors.card,
      border: Border(
        top: borderTop
            ? BorderSide(color: context.colors.border)
            : BorderSide.none,
        left: BorderSide(color: context.colors.border),
        right: BorderSide(color: context.colors.border),
        bottom: borderBottom
            ? BorderSide(color: context.colors.border)
            : BorderSide.none,
      ),
      borderRadius: BorderRadius.vertical(
        top: first ? const Radius.circular(10) : Radius.zero,
        bottom: last ? const Radius.circular(10) : Radius.zero,
      ),
    ),
    child: Padding(padding: padding, child: child),
  );

  Widget _emptyTable(BuildContext context, AppLocalizations l) => _tableFrame(
    context,
    borderTop: true,
    borderBottom: true,
    first: true,
    last: true,
    padding: const EdgeInsets.all(42),
    child: Text(
      l.noPrices,
      style: TextStyle(color: context.colors.mutedForeground),
    ),
  );

  Widget _priceRow(
    BuildContext context,
    MarketPrice price, {
    required bool last,
  }) => _tableFrame(
    context,
    borderTop: true,
    borderBottom: last,
    last: last,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
    child: Row(
      children: [
        Expanded(
          flex: 5,
          child: Row(
            children: [
              NetworkItemIcon(price.iconUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Text(price.name, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: AmountView(
            price.priceEx,
            widget.controller.snapshot.divineRate,
            fontSize: 13,
          ),
        ),
        Expanded(
          flex: 2,
          child: price.manualPriceEx == null
              ? Text(
                  '—',
                  style: TextStyle(color: context.colors.mutedForeground),
                )
              : AmountView(price.manualPriceEx!, 0, fontSize: 13),
        ),
        Expanded(
          flex: 2,
          child: _manualPriceButton(
            context,
            () => showManualPriceDialog(
              context,
              itemKey: price.key,
              name: price.name,
              divineRate: widget.controller.snapshot.divineRate,
              currentEx: price.manualPriceEx,
              onApply: (value) =>
                  widget.controller.setManualPrice(price.key, value),
              onClear: () => widget.controller.clearManualPrice(price.key),
            ),
          ),
        ),
      ],
    ),
  );

  /// A hand-rolled outline button rather than a Forui [FButton]: this table renders hundreds of
  /// them, and FButton's own layout does not shrink inside a constrained cell. Filling the flex
  /// column also means the label can ellipsize instead of overflowing.
  Widget _manualPriceButton(BuildContext context, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(6),
    onTap: onTap,
    child: Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          AppLocalizations.of(context).manualPrice,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    ),
  );

  String _updated(DateTime? value) {
    if (value == null || value.year < 2000) return '—';
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _syncLabel(AppLocalizations l, String status) => switch (status) {
    'ready' => l.syncReady,
    'syncing' => l.syncing,
    'error' => l.syncError,
    _ => l.syncIdle,
  };
}

class _RateMetric extends StatelessWidget {
  const _RateMetric({required this.rate});
  final double rate;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).divineRate,
          style: TextStyle(fontSize: 12, color: context.colors.mutedForeground),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const AppIcon('currency_divine', size: 22),
            const SizedBox(width: 6),
            Text(
              '1',
              style: context.numberStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const AppIcon('currency_exalted', size: 22),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                rate > 0 ? rate.toStringAsFixed(2) : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.numberStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
