import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../item_icon_cache.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';

class AppSvg extends StatelessWidget {
  const AppSvg(this.name, {this.size = 18, this.color, super.key});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name.svg',
    width: size,
    height: size,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
  );
}

/// The application mark shown in the main window and compact overlay headers.
class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 24, super.key});
  final double size;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
    return Image.asset(
      'assets/icons/app_logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      cacheWidth: (size * ratio).round(),
    );
  }
}

/// Raster art shared with the tracker host's own ImGui overlay
/// (`tracker_host/Assets/icons/*.png`).
///
/// The currency and monster glyphs in this panel used to be the SVG line-art versions, which read
/// as generic outlines next to the game's actual orb/monster art the host draws over the game.
/// These are the very PNGs the host loads, so both windows now show the same artwork.
const Map<String, String> _rasterIcons = {
  'currency_divine': 'assets/icons/Divine.png',
  'currency_exalted': 'assets/icons/Exalt.png',
  'monster_normal': 'assets/icons/NormalMob.png',
  'monster_magic': 'assets/icons/MagicMob.png',
  'monster_rare': 'assets/icons/RareMob.png',
  'monster_unique': 'assets/icons/UniqueMob.png',
};

/// Icon by logical name: the shared raster art above where one exists, otherwise [AppSvg].
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {this.size = 18, super.key});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final asset = _rasterIcons[name];
    if (asset == null) return AppSvg(name, size: size);
    final ratio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
    return Image.asset(
      asset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      cacheWidth: (size * ratio).round(),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.card,
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, super.key});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      ?trailing,
    ],
  );
}

class CostPresetSelector extends StatelessWidget {
  const CostPresetSelector({
    required this.presets,
    required this.selectedId,
    required this.onChanged,
    this.compact = false,
    super.key,
  });

