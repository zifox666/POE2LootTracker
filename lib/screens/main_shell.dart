import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../app_controller.dart';
import '../app_theme.dart';
import '../app_version.dart';
import '../dialogs.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common.dart';
import 'market_tab.dart';
import 'cost_settings_tab.dart';
import 'settings_tab.dart';
import 'stats_tab.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    required this.controller,
    required this.onShowOverlay,
    required this.onShowRecentLoot,
    required this.onNewSession,
    required this.onCloseWindow,
    super.key,
  });
  final AppController controller;
  final VoidCallback onShowOverlay;
  final VoidCallback onShowRecentLoot;

  /// Both of these go through the shell rather than straight to the controller, because each one
  /// asks for confirmation first (and that dialog needs a build context).
  final VoidCallback onNewSession;
  final VoidCallback onCloseWindow;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pages = [
      StatsTab(controller: widget.controller),
      MarketTab(controller: widget.controller),
      CostSettingsTab(controller: widget.controller),
      SettingsTab(
        controller: widget.controller,
        onShowOverlay: widget.onShowOverlay,
        onShowRecentLoot: widget.onShowRecentLoot,
        onNewSession: widget.onNewSession,
      ),
    ];
    final entries = [
      ('loot', l.lootStats),
      ('market', l.marketPrices),
      ('currency_exalted', l.costSettings),
      ('settings', l.settings),
    ];
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          _TitleBar(
            controller: widget.controller,
            onShowOverlay: widget.onShowOverlay,
            onShowRecentLoot: widget.onShowRecentLoot,
            onNewSession: widget.onNewSession,
            onCloseWindow: widget.onCloseWindow,
          ),
          _ErrorBanner(controller: widget.controller),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 222,
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    border: Border(
                      right: BorderSide(color: context.colors.border),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 18),
                      for (var i = 0; i < entries.length; i++)
                        _NavEntry(
                          icon: entries[i].$1,
                          label: entries[i].$2,
                          selected: index == i,
                          onTap: () => setState(() => index = i),
                        ),
                      const Spacer(),
                      _ConnectionStatus(controller: widget.controller),
                      _MiniWindowAction(
                        label: l.showOverlay,
                        onTap: widget.onShowOverlay,
                      ),
                      _MiniWindowAction(
                        label: l.previewPickupNotifications,
                        icon: 'loot',
                        onTap: widget.onShowRecentLoot,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(index: index, children: pages),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.controller,
    required this.onShowOverlay,
    required this.onShowRecentLoot,
    required this.onNewSession,
    required this.onCloseWindow,
  });
  final AppController controller;
  final VoidCallback onShowOverlay;
  final VoidCallback onShowRecentLoot;
  final VoidCallback onNewSession;
  final VoidCallback onCloseWindow;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final paused = controller.snapshot.trackingPaused;
    return SizedBox(
      height: 62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.card,
          border: Border(bottom: BorderSide(color: context.colors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      const AppLogo(size: 24),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.appTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Text(
                                'v$appVersionFull',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.colors.mutedForeground,
                                ),
                              ),
                              if (controller.updatePhase ==
                                      UpdatePhase.available &&
                                  controller.availableUpdate != null) ...[
                                const SizedBox(width: 6),
                                _UpdateBadge(
                                  onTap: () => _openUpdate(context),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _HeaderStatus(
              label: l.season,
              value: controller.leagueName,
            ),
            _HeaderStatus(
              label: l.onlinePlayers,
              value: _formatPlayerCount(controller.onlinePlayers),
              accent: tradingGreen,
            ),
            const SizedBox(width: 10),
            // Session controls. The host has always had pause/resume and start-new-session; they
            // were only reachable from the tray menu, which left no way to exercise them (and
            // nothing to see the "resumes by itself when you enter a map" behaviour from).
            //
            // No Tooltips here on purpose: Material's Tooltip builds a fresh
            // GlobalKey<RawTooltipState> per widget instance, so in a tree that rebuilds on every
            // state push it recycles its element (and its overlay entry) once a second, which shows
            // up as a stream of detached-render-object assertions.
            _TitleAction(
              icon: paused ? 'play' : 'pause',
              color: paused ? brandYellow : null,
              onTap: controller.pauseOrResume,
            ),
            _TitleAction(icon: 'plus', onTap: onNewSession),
            _TitleAction(icon: 'overlay', onTap: onShowOverlay),
            _TitleAction(icon: 'loot', onTap: onShowRecentLoot),
            _TitleAction(icon: 'minimize', onTap: windowManager.minimize),
            _TitleAction(icon: 'close', onTap: onCloseWindow),
          ],
        ),
      ),
    );
  }

  Future<void> _openUpdate(BuildContext context) async {
    final release = controller.availableUpdate;
    if (release == null || controller.updatePhase != UpdatePhase.available) {
      return;
    }
    final install = await confirmUpdateAvailable(
      context,
      version: release.version,
    );
    if (install && context.mounted) {
      await showUpdateProgress(context, controller: controller);
    }
  }
}

class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: brandYellow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          color: Color(0xFF181A20),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: .3,
        ),
      ),
    ),
  );
}

class _HeaderStatus extends StatelessWidget {
  const _HeaderStatus({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 150),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      border: Border(left: BorderSide(color: context.colors.border)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: context.colors.mutedForeground),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.numberStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: accent,
          ),
        ),
      ],
    ),
  );
}

String _formatPlayerCount(int? value) {
  if (value == null) return '—';
  return value
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

class _TitleAction extends StatelessWidget {
  const _TitleAction({required this.icon, required this.onTap, this.color});
  final String icon;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      width: 48,
      height: 54,
      child: Center(child: AppSvg(icon, size: 18, color: color)),
    ),
  );
}

class _NavEntry extends StatelessWidget {
  const _NavEntry({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected
              ? brandYellow.withValues(alpha: .12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            AppSvg(
              icon,
              size: 19,
              color: selected ? brandYellow : context.colors.mutedForeground,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? context.colors.foreground
                    : context.colors.mutedForeground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Surfaces [AppController.error].
///
/// Nothing rendered that field before, so a failed overlay window or a dead tracker host looked
/// exactly like a button that was never wired up -- which is what made "clicking does nothing" so
/// hard to tell apart from a real failure.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final message = controller.error ?? '';
    if (message.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 9, 10, 9),
      color: tradingRed.withValues(alpha: .16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${l.syncError} · $message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          InkWell(
            onTap: () => controller.setError(null),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                l.clear,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.mutedForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniWindowAction extends StatelessWidget {
  const _MiniWindowAction({
    required this.label,
    required this.onTap,
    this.icon = 'overlay',
  });
  final String label;
  final VoidCallback onTap;
  final String icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: context.colors.background,
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            AppSvg(icon, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final connected = controller.snapshot.gameConnected;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: connected ? tradingGreen : context.colors.mutedForeground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              connected ? l.connected : l.waitingForGame,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
