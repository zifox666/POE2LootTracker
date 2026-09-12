import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../app_controller.dart';
import '../app_theme.dart';
import '../app_version.dart';
import '../l10n/app_localizations.dart';
import '../overlay_window.dart' show overlayWindowStyle;
import '../update_service.dart';
import '../widgets/common.dart';

enum _SettingsCategory {
  general,
  overlay,
  notifications,
  tracking,
  data,
  updates,
  advanced,
}

class SettingsTab extends StatefulWidget {
  const SettingsTab({
    required this.controller,
    required this.onShowOverlay,
    required this.onShowRecentLoot,
    required this.onNewSession,
    required this.onResetDatabase,
    super.key,
  });
  final AppController controller;
  final VoidCallback onShowOverlay;
  final VoidCallback onShowRecentLoot;
  final VoidCallback onNewSession;
  final Future<void> Function() onResetDatabase;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final searchController = TextEditingController();
  _SettingsCategory selectedCategory = _SettingsCategory.general;

  AppController get controller => widget.controller;
  VoidCallback get onShowOverlay => widget.onShowOverlay;
  VoidCallback get onShowRecentLoot => widget.onShowRecentLoot;
  VoidCallback get onNewSession => widget.onNewSession;
  Future<void> Function() get onResetDatabase => widget.onResetDatabase;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = controller.settings;
    final frostedGlass = settings['frostedGlass'] as bool? ?? false;
    final query = searchController.text.trim().toLowerCase();
    bool show(_SettingsCategory category, Iterable<String> terms) =>
        query.isEmpty
        ? selectedCategory == category
        : terms.any((term) => term.toLowerCase().contains(query));
    final categories = <(_SettingsCategory, String, String)>[
      (_SettingsCategory.general, l.generalSettings, 'settings'),
      (_SettingsCategory.overlay, l.overlaySettings, 'overlay'),
      (_SettingsCategory.notifications, l.notificationSettings, 'loot'),
      (_SettingsCategory.tracking, l.trackingSettings, 'play'),
      (_SettingsCategory.data, l.dataSettings, 'market'),
      (_SettingsCategory.updates, l.updateSettings, 'refresh'),
      (_SettingsCategory.advanced, l.advancedSettings, 'mouse'),
    ];
    final hasSearchResults =
        query.isEmpty ||
        [
          ...categories.map((item) => item.$2),
          l.language,
          l.theme,
          l.mainFontSize,
          l.gameSettings,
          l.applicationBehavior,
          l.windowBehavior,
          l.appearanceSettings,
          l.typographySettings,
          l.league,
          l.priceRefresh,
          l.closeBehavior,
          l.overlayMode,
          l.floating,
          l.minimal,
          l.windowAppearance,
          l.alwaysOnTop,
          l.clickThrough,
          l.frostedGlass,
          l.transparentOverlayBorder,
          l.textOpacity,
          l.backgroundOpacity,
          l.frostedGlassGlow,
          l.frostedGlassOpacity,
          l.frostedGlassBlur,
          l.floatingFontSize,
          l.minimalFontSize,
          l.showOverlay,
          l.pickupNotifications,
          l.maxVisiblePickups,
          l.pickupDisplayDuration,
          l.previewPickupNotifications,
          l.pause,
          l.resume,
          l.newSession,
          l.confirmNewSession,
          l.databaseManagement,
          l.resetDatabase,
          l.updateSource,
          l.updateSourceCdn,
          l.updateSourceNative,
          l.updateSourceCustom,
          l.checkForUpdates,
          l.forceOverwriteUpdate,
          l.offsetSettings,
          l.playerInventory,
          l.entity,
          l.components,
          l.itemOffsets,
        ].any((term) => term.toLowerCase().contains(query));
    return Row(
      children: [
        Container(
          width: 190,
          decoration: BoxDecoration(
            color: context.colors.card.withValues(alpha: .55),
            border: Border(right: BorderSide(color: context.colors.border)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l.searchSettings,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(11),
                      child: AppSvg('search', size: 16),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 38),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              searchController.clear();
                              setState(() {});
                            },
                            icon: const AppSvg('close', size: 14),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _CategoryTab(
                      icon: category.$3,
                      label: category.$2,
                      selected:
                          searchController.text.isEmpty &&
                          selectedCategory == category.$1,
                      onTap: () {
                        searchController.clear();
                        setState(() => selectedCategory = category.$1);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 28, 32),
            children: [
              Text(
                searchController.text.isEmpty
                    ? categories
                          .firstWhere((item) => item.$1 == selectedCategory)
                          .$2
                    : l.settingsSearchResults,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (!hasSearchResults)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(
                    child: Text(
                      l.noSettingsFound,
                      style: TextStyle(color: context.colors.mutedForeground),
                    ),
                  ),
                ),
              if (show(_SettingsCategory.general, [
                l.generalSettings,
                l.language,
                l.theme,
                l.mainFontSize,
                l.gameSettings,
                l.league,
                l.priceRefresh,
                l.applicationBehavior,
                l.closeBehavior,
              ]))
                _group(context, l.generalSettings, [
                  _choice(
                    context,
                    l.language,
                    settings['language']?.toString() == 'zh'
                        ? 'zh'
                        : settings['language']?.toString() == 'en'
                        ? 'en'
                        : '',
                    {'': l.systemDefault, 'en': l.english, 'zh': l.chinese},
                    (value) => controller.updateSettings({'language': value}),
                  ),
                  _choice(
                    context,
                    l.theme,
                    settings['themeMode']?.toString() ?? 'dark',
                    {
                      'system': l.systemDefault,
                      'dark': l.dark,
                      'light': l.light,
                    },
                    (value) => controller.updateSettings({'themeMode': value}),
                  ),
                  _subheading(context, l.gameSettings),
                  _choice(
                    context,
                    l.league,
                    settings['league']?.toString() ?? 'Standard',
                    {for (final league in controller.leagues) league: league},
                    (value) => controller.updateSettings({'league': value}),
                  ),
                  _choice(
                    context,
                    l.priceRefresh,
                    '${settings['priceCacheMinutes'] ?? 30}',
                    {
                      for (final value in [5, 15, 30, 60, 120])
                        '$value': '$value ${l.minutes}',
                    },
                    (value) => controller.updateSettings({
                      'priceCacheMinutes': int.parse(value),
                    }),
                  ),
                  _subheading(context, l.typographySettings),
                  _scaleSlider(
                    context,
                    l.mainFontSize,
                    (settings['mainFontScale'] as num?)?.toDouble() ?? 1,
                    (value) =>
                        controller.updateSettings({'mainFontScale': value}),
                  ),
                  _subheading(context, l.applicationBehavior),
                  _choice(
                    context,
                    l.closeBehavior,
                    settings['closeAction']?.toString() ?? '',
                    {
                      '': l.askEveryTime,
                      'overlay': l.minimizeToOverlay,
                      'exit': l.exitApp,
                    },
                    (value) =>
                        controller.updateSettings({'closeAction': value}),
                  ),
                ]),
              if (show(_SettingsCategory.overlay, [
                l.overlaySettings,
                l.overlayMode,
                l.floating,
                l.minimal,
                l.windowBehavior,
                l.windowAppearance,
                l.alwaysOnTop,
                l.clickThrough,
                l.appearanceSettings,
                l.frostedGlass,
                l.transparentOverlayBorder,
                l.textOpacity,
                l.backgroundOpacity,
                l.frostedGlassGlow,
                l.frostedGlassOpacity,
                l.frostedGlassBlur,
                l.typographySettings,
                l.floatingFontSize,
                l.minimalFontSize,
                l.showOverlay,
              ])) ...[
                _group(context, l.overlayMode, [
                  _choice(
                    context,
                    l.overlayMode,
                    settings['overlayMode']?.toString() ?? 'floating',
                    {'floating': l.floating, 'minimal': l.minimal},
                    (value) =>
                        controller.updateSettings({'overlayMode': value}),
                  ),
                  _subheading(context, l.windowBehavior),
                  _choice(
                    context,
                    l.windowAppearance,
                    overlayWindowStyle(settings['overlayWindowStyle']),
                    {'frameless': l.framelessWindow, 'normal': l.normalWindow},
                    (value) => controller.updateSettings({
                      'overlayWindowStyle': value,
                    }),
                  ),
                  _toggle(
                    context,
                    l.alwaysOnTop,
                    settings['alwaysOnTop'] as bool? ?? true,
                    (value) =>
                        controller.updateSettings({'alwaysOnTop': value}),
                  ),
                  _toggle(
                    context,
                    l.clickThrough,
                    settings['clickThrough'] as bool? ?? false,
                    (value) =>
                        controller.updateSettings({'clickThrough': value}),
                  ),
                  _subheading(context, l.appearanceSettings),
                  _toggle(
                    context,
                    l.frostedGlass,
                    frostedGlass,
                    (value) =>
                        controller.updateSettings({'frostedGlass': value}),
                  ),
                  if (frostedGlass) ...[
                    _slider(
                      context,
                      l.frostedGlassOpacity,
                      (settings['frostedGlassOpacity'] as num?)?.toDouble() ??
                          .7,
                      (value) => controller.updateSettings({
                        'frostedGlassOpacity': value,
                      }),
                    ),
                    _slider(
                      context,
                      l.frostedGlassBlur,
                      (settings['frostedGlassBlur'] as num?)?.toDouble() ?? .65,
                      (value) => controller.updateSettings({
                        'frostedGlassBlur': value,
                      }),
                    ),
                    _slider(
                      context,
                      l.frostedGlassGlow,
                      (settings['frostedGlassGlow'] as num?)?.toDouble() ?? .5,
                      (value) => controller.updateSettings({
                        'frostedGlassGlow': value,
                      }),
                    ),
                  ] else
                    _slider(
                      context,
                      l.backgroundOpacity,
                      (settings['backgroundOpacity'] as num?)?.toDouble() ??
                          .94,
                      (value) => controller.updateSettings({
                        'backgroundOpacity': value,
                      }),
                    ),
                  _slider(
                    context,
                    l.textOpacity,
                    (settings['textOpacity'] as num?)?.toDouble() ?? 1,
                    (value) =>
                        controller.updateSettings({'textOpacity': value}),
                  ),
                  _toggle(
                    context,
                    l.transparentOverlayBorder,
                    settings['transparentOverlayBorder'] as bool? ?? false,
                    (value) => controller.updateSettings({
                      'transparentOverlayBorder': value,
                    }),
                  ),
                  _subheading(context, l.typographySettings),
                  _scaleSlider(
                    context,
                    l.floatingFontSize,
                    (settings['floatingFontScale'] as num?)?.toDouble() ?? 1,
                    (value) =>
                        controller.updateSettings({'floatingFontScale': value}),
                  ),
                  _scaleSlider(
                    context,
                    l.minimalFontSize,
                    (settings['minimalFontScale'] as num?)?.toDouble() ?? 1,
                    (value) =>
                        controller.updateSettings({'minimalFontScale': value}),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FButton(
                          onPress: onShowOverlay,
                          mainAxisSize: MainAxisSize.min,
                          prefix: const AppSvg(
                            'overlay',
                            color: Color(0xFF181A20),
                          ),
                          child: Text(l.showOverlay),
                        ),
                      ],
                    ),
                  ),
                ]),
              ],
              if (show(_SettingsCategory.notifications, [
                l.notificationSettings,
                l.pickupNotifications,
                l.maxVisiblePickups,
                l.pickupDisplayDuration,
                l.previewPickupNotifications,
              ]))
                _group(context, l.notificationSettings, [
                  _toggle(
                    context,
                    l.pickupNotifications,
                    settings['pickupToastsEnabled'] as bool? ?? true,
                    (value) => controller.updateSettings({
                      'pickupToastsEnabled': value,
                    }),
                  ),
                  _choice(
                    context,
                    l.maxVisiblePickups,
                    '${settings['pickupToastMaxVisible'] ?? 3}',
                    {
                      for (var value = 1; value <= 10; value++)
                        '$value': '$value',
                    },
                    (value) => controller.updateSettings({
                      'pickupToastMaxVisible': int.parse(value),
                    }),
                  ),
                  _choice(
                    context,
                    l.pickupDisplayDuration,
                    '${settings['pickupToastDurationSeconds'] ?? 2.5}',
                    {
                      for (final value in [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10])
                        '$value': '$value ${l.seconds}',
                    },
                    (value) => controller.updateSettings({
                      'pickupToastDurationSeconds': double.parse(value),
                    }),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FButton(
                      onPress: onShowRecentLoot,
                      mainAxisSize: MainAxisSize.min,
                      prefix: const AppSvg('loot', color: Color(0xFF181A20)),
                      child: Text(l.previewPickupNotifications),
                    ),
                  ),
                ]),
              if (show(_SettingsCategory.tracking, [
                l.trackingSettings,
                l.tracking,
                l.pause,
                l.resume,
                l.newSession,
                l.confirmNewSession,
              ]))
                _group(context, l.tracking, [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.snapshot.trackingPaused
                              ? l.pause
                              : l.trackingActive,
                          style: TextStyle(
                            color: controller.snapshot.trackingPaused
                                ? tradingRed
                                : tradingGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      FButton(
                        onPress: controller.pauseOrResume,
                        variant: FButtonVariant.outline,
                        mainAxisSize: MainAxisSize.min,
                        child: Text(
                          controller.snapshot.trackingPaused
                              ? l.resume
                              : l.pause,
                        ),
                      ),
                      const SizedBox(width: 10),
                      FButton(
                        onPress: onNewSession,
                        mainAxisSize: MainAxisSize.min,
                        child: Text(l.newSession),
                      ),
                    ],
                  ),
                  _toggle(
                    context,
                    l.confirmNewSession,
                    settings['confirmNewSession'] as bool? ?? true,
                    (value) =>
                        controller.updateSettings({'confirmNewSession': value}),
                  ),
                ]),
              if (show(_SettingsCategory.data, [
                l.dataSettings,
                l.databaseManagement,
                l.resetDatabase,
                l.resetDatabaseHint,
              ]))
                _group(context, l.databaseManagement, [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.resetDatabaseHint,
                          style: TextStyle(
                            color: context.colors.mutedForeground,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FButton(
                        onPress: onResetDatabase,
                        variant: FButtonVariant.outline,
                        mainAxisSize: MainAxisSize.min,
                        child: Text(
                          l.resetDatabase,
                          style: const TextStyle(color: tradingRed),
                        ),
                      ),
                    ],
                  ),
                ]),
              if (show(_SettingsCategory.updates, [
                l.updateSettings,
                l.updates,
                l.updateSource,
                l.updateSourceCdn,
                l.updateSourceNative,
                l.updateSourceCustom,
                l.currentVersion(appVersion),
                l.checkForUpdates,
                l.forceOverwriteUpdate,
              ]))
                _group(context, l.updates, [
                  _choice(
                    context,
                    l.updateSource,
                    controller.updateSource,
                    {
                      'cdn': l.updateSourceCdn,
                      'native': l.updateSourceNative,
                      'custom': l.updateSourceCustom,
                    },
                    (value) =>
                        controller.updateSettings({'updateSource': value}),
                  ),
                  if (controller.updateSource == 'cdn')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        l.updateCdnHint(defaultUpdateCdnPrefix),
                        style: TextStyle(
                          color: context.colors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (controller.updateSource == 'custom')
                    _CustomUpdateCdn(controller: controller),
                  const Divider(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.currentVersion(appVersionFull)),
                            const SizedBox(height: 4),
                            Text(
                              _updateStatus(l),
                              style: TextStyle(
                                color:
                                    controller.updatePhase == UpdatePhase.failed
                                    ? tradingRed
                                    : context.colors.mutedForeground,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          FButton(
                            onPress: _updateBusy
                                ? null
                                : controller.updatePhase ==
                                      UpdatePhase.available
                                ? controller.installAvailableUpdate
                                : controller.checkForUpdates,
                            variant:
                                controller.updatePhase == UpdatePhase.available
                                ? FButtonVariant.primary
                                : FButtonVariant.outline,
                            mainAxisSize: MainAxisSize.min,
                            child: Text(
                              controller.updatePhase == UpdatePhase.available
                                  ? controller.isInstalledEdition
                                        ? l.downloadAndInstall
                                        : l.openReleasePage
                                  : l.checkForUpdates,
                            ),
                          ),
                          FButton(
                            onPress: _updateBusy
                                ? null
                                : controller.forceInstallLatestUpdate,
                            variant: FButtonVariant.outline,
                            mainAxisSize: MainAxisSize.min,
                            child: Text(
                              controller.isInstalledEdition
                                  ? l.forceOverwriteUpdate
                                  : l.openLatestRelease,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.isInstalledEdition
                        ? l.forceOverwriteUpdateHint
                        : l.portableUpdateHint,
                    style: TextStyle(
                      color: context.colors.mutedForeground,
                      fontSize: 12,
                    ),
                  ),
                ]),
              if (show(_SettingsCategory.advanced, [
                l.advancedSettings,
                l.offsetSettings,
                l.playerInventory,
                l.entity,
                l.components,
                l.itemOffsets,
              ]))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _OffsetSettings(controller: controller),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _group(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  Widget _subheading(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 4),
    child: Text(
      label,
      style: TextStyle(
        color: context.colors.mutedForeground,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _toggle(
    BuildContext context,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        FSwitch(value: value, onChange: onChanged),
      ],
    ),
  );

  Widget _choice(
    BuildContext context,
    String label,
    String value,
    Map<String, String> choices,
    ValueChanged<String> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 260,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.colors.background,
              border: Border.all(color: context.colors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: choices.containsKey(value) ? value : choices.keys.first,
                isExpanded: true,
                dropdownColor: context.colors.card,
                icon: const AppSvg('chevron_down', size: 16),
                items: choices.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (next) {
                  if (next != null) onChanged(next);
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _slider(
    BuildContext context,
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 210,
          child: Slider(
            value: value.clamp(0, 1),
            activeColor: brandYellow,
            onChanged: onChanged,
            onChangeEnd: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: context.numberStyle,
          ),
        ),
      ],
    ),
  );

  Widget _scaleSlider(
    BuildContext context,
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 210,
          child: Slider(
            value: value.clamp(.75, 1.5),
            min: .75,
            max: 1.5,
            divisions: 15,
            activeColor: brandYellow,
            onChanged: onChanged,
            onChangeEnd: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: context.numberStyle,
          ),
        ),
      ],
    ),
  );

  bool get _updateBusy =>
      controller.updatePhase == UpdatePhase.checking ||
      controller.updatePhase == UpdatePhase.downloading ||
      controller.updatePhase == UpdatePhase.installing;

  String _updateStatus(AppLocalizations l) => switch (controller.updatePhase) {
    UpdatePhase.idle => l.checkForUpdates,
    UpdatePhase.checking => l.checkingForUpdates,
    UpdatePhase.upToDate => l.upToDate,
    UpdatePhase.available => l.updateAvailable(
      controller.availableUpdate!.version,
    ),
    UpdatePhase.downloading => l.downloadingUpdate(
      controller.updateDownloadPercent,
    ),
    UpdatePhase.installing => l.installingUpdate,
    UpdatePhase.installerOpened => l.installerOpened,
    UpdatePhase.failed => l.updateCheckFailed(controller.updateError ?? ''),
  };
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
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
    padding: const EdgeInsets.only(bottom: 4),
    child: Material(
      color: selected ? brandYellow.withValues(alpha: .14) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              AppSvg(
                icon,
                size: 18,
                color: selected ? brandYellow : context.colors.mutedForeground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? brandYellow : null,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CustomUpdateCdn extends StatefulWidget {
  const _CustomUpdateCdn({required this.controller});
  final AppController controller;

  @override
  State<_CustomUpdateCdn> createState() => _CustomUpdateCdnState();
}

class _CustomUpdateCdnState extends State<_CustomUpdateCdn> {
  late final TextEditingController field = TextEditingController(
    text: widget.controller.customUpdateCdn,
  );

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  Future<void> _save() =>
      widget.controller.updateSettings({'customUpdateCdn': field.text.trim()});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(l.customUpdateCdn)),
          SizedBox(
            width: 260,
            child: TextField(
              controller: field,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                isDense: true,
                hintText: l.customUpdateCdnHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FButton(
            onPress: _save,
            variant: FButtonVariant.outline,
            mainAxisSize: MainAxisSize.min,
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}

class _OffsetSettings extends StatefulWidget {
  const _OffsetSettings({required this.controller});
  final AppController controller;
  @override
  State<_OffsetSettings> createState() => _OffsetSettingsState();
}

class _OffsetSettingsState extends State<_OffsetSettings> {
  final fields = <String, TextEditingController>{};
  String status = '';
  String profileSignature = '';
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFields);
    _syncFields();
  }

  /// Mirrors the offsets profile that [AppController.initialize] already fetched into the inputs.
  ///
  /// This used to fire its own `getOffsetProfile` from `initState`. Every tab lives in an
  /// IndexedStack and is therefore built by the first frame, which `main()` schedules *before*
  /// `AppController.initialize()` has spawned the tracker host, so that request lost the race on
  /// every launch and surfaced as "Unhandled Exception: Bad state: Tracker host is not running."
  void _syncFields() {
    final profile =
        widget.controller.offsets['pending'] ??
        widget.controller.offsets['current'];
    if (profile is! Map || profile.isEmpty) return;
    // Only rewrite the inputs when the profile itself changed. This also runs on every controller
    // notification, and reassigning the text unconditionally would fight the user mid-keystroke.
    final signature = profile.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('|');
    if (signature == profileSignature) return;
    profileSignature = signature;
    for (final entry in profile.entries) {
      fields
              .putIfAbsent(entry.key.toString(), () => TextEditingController())
              .text =
          '0x${(entry.value as num).toInt().toRadixString(16).toUpperCase()}';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFields);
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(l.offsetSettings),
          const SizedBox(height: 12),
          if (fields.isEmpty)
            Text(
              l.loading,
              style: TextStyle(color: context.colors.mutedForeground),
            )
          else
            ..._groups(context),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              status,
              style: TextStyle(
                color: status == l.validationFailed ? tradingRed : tradingGreen,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: [
              FButton(
                onPress: _test,
                variant: FButtonVariant.outline,
                mainAxisSize: MainAxisSize.min,
                child: Text(l.testOffsets),
              ),
              FButton(
                onPress: _apply,
                mainAxisSize: MainAxisSize.min,
                child: Text(l.apply),
              ),
              FButton(
                onPress: _restore,
                variant: FButtonVariant.ghost,
                mainAxisSize: MainAxisSize.min,
                child: Text(l.restoreDefaults),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _groups(BuildContext context) {
    final l = AppLocalizations.of(context);
    const groups = <String, List<String>>{
      'player': [
        'ServerDataPlayerVector',
        'PlayerInventoriesVector',
        'InventoryArrayStride',
        'InventoryArrayId',
        'InventoryArrayPointer',
        'InventoryTotalBoxes',
        'InventoryItemList',
        'InventoryItemItem',
        'MainInventoryId',
      ],
      'entity': ['EntityDetailsPointer', 'EntityDetailsName'],
      'components': [
        'EntityComponentList',
        'EntityComponentLookup',
        'ComponentLookupBucket',
        'ComponentNameIndexStride',
      ],
      'items': [
        'StackCount',
        'ModsRarity',
        'RenderItemArt',
        'BaseDisplayNameRow',
        'BaseDisplayName',
      ],
    };
    final labels = {
      'player': l.playerInventory,
      'entity': l.entity,
      'components': l.components,
      'items': l.itemOffsets,
    };
    final fieldLabels = <String, String>{
      'ServerDataPlayerVector': l.serverDataOffset,
      'PlayerInventoriesVector': l.playerInventoriesOffset,
      'InventoryArrayStride': l.inventoryStride,
      'InventoryArrayId': l.inventoryIdOffset,
      'InventoryArrayPointer': l.inventoryPointerOffset,
      'InventoryTotalBoxes': l.inventorySizeOffset,
      'InventoryItemList': l.inventoryItemsOffset,
      'InventoryItemItem': l.inventoryItemPointerOffset,
      'MainInventoryId': l.mainInventoryId,
      'EntityDetailsPointer': l.entityDetailsPointerOffset,
      'EntityDetailsName': l.entityNameOffset,
      'EntityComponentList': l.entityComponentListOffset,
      'EntityComponentLookup': l.entityComponentLookupOffset,
      'ComponentLookupBucket': l.componentBucketOffset,
      'ComponentNameIndexStride': l.componentNameStride,
      'StackCount': l.stackCountOffset,
      'ModsRarity': l.modsRarityOffset,
      'RenderItemArt': l.renderArtOffset,
      'BaseDisplayNameRow': l.baseNameRowOffset,
      'BaseDisplayName': l.baseNameOffset,
    };
    return groups.entries
        .map(
          (group) => ExpansionTile(
            tilePadding: EdgeInsets.zero,
            trailing: const AppSvg('chevron_down', size: 16),
            initiallyExpanded: group.key == 'player',
            title: Text(labels[group.key]!),
            children: group.value
                .where(fields.containsKey)
                .map(
                  (name) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fieldLabels[name]!,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.mutedForeground,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: fields[name],
                            style: context.numberStyle,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Not wrapped in a Tooltip: Material's Tooltip holds a fresh
                        // GlobalKey<RawTooltipState> per instance, and this tab sits inside an
                        // IndexedStack, so it is rebuilt on every state push whether or not it is
                        // the visible tab -- recycling that element once a second for each offset
                        // row is exactly what produced a stream of tree-integrity assertions.
                        InkWell(
                          onTap: () => Clipboard.setData(
                            ClipboardData(text: fields[name]!.text),
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: AppSvg('copy', size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  Map<String, String> get values => {
    for (final entry in fields.entries) entry.key: entry.value.text,
  };
  Future<void> _test() async {
    final result = await widget.controller.testOffsets(values);
    if (mounted) {
      setState(
        () => status = result['status'] == 'valid'
            ? AppLocalizations.of(context).validationPassed
            : result['status'] == 'pending'
            ? AppLocalizations.of(context).pendingValidation
            : AppLocalizations.of(context).validationFailed,
      );
    }
  }

  Future<void> _apply() async {
    final result = await widget.controller.applyOffsets(values);
    if (mounted) {
      setState(
        () => status = ((result['validation'] as Map?)?['status'] == 'valid')
            ? AppLocalizations.of(context).validationPassed
            : AppLocalizations.of(context).pendingValidation,
      );
    }
  }

  Future<void> _restore() async {
    // restoreOffsets() replaces controller.offsets, and _syncFields repopulates the inputs.
    await widget.controller.restoreOffsets();
  }
}