  final List<CostPreset> presets;
  final String selectedId;
  final ValueChanged<String?> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final value = presets.any((preset) => preset.id == selectedId)
        ? selectedId
        : '';
    return Row(
      children: [
        Text(
          l.activeCost,
          style: TextStyle(
            fontSize: compact ? 10 : 12,
            color: context.colors.mutedForeground,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: compact ? 32 : 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: context.colors.background,
              border: Border.all(color: context.colors.border),
              borderRadius: BorderRadius.circular(7),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: context.colors.card,
                icon: const AppSvg('chevron_down', size: 14),
                style: TextStyle(
                  color: context.colors.foreground,
                  fontSize: compact ? 11 : 13,
                ),
                items: [
                  DropdownMenuItem(value: '', child: Text(l.noCostPreset)),
                  ...presets.map(
                    (preset) => DropdownMenuItem(
                      value: preset.id,
                      child: Text(
                        '${preset.name} · ${formatNumber(preset.amount)} ${preset.currency}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    super.key,
  });
  final String label;
  final String value;
  final String? icon;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              AppSvg(icon!, size: 16),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: context.numberStyle.copyWith(
            fontSize: 23,
            fontWeight: FontWeight.w600,
            color: valueColor ?? context.colors.foreground,
          ),
        ),
      ],
    ),
  );
}

class AmountView extends StatelessWidget {
  const AmountView(
    this.exalted,
    this.divineRate, {
    this.fontSize = 16,
    this.color,
    super.key,
  });
  final double exalted;
  final double divineRate;
  final double fontSize;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final amount = formatAmount(exalted, divineRate);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(
          amount.unit == 'D' ? 'currency_divine' : 'currency_exalted',
          size: fontSize + 2,
        ),
        const SizedBox(width: 6),
        // Flexible, not Expanded: AmountView is also dropped into tight table cells, and a long
        // amount used to overflow the cell by a few pixels instead of ellipsizing.
        Flexible(
          child: Text(
            amount.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.numberStyle.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class IconCount extends StatelessWidget {
  const IconCount({
    required this.icon,
    required this.count,
    this.label,
    this.compact = false,
    super.key,
  });
  final String icon;
  final int count;
  final String? label;
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppIcon(icon, size: compact ? 16 : 20),
      SizedBox(width: compact ? 4 : 7),
      if (label != null) ...[
        Text(
          label!,
          style: TextStyle(fontSize: 12, color: context.colors.mutedForeground),
        ),
        const SizedBox(width: 6),
      ],
      Text(
        '$count',
        style: context.numberStyle.copyWith(
          fontSize: compact ? 13 : 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

/// The pickups / costs switch, shared by the overlay and the stats tab.
///
/// Both lists come from one host-side list whose entries carry a *signed* count: positive for what
/// was picked up, negative for what was spent. That is how the original WinForms build split its two
/// tabs, and it keeps the split exact without a second data source.
class LootTabs extends StatelessWidget {
  const LootTabs({
    required this.pickups,
    required this.costs,
    required this.showCosts,
    required this.onSelect,
    super.key,
  });
  final int pickups;
  final int costs;
  final bool showCosts;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        _tab(
          context,
          '${l.pickups} $pickups',
          !showCosts,
          () => onSelect(false),
        ),
        const SizedBox(width: 6),
        _tab(context, '${l.costs} $costs', showCosts, () => onSelect(true)),
      ],
    );
  }

  Widget _tab(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) => InkWell(
    borderRadius: BorderRadius.circular(6),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? context.colors.card : Colors.transparent,
        border: Border.all(
          color: selected ? brandYellow : context.colors.border,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: selected ? brandYellow : context.colors.mutedForeground,
        ),
      ),
    ),
  );
}

/// A scrollable list of [LootRow]s with an empty state.
class LootList extends StatelessWidget {
  const LootList({
    required this.rows,
    required this.divineRate,
    required this.empty,
    this.onPrice,
    super.key,
  });
  final List<LootEntry> rows;
  final double divineRate;
  final String empty;

  /// Opens the manual price dialog for a row. Left null where no controller is in reach.
  final void Function(LootEntry entry)? onPrice;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          empty,
          style: TextStyle(fontSize: 12, color: context.colors.mutedForeground),
        ),
      );
    }
    final price = onPrice;
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final entry = rows[index];
        return LootRow(
          entry: entry,
          divineRate: divineRate,
          onPrice: price == null ? null : () => price(entry),
        );
      },
    );
  }
}

