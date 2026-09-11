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

    // The header is a session dashboard. Selecting a row is deliberately only a lower-panel detail
    // action, so comparing a map's drops never makes the total revenue and time cards jump around.
    final profit = snapshot.totalProfitEx;
    final activeTime = snapshot.activeTime;
    final perHour = snapshot.perHourEx;

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
    // The dashboard keeps the four figures used while farming together, instead of pushing the
    // time and kill statistics onto a second wrapped row.
    final trend = _cumulativeProfit(maps);
    final cards = [
      _AmountMetric(
        label: l.totalRevenue,
        amount: profit,
        rate: rate,
        trend: trend,
        color: profit < 0 ? tradingRed : const Color(0xFFFF7A45),
      ),
      _AmountMetric(
        label: l.revenuePerHour,
        amount: perHour,
        rate: rate,
        trend: maps.map((map) => _perMinute(map)).toList(growable: false),
        color: perHour < 0 ? tradingRed : tradingGreen,
      ),
      _KillMetric(kills: snapshot.kills),
      _DurationMetric(
        mapTime: activeTime,
        sessionTime: snapshot.sessionTime,
        mapCount: snapshot.mapCount,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 880) {
          // A narrow window cannot hold four full-size cards without stealing the map log's usable
          // height. Keep the compact dashboard one line high and let the row scroll horizontally.
          return SizedBox(
            height: 168,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    if (index > 0) const SizedBox(width: 12),
                    SizedBox(width: 280, child: cards[index]),
                  ],
                ],
              ),
            ),
          );
        }
        return Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              Expanded(child: cards[index]),
            ],
          ],
        );
      },
    );
  }

  List<double> _cumulativeProfit(List<MapSummary> maps) {
    var total = 0.0;
    return [for (final map in maps.reversed) total += map.profitEx];
  }

  double _perMinute(MapSummary map) => map.activeTime.inSeconds == 0
      ? 0
      : map.profitEx / map.activeTime.inSeconds * 60;

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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.itemsCount(maps.length),
                    style: TextStyle(color: context.colors.mutedForeground),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: l.selectSession,
                    icon: const AppSvg('chevron_down', size: 16),
                    onSelected: (value) => widget.controller.selectSession(
                      value.isEmpty ? null : value,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(value: '', child: Text(l.currentSession)),
                      ...widget.controller.sessions
                          .where(
                            (session) =>
                                session.id !=
                                widget.controller.snapshot.activeSessionId,
                          )
                          .map(
                            (session) => PopupMenuItem(
                              value: session.id,
                              child: Text(_sessionLabel(session)),
                            ),
                          ),
                    ],
                  ),
                ],
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
          const Expanded(flex: 4, child: SizedBox()),
          Expanded(flex: 2, child: Text(l.pickups)),
          Expanded(flex: 2, child: Text(l.cost)),
          Expanded(flex: 2, child: Text(l.profit)),
          Expanded(flex: 2, child: Text(l.totalKills)),
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
    final pickup = map.profitEx + map.costEx;
    final totalKills = map.kills.fold<int>(0, (total, kills) => total + kills);
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
              flex: 4,
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
                pickup,
                rate,
                fontSize: 12,
                color: pickup < 0 ? tradingRed : null,
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
            Expanded(
              flex: 2,
              child: Text(
                '$totalKills',
                style: context.numberStyle.copyWith(
                  fontSize: 12,
                  color: context.colors.mutedForeground,
                ),
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
    required this.trend,
    required this.color,
  });
  final String label;
  final double amount;
  final double rate;
  final List<double> trend;
  final Color color;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
    child: SizedBox(
      height: 136,
      child: Stack(
        children: [
          Positioned.fill(
            top: 77,
            child: IgnorePointer(
              child: _TrendLine(values: trend, color: color),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              AmountView(amount, rate, fontSize: 27, color: color),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DurationMetric extends StatelessWidget {
  const _DurationMetric({
    required this.mapTime,
    required this.sessionTime,
    required this.mapCount,
  });

  final Duration mapTime;
  final Duration sessionTime;
  final int mapCount;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = [
      (l.mapTime, formatDuration(mapTime)),
      (l.sessionTime, formatDuration(sessionTime)),
      (l.mapCount, '$mapCount'),
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: SizedBox(
        height: 140,
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) Divider(height: 1, color: context.colors.border),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      rows[index].$1,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      rows[index].$2,
                      style: context.numberStyle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: brandYellow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KillMetric extends StatelessWidget {
  const _KillMetric({required this.kills});

  final List<int> kills;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final total = kills.fold<int>(0, (sum, count) => sum + count);
    const icons = [
      'monster_normal',
      'monster_magic',
      'monster_rare',
      'monster_unique',
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: SizedBox(
        height: 136,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.monsterKills,
              style: TextStyle(
                fontSize: 14,
                color: context.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '$total',
              style: context.numberStyle.copyWith(
                fontSize: 27,
                fontWeight: FontWeight.w600,
                color: brandYellow,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 58,
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _KillCount(
                            icon: icons[0],
                            count: kills.isNotEmpty ? kills[0] : 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _KillCount(
                            icon: icons[1],
                            count: kills.length > 1 ? kills[1] : 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _KillCount(
                            icon: icons[2],
                            count: kills.length > 2 ? kills[2] : 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _KillCount(
                            icon: icons[3],
                            count: kills.length > 3 ? kills[3] : 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KillCount extends StatelessWidget {
  const _KillCount({required this.icon, required this.count});

  final String icon;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      AppIcon(icon, size: 20),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          '$count',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.numberStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TrendLinePainter(
      values: values,
      color: color.withValues(alpha: .38),
    ),
  );
}

class _TrendLinePainter extends CustomPainter {
  const _TrendLinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final span = maximum - minimum;
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final normalized = span == 0 ? .5 : (values[index] - minimum) / span;
      final y = size.height - normalized * size.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
