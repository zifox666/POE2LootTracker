import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../app_controller.dart';
import '../app_theme.dart';
import '../data/endgame_maps.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../widgets/common.dart';

class CostSettingsTab extends StatelessWidget {
  const CostSettingsTab({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final presets = controller.costPresets;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      children: [
        SectionTitle(
          l.costSettings,
          trailing: FButton(
            onPress: () => _edit(context),
            mainAxisSize: MainAxisSize.min,
            prefix: const AppSvg('plus', color: Color(0xFF181A20)),
            child: Text(l.addCostPreset),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.costSettingsHint,
          style: TextStyle(color: context.colors.mutedForeground),
        ),
        const SizedBox(height: 18),
        if (presets.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  l.noCostPresets,
                  style: TextStyle(color: context.colors.mutedForeground),
                ),
              ),
            ),
          )
        else
          for (final preset in presets) ...[
            _PresetCard(
              preset: preset,
              onMakeDefault: () =>
                  controller.saveCostPreset(preset.copyWith(isDefault: true)),
              onEdit: () => _edit(context, preset),
              onDelete: () => _delete(context, preset),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Future<void> _edit(BuildContext context, [CostPreset? preset]) async {
    final result = await showDialog<CostPreset>(
      context: context,
      builder: (_) => _CostPresetDialog(
        preset: preset,
        defaultIsDefault:
            preset == null && !controller.costPresets.any((p) => p.isDefault),
      ),
    );
    if (result != null) await controller.saveCostPreset(result);
  }

  Future<void> _delete(BuildContext context, CostPreset preset) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(l.deleteCostPreset),
        content: Text(l.deleteCostPresetBody(preset.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteCostPreset(preset.id);
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.onMakeDefault,
    required this.onEdit,
    required this.onDelete,
  });

  final CostPreset preset;
  final VoidCallback onMakeDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final maps = mapOptionsForAliases(preset.mapNames);
    final visible = maps.take(4).map((map) => map.zhCn).join('、');
    final mapText = maps.isEmpty
        ? l.manualOnly
        : maps.length > 4
        ? '$visible · +${maps.length - 4}'
        : visible;
    return AppCard(
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onMakeDefault,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: preset.isDefault ? brandYellow : Colors.transparent,
                border: Border.all(
                  color: preset.isDefault
                      ? brandYellow
                      : context.colors.mutedForeground,
                  width: 2,
                ),
              ),
              child: preset.isDefault
                  ? const Center(
                      child: SizedBox.square(
                        dimension: 7,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFF181A20),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        preset.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (preset.isDefault) ...[
                      const SizedBox(width: 8),
                      _DefaultBadge(label: l.defaultCost),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  mapText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                AppIcon(
                  preset.currency == 'D'
                      ? 'currency_divine'
                      : 'currency_exalted',
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  formatNumber(preset.amount),
                  style: context.numberStyle.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: Text(l.edit)),
          TextButton(onPressed: onDelete, child: Text(l.delete)),
        ],
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: brandYellow.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: brandYellow,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _CostPresetDialog extends StatefulWidget {
  const _CostPresetDialog({this.preset, required this.defaultIsDefault});

  final CostPreset? preset;
  final bool defaultIsDefault;

  @override
  State<_CostPresetDialog> createState() => _CostPresetDialogState();
}

class _CostPresetDialogState extends State<_CostPresetDialog> {
  late final TextEditingController name = TextEditingController(
    text: widget.preset?.name ?? '',
  );
  late final TextEditingController amount = TextEditingController(
    text: widget.preset == null ? '' : formatNumber(widget.preset!.amount),
  );
  late String currency = widget.preset?.currency ?? 'E';
  late bool isDefault = widget.preset?.isDefault ?? widget.defaultIsDefault;
  late Set<String> selectedMapKeys = mapOptionsForAliases(
    widget.preset?.mapNames ?? const [],
  ).map((map) => map.key).toSet();
  late final Set<String> unmatchedLegacyNames = _unmatchedNames(
    widget.preset?.mapNames ?? const [],
  );
  String? error;

  static Set<String> _unmatchedNames(Iterable<String> names) {
    final matched = mapOptionsForAliases(names)
        .expand((option) => option.aliases)
        .map((name) => name.toLowerCase())
        .toSet();
    return {
      for (final name in names)
        if (!matched.contains(name.toLowerCase())) name,
    };
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selectedMaps = [
      for (final option in endgameMaps)
        if (selectedMapKeys.contains(option.key)) option,
    ];
    return AlertDialog(
      backgroundColor: context.colors.card,
      title: Text(widget.preset == null ? l.addCostPreset : l.editCostPreset),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(l.costName, name),
            const SizedBox(height: 14),
            Text(
              l.costPrice,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 96,
                  child: DropdownButtonFormField<String>(
                    initialValue: currency,
                    dropdownColor: context.colors.card,
                    items: const [
                      DropdownMenuItem(value: 'E', child: Text('E')),
                      DropdownMenuItem(value: 'D', child: Text('D')),
                    ],
                    onChanged: (value) =>
                        setState(() => currency = value ?? 'E'),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.defaultCost),
                      const SizedBox(height: 2),
                      Text(
                        l.defaultCostHint,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                FSwitch(
                  value: isDefault,
                  onChange: (value) => setState(() => isDefault = value),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.mapNames,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.mutedForeground,
                    ),
                  ),
                ),
                TextButton(onPressed: _chooseMaps, child: Text(l.chooseMaps)),
              ],
            ),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 54, maxHeight: 120),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colors.background,
                border: Border.all(color: context.colors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: selectedMaps.isEmpty
                  ? Center(
                      child: Text(
                        l.noMapsSelected,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.mutedForeground,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final map in selectedMaps)
                            _SelectedMapChip(
                              name: map.zhCn,
                              onRemove: () => setState(
                                () => selectedMapKeys.remove(map.key),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 5),
            Text(
              l.mapNamesHint,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.mutedForeground,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: const TextStyle(color: tradingRed, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(onPressed: _save, child: Text(l.apply)),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 12, color: context.colors.mutedForeground),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        decoration: const InputDecoration(isDense: true),
      ),
    ],
  );

  Future<void> _chooseMaps() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _MapPickerDialog(selected: selectedMapKeys),
    );
    if (result != null) setState(() => selectedMapKeys = result);
  }

  void _save() {
    final l = AppLocalizations.of(context);
    final parsed = double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (name.text.trim().isEmpty || parsed == null || parsed <= 0) {
      setState(() => error = l.invalidCostPreset);
      return;
    }
    Navigator.pop(
      context,
      CostPreset(
        id:
            widget.preset?.id ??
            'cost_${DateTime.now().microsecondsSinceEpoch}',
        name: name.text.trim(),
        amount: parsed,
        currency: currency,
        mapNames: {
          ...aliasesForMapKeys(selectedMapKeys),
          ...unmatchedLegacyNames,
        }.toList(),
        isDefault: isDefault,
      ),
    );
  }
}

class _SelectedMapChip extends StatelessWidget {
  const _SelectedMapChip({required this.name, required this.onRemove});

  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(9, 5, 5, 5),
    decoration: BoxDecoration(
      color: context.colors.card,
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 4),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onRemove,
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: AppSvg('close', size: 10),
          ),
        ),
      ],
    ),
  );
}