class LootRow extends StatelessWidget {
  const LootRow({
    required this.entry,
    required this.divineRate,
    this.onPrice,
    super.key,
  });
  final LootEntry entry;
  final double divineRate;
  final VoidCallback? onPrice;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final unitAmount = formatAmount(entry.unitEx, divineRate);
    final totalAmount = formatAmount(entry.totalEx, divineRate);
    final signed = '${entry.count > 0 ? '+' : ''}${entry.count}';
    final price = onPrice;
    return InkWell(
      onTap: price,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.border)),
        ),
        child: Row(
          children: [
            NetworkItemIcon(entry.iconUrl, size: 22),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    entry.priced
                        ? '${l.unitPrice}: ${unitAmount.value} ${unitAmount.unit}'
                        : '${l.unitPrice}: —',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.numberStyle.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: entry.unitEx < 0 ? tradingRed : tradingGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '× $signed',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.mutedForeground,
                  ),
                ),
                Text(
                  entry.priced
                      ? '${totalAmount.value} ${totalAmount.unit}'
                      : '—',
                  style: context.numberStyle.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: entry.totalEx < 0 ? tradingRed : tradingGreen,
                  ),
                ),
              ],
            ),
            // The visible affordance for the case this list could not handle at all before: a drop
            // poe.ninja has no price for. Not a Tooltip: Material's Tooltip recycles its element
            // from a fresh GlobalKey per instance, and these rows are built and destroyed by a
            // ListView as it scrolls.
            if (!entry.priced && price != null) ...[
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: price,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(child: AppSvg('plus', size: 11)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NetworkItemIcon extends StatelessWidget {
  const NetworkItemIcon(this.url, {this.size = 32, super.key});
  final String url;
  final double size;

  /// Origin that actually serves the art.
  ///
  /// poe.ninja's economy API returns image paths relative to its own origin
  /// (`/gen/image/<b64>/<hash>/Name.png`), and that relative string is what the host persists in the
  /// price cache and in the SQLite price table. The art is *not* served from poe.ninja though --
  /// asking poe.ninja for it answers 404 with a full HTML error page -- it comes from GGG's CDN.
  /// Resolving against the wrong origin is what made every single market icon fall back to the
  /// placeholder.
  static const String artOrigin = 'https://web.poecdn.com';

  static final Set<String> _reported = <String>{};

  /// Absolute form of [url], or '' when there is nothing loadable.
  ///
  /// [artOrigin] doubles as the fix for a second bug: `NetworkImage` needs an absolute URL, and a
  /// relative one is resolved against `Uri.base`, which on desktop is the working directory as a
  /// `file://` URI, so the request was rejected outright.
  static String resolve(String url) {
    if (url.isEmpty) return '';
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    if (uri.hasScheme) return uri.toString();
    return Uri.parse(artOrigin).resolve(url).toString();
  }

  /// Keeps the first failures visible in the console: [errorBuilder] alone swallowed the reason,
  /// which is what made "every icon is a placeholder" invisible for so long.
  static void _reportFailure(String url, Object error) {
    if (_reported.length >= 20 || !_reported.add(url)) return;
    debugPrint('item icon failed: $url -> $error');
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolve(url);
    if (resolved.isEmpty) {
      return SizedBox.square(
        dimension: size,
        child: const AppSvg('placeholder'),
      );
    }
    final ratio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
    final uri = Uri.parse(resolved);
    final cached = ItemIconCache.cacheFileFor(uri);
    if (cached.existsSync()) return _fileIcon(cached, ratio);
    return SizedBox.square(
      dimension: size,
      child: FutureBuilder<File?>(
        future: ItemIconCache.load(uri),
        builder: (context, snapshot) {
          final image = snapshot.data;
          if (image != null) return _fileIcon(image, ratio);
          if (snapshot.hasError) _reportFailure(resolved, snapshot.error!);
          return const AppSvg('placeholder');
        },
      ),
    );
  }

  Widget _fileIcon(File image, double ratio) => Image.file(
    image,
    fit: BoxFit.contain,
    // Decode at the size actually painted rather than at source resolution.
    cacheWidth: (size * ratio).round(),
    errorBuilder: (context, error, stackTrace) {
      _reportFailure(image.path, error);
      return const AppSvg('placeholder');
    },
  );
}

/// The one rule for choosing between the Divine and Exalted unit: an amount is shown in Divine once
/// it is worth *at least* 0.3 of one, and in Exalted below that.
///
/// This is deliberately a single function rather than a condition repeated at each call site,
/// because two callers have to agree on the answer and previously did not. [formatAmount] picks the
/// unit it renders, and the price editor in `dialogs.dart` seeds its D/E toggle from the same
/// answer; when the two drifted apart, opening a price could show a different unit than the list it
/// was opened from.
///
/// A zero or unknown rate always means Exalted: with no rate there is nothing to convert by, and
/// every caller shows the raw Exalted number.
bool amountUsesDivine(double exalted, double divineRate) =>
    divineRate > 0 && (exalted / divineRate).abs() >= 0.3;

/// Formats an Exalted amount, switching to Divine once it is worth at least 0.3 of one.
///
/// Two decimals, with trailing zeros dropped. The unit is chosen from the rate the prices were
/// converted with, so 1 Divine always renders as "1 D". [amountUsesDivine] owns that choice.
({String value, String unit}) formatAmount(double exalted, double divineRate) {
  final useDivine = amountUsesDivine(exalted, divineRate);
  final value = useDivine ? exalted / divineRate : exalted;
  String text = value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  if (text == '-0') text = '0';
  return (value: text, unit: useDivine ? 'D' : 'E');
}

String formatNumber(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

String formatDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
