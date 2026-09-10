import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../app_theme.dart';
import '../dialogs.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../widgets/common.dart';

/// The stats tab: a summary strip on top, then the map log beside the loot/cost statistics.
///
/// The two lower panes are deliberately independent: clicking a row in the map log selects that run
/// (the loot panel then shows what that map produced), while the pickups/costs tabs keep working
/// against the session as a whole when nothing is selected.
class StatsTab extends StatefulWidget {
  const StatsTab({required this.controller, super.key});
  final AppController controller;
  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  /// The host keeps up to 100 runs per session, so the log is paged instead of rendered whole. The
  /// current page survives rebuilds (state pushes happen once a second) and is clamped whenever the
  /// data shrinks under it.
  static const int _pageSize = 8;

  int _page = 0;
  bool _showCosts = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final snapshot = widget.controller.snapshot;
    final selectedSession = widget.controller.selectedSessionId;
    final onActiveSession =
        selectedSession == null || selectedSession == snapshot.activeSessionId;
    final maps = onActiveSession
        ? snapshot.maps
        : widget.controller.historyMaps.map(MapSummary.fromJson).toList();

    final detail = widget.controller.mapDetail;
    final mapHeader = detail['map'] is Map
        ? (detail['map'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final hasMap = mapHeader.isNotEmpty;
    final loot = detail['loot'] is List
        ? listOfMaps(detail['loot']).map(LootEntry.fromJson).toList()
        : snapshot.loot;

    // With a run selected every figure describes that run; otherwise the session.
    // The `0.0` literals matter: `(x as num?)?.toDouble() ?? 0` would infer `num` and cannot be
    // passed where a double is expected.
    final profit = hasMap
        ? (mapHeader['profitEx'] as num?)?.toDouble() ?? 0.0
        : snapshot.totalProfitEx;
    final activeTime = hasMap
        ? Duration(milliseconds: (mapHeader['activeMs'] as num?)?.toInt() ?? 0)
        // Total time spent inside maps, not the session clock: the two labels sit next to each other
        // and a session clock labelled "in-map time" never stops, which reads as the overlay's timer
        // having frozen.
        : snapshot.activeTime;
    final perHour = hasMap
        ? (activeTime.inSeconds > 0
              ? profit / activeTime.inSeconds * 3600
              : 0.0)
        : snapshot.perHourEx;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: _summary(
            context,
            l,
            snapshot,
            maps: maps,
            profit: profit,
            perHour: perHour,
            activeTime: activeTime,
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _mapLog(context, l, maps)),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: _lootPanel(
                    context,
                    l,
                    loot: loot,
                    divineRate: snapshot.divineRate,
                    title: hasMap
                        ? (mapHeader['name']?.toString() ?? l.currentMap)
                        : l.lootStats,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(
    BuildContext context,
    AppLocalizations l,
    TrackerSnapshot snapshot, {
    required List<MapSummary> maps,
    required double profit,
    required double perHour,
    required Duration activeTime,
  }) {
    final rate = snapshot.divineRate;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        SizedBox(
          width: 230,
          child: _AmountMetric(
            label: l.sessionRevenue,
            amount: profit,
            rate: rate,
          ),
        ),
        SizedBox(
          width: 230,
          child: _AmountMetric(
            label: l.revenuePerHour,
            amount: perHour,
            rate: rate,
          ),
        ),
        SizedBox(
          width: 170,
          child: MetricCard(
            label: l.mapTime,
            value: formatDuration(activeTime),
          ),
        ),
        _stacked(context, [
          (l.sessionTime, formatDuration(snapshot.sessionTime)),
          (l.mapCount, '${snapshot.mapCount}'),
        ]),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              IconCount(
                icon: 'monster_normal',
                count: snapshot.kills[0],
                compact: true,
              ),
              IconCount(
                icon: 'monster_magic',
                count: snapshot.kills[1],
                compact: true,
              ),
              IconCount(
                icon: 'monster_rare',
                count: snapshot.kills[2],
                compact: true,
              ),
              IconCount(
                icon: 'monster_unique',
                count: snapshot.kills[3],
                compact: true,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 250,
          child: _Selector<String?>(
            label: l.selectSession,
            value: widget.controller.selectedSessionId,
            width: 250,
            items: [
              DropdownMenuItem(value: null, child: Text(l.currentSession)),
              ...widget.controller.sessions
                  .where((session) => session.id != snapshot.activeSessionId)
                  .map(
                    (session) => DropdownMenuItem(
                      value: session.id,
                      child: Text(_sessionLabel(session)),
                    ),
                  ),
            ],
            onChanged: widget.controller.selectSession,
          ),
        ),
      ],
    );
  }

  /// Two labelled figures stacked in one card, as the 总时长 / 地图次数 pair.
  Widget _stacked(BuildContext context, List<(String, String)> rows) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rows[i].$1,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.mutedForeground,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                rows[i].$2,
                style: context.numberStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Widget _mapLog(
    BuildContext context,
    AppLocalizations l,
    List<MapSummary> maps,
  ) {
    final pageCount = math.max(1, (maps.length + _pageSize - 1) ~/ _pageSize);
    final current = _page.clamp(0, pageCount - 1);
    final start = current * _pageSize;
    final rows = start >= maps.length
        ? const <MapSummary>[]
        : maps.sublist(start, math.min(start + _pageSize, maps.length));

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: SectionTitle(
              l.mapLog,
              trailing: Text(
                l.itemsCount(maps.length),
                style: TextStyle(color: context.colors.mutedForeground),
              ),
            ),
          ),
          Divider(height: 1, color: context.colors.border),
          _mapLogHeader(context, l),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      l.noMaps,
                      style: TextStyle(color: context.colors.mutedForeground),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    itemBuilder: (context, index) =>
                        _mapRow(context, rows[index]),
                  ),
          ),
          Divider(height: 1, color: context.colors.border),
          _pager(context, l, current, pageCount),
        ],
      ),
    );
  }

  /// Column widths are shared with [_mapRow] and every column is a flex, so a long map name can only
  /// ever ellipsize.
  Widget _mapLogHeader(BuildContext context, AppLocalizations l) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    child: DefaultTextStyle(
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.colors.mutedForeground,
      ),
      child: Row(
        children: [
          const Expanded(flex: 5, child: SizedBox()),
          Expanded(flex: 2, child: Text(l.cost)),
          Expanded(flex: 2, child: Text(l.profit)),
          SizedBox(
            width: 62,
            child: Text(l.duration, textAlign: TextAlign.right),
          ),
        ],
      ),
    ),
  );

  Widget _mapRow(BuildContext context, MapSummary map) {
    final selected = widget.controller.selectedMapId == map.id;
    final rate = widget.controller.snapshot.divineRate;
    return InkWell(
      onTap: () => widget.controller.selectMap(selected ? null : map.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? brandYellow.withValues(alpha: .10) : null,
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  if (map.active) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: tradingGreen,
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Expanded(
                    child: Text(
                      // The area level doubles as the map tier, the way the game shows it.
                      '${map.name} (Lv.${map.areaLevel})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: AmountView(
                map.costEx,
                rate,
                fontSize: 12,
                color: tradingRed,
              ),
            ),
            Expanded(
              flex: 2,
              child: AmountView(
                map.profitEx,
                rate,
                fontSize: 12,
                color: map.profitEx < 0 ? tradingRed : tradingGreen,
              ),
            ),
            SizedBox(
              width: 62,
              child: Text(
                formatDuration(map.activeTime),
                textAlign: TextAlign.right,
                style: context.numberStyle.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pager(
    BuildContext context,
    AppLocalizations l,
    int current,
    int pageCount,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Row(
      children: [
        TextButton(
          onPressed: current > 0
              ? () => setState(() => _page = current - 1)
              : null,
          child: Text(l.previous, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Text(
            l.pageOf(current + 1, pageCount),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.colors.mutedForeground,
            ),
          ),
        ),
        TextButton(
          onPressed: current < pageCount - 1
              ? () => setState(() => _page = current + 1)
              : null,
          child: Text(l.next, style: const TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );

  Widget _lootPanel(
    BuildContext context,
    AppLocalizations l, {
    required List<LootEntry> loot,
    required double divineRate,
    required String title,
  }) {
    final pickups = [
      for (final entry in loot)
        if (entry.count > 0) entry,
    ];
    final costs = [
      for (final entry in loot)
        if (entry.count < 0) entry,
    ];
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: SectionTitle(
              title,
              trailing: Text(
                l.itemsCount(loot.length),
                style: TextStyle(color: context.colors.mutedForeground),
              ),
            ),
          ),
          Divider(height: 1, color: context.colors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
            child: Column(
              children: [
                CostPresetSelector(
                  presets: widget.controller.costPresets,
                  selectedId: widget.controller.snapshot.inMap
                      ? widget.controller.snapshot.currentCostPresetId
                      : widget.controller.selectedCostPresetId,
                  onChanged: widget.controller.selectCostPreset,
                ),
                const SizedBox(height: 10),
                LootTabs(
                  pickups: pickups.length,
                  costs: costs.length,
                  showCosts: _showCosts,
                  onSelect: (value) => setState(() => _showCosts = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: LootList(
                rows: _showCosts ? costs : pickups,
                divineRate: divineRate,
                empty: _showCosts ? l.noCosts : l.waitingForPickups,
                // A drop poe.ninja has no price for is exactly when a manual price is wanted, and
                // this list is where those show up -- the button used to exist only in the market
                // table, which only lists items that already have a price.
                onPrice: (entry) => showManualPriceDialog(
                  context,
                  itemKey: entry.key,
                  name: entry.name,
                  divineRate: divineRate,
                  onApply: (value) =>
                      widget.controller.setManualPrice(entry.key, value),
                  onClear: () => widget.controller.clearManualPrice(entry.key),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sessionLabel(SessionRow value) {
    final date = value.startedUtc?.toLocal();
    final prefix = date == null
        ? value.id.substring(0, value.id.length.clamp(0, 8))
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$prefix · ${value.mapCount}';
  }
}

class _AmountMetric extends StatelessWidget {
  const _AmountMetric({
    required this.label,
    required this.amount,
    required this.rate,
  });
  final String label;
  final double amount;
  final double rate;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.mutedForeground),
        ),
        const SizedBox(height: 10),
        AmountView(
          amount,
          rate,
          fontSize: 22,
          color: amount < 0 ? tradingRed : tradingGreen,
        ),
      ],
    ),
  );
}

class _Selector<T> extends StatelessWidget {
  const _Selector({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.width,
  });
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.mutedForeground),
        ),
        const SizedBox(height: 7),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.colors.card,
            border: Border.all(color: context.colors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: context.colors.card,
              icon: const AppSvg('chevron_down', size: 16),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    ),
  );
}