class _MapPickerDialog extends StatefulWidget {
  const _MapPickerDialog({required this.selected});

  final Set<String> selected;

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late Set<String> selected = {...widget.selected};
  String query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final needle = query.trim().toLowerCase();
    final options = needle.isEmpty
        ? endgameMaps
        : [
            for (final option in endgameMaps)
              if (option.aliases.any(
                (name) => name.toLowerCase().contains(needle),
              ))
                option,
          ];
    return AlertDialog(
      backgroundColor: context.colors.card,
      title: Text(l.chooseMaps),
      content: SizedBox(
        width: 520,
        height: 500,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                isDense: true,
                hintText: l.searchMaps,
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(11),
                  child: AppSvg('search', size: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final checked = selected.contains(option.key);
                  return CheckboxListTile(
                    dense: true,
                    value: checked,
                    activeColor: brandYellow,
                    checkColor: const Color(0xFF181A20),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(option.zhCn),
                    subtitle: Text(
                      '${option.zhTw} · ${option.en}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.mutedForeground,
                      ),
                    ),
                    onChanged: (_) => setState(() {
                      if (checked) {
                        selected.remove(option.key);
                      } else {
                        selected.add(option.key);
                      }
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(selected.clear),
          child: Text(l.clear),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, selected),
          child: Text(l.apply),
        ),
      ],
    );
  }
}
