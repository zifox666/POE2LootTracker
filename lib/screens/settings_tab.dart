import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../app_controller.dart';
import '../app_theme.dart';
import '../app_version.dart';
import '../l10n/app_localizations.dart';
import '../update_service.dart';
import '../widgets/common.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({
    required this.controller,
    required this.onShowOverlay,
    required this.onNewSession,
    super.key,
  });
  final AppController controller;
  final VoidCallback onShowOverlay;
  final VoidCallback onNewSession;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = controller.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      children: [
        _group(context, l.settings, [
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
            settings['themeMode']?.toString() ?? 'system',
            {'system': l.systemDefault, 'dark': l.dark, 'light': l.light},
            (value) => controller.updateSettings({'themeMode': value}),
          ),
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
        ]),
        const SizedBox(height: 16),
        _group(context, l.overlayMode, [
          _choice(
            context,
            l.overlayMode,
            settings['overlayMode']?.toString() ?? 'floating',
            {'floating': l.floating, 'minimal': l.minimal},
            (value) => controller.updateSettings({'overlayMode': value}),
          ),
          _toggle(
            context,
            l.alwaysOnTop,
            settings['alwaysOnTop'] as bool? ?? true,
            (value) => controller.updateSettings({'alwaysOnTop': value}),
          ),
          _toggle(
            context,
            l.clickThrough,
            settings['clickThrough'] as bool? ?? false,
            (value) => controller.updateSettings({'clickThrough': value}),
          ),
          _slider(
            context,
            l.textOpacity,
            (settings['textOpacity'] as num?)?.toDouble() ?? 1,
            (value) => controller.updateSettings({'textOpacity': value}),
          ),
          _slider(
            context,
            l.backgroundOpacity,
            (settings['backgroundOpacity'] as num?)?.toDouble() ?? .94,
            (value) => controller.updateSettings({'backgroundOpacity': value}),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FButton(
              onPress: onShowOverlay,
              mainAxisSize: MainAxisSize.min,
              prefix: const AppSvg('overlay', color: Color(0xFF181A20)),
              child: Text(l.showOverlay),
            ),
          ),
        ]),
        const SizedBox(height: 16),
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
                  controller.snapshot.trackingPaused ? l.resume : l.pause,
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
            (value) => controller.updateSettings({'confirmNewSession': value}),
          ),
        ]),
        const SizedBox(height: 16),
        _group(context, l.closeWindowTitle, [
          _choice(
            context,
            l.closeBehavior,
            settings['closeAction']?.toString() ?? '',
            {
              '': l.askEveryTime,
              'overlay': l.minimizeToOverlay,
              'exit': l.exitApp,
            },
            (value) => controller.updateSettings({'closeAction': value}),
          ),
        ]),
        const SizedBox(height: 16),
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
            (value) => controller.updateSettings({'updateSource': value}),
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
                        color: controller.updatePhase == UpdatePhase.failed
                            ? tradingRed
                            : context.colors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FButton(
                onPress: _updateBusy
                    ? null
                    : controller.updatePhase == UpdatePhase.available
                    ? controller.installAvailableUpdate
                    : controller.checkForUpdates,
                variant: controller.updatePhase == UpdatePhase.available
                    ? FButtonVariant.primary
                    : FButtonVariant.outline,
                mainAxisSize: MainAxisSize.min,
                child: Text(
                  controller.updatePhase == UpdatePhase.available
                      ? l.downloadAndInstall
                      : l.checkForUpdates,
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 16),
        _OffsetSettings(controller: controller),
      ],
    );
  }

  Widget _group(BuildContext context, String title, List<Widget> children) =>
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(title),
            const SizedBox(height: 8),
            ...children,
          ],
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
    UpdatePhase.failed => l.updateCheckFailed(controller.updateError ?? ''),
  };
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
