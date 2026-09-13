import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:window_manager/window_manager.dart';

import '../app_controller.dart';
import '../app_theme.dart';
import '../app_version.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    required this.controller,
    required this.onShowOverlayPreview,
    required this.onFinish,
    required this.onClose,
    super.key,
  });

  final AppController controller;
  final Future<bool> Function() onShowOverlayPreview;
  final Future<void> Function() onFinish;
  final VoidCallback onClose;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int step = 0;
  bool finishing = false;
  late double backgroundOpacity;
  late double textOpacity;
  late double floatingFontScale;
  late double minimalFontScale;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    final settings = controller.settings;
    backgroundOpacity =
        (settings['backgroundOpacity'] as num?)?.toDouble() ?? .94;
    textOpacity = (settings['textOpacity'] as num?)?.toDouble() ?? 1;
    floatingFontScale =
        (settings['floatingFontScale'] as num?)?.toDouble() ?? 1;
    minimalFontScale = (settings['minimalFontScale'] as num?)?.toDouble() ?? 1;
  }

  void _update(Map<String, dynamic> changes) {
    unawaited(controller.updateSettings(changes));
  }

  void _next() {
    if (step == 2) return;
    setState(() => step++);
    if (step == 2) unawaited(widget.onShowOverlayPreview());
  }

  void _back() {
    if (step == 0) return;
    setState(() => step--);
  }

  Future<void> _selectOverlayMode(String mode) async {
    await controller.updateSettings({'overlayMode': mode});
    await widget.onShowOverlayPreview();
  }

  Future<void> _finish() async {
    if (finishing) return;
    setState(() => finishing = true);
    await widget.onFinish();
    if (mounted) setState(() => finishing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          _WelcomeTitleBar(onClose: widget.onClose),
          Expanded(
            child: Row(
              children: [
                _WelcomeRail(step: step),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 780),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(48, 30, 48, 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l.welcomeTitle,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l.welcomeSubtitle,
                              style: TextStyle(
                                color: context.colors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: KeyedSubtree(
                                  key: ValueKey(step),
                                  child: switch (step) {
                                    0 => _appearanceStep(context),
                                    1 => _leagueStep(context),
                                    _ => _overlayStep(context),
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                if (step > 0)
                                  OutlinedButton(
                                    onPressed: finishing ? null : _back,
                                    child: Text(l.previous),
                                  ),
                                const Spacer(),
                                FButton(
                                  onPress: finishing
                                      ? null
                                      : step == 2
                                      ? () => unawaited(_finish())
                                      : _next,
                                  mainAxisSize: MainAxisSize.min,
                                  child: Text(
                                    step == 2 ? l.finishSetup : l.next,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appearanceStep(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = controller.settings;
    final configuredLanguage = settings['language']?.toString();
    final language = configuredLanguage == 'en' || configuredLanguage == 'zh'
        ? configuredLanguage!
        : controller.locale.languageCode;
    return _StepCard(
      icon: 'settings',
      title: l.welcomeAppearanceTitle,
      hint: l.welcomeAppearanceHint,
      child: Column(
        children: [
          _SettingRow(
            label: l.language,
            child: DropdownButton<String>(
              value: language,
              icon: const AppSvg('chevron_down', size: 14),
              items: [
                DropdownMenuItem(value: 'zh', child: Text(l.chinese)),
                DropdownMenuItem(value: 'en', child: Text(l.english)),
              ],
              onChanged: (value) {
                if (value != null) _update({'language': value});
              },
            ),
          ),
          const Divider(height: 32),
          _SettingRow(
            label: l.theme,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'dark', label: Text(l.dark)),
                ButtonSegment(value: 'light', label: Text(l.light)),
              ],
              selected: {
                settings['themeMode']?.toString() == 'light' ? 'light' : 'dark',
              },
              onSelectionChanged: (values) {
                _update({'themeMode': values.single});
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _leagueStep(BuildContext context) {
    final l = AppLocalizations.of(context);
    final leagues = controller.leagues.isEmpty
        ? const ['Standard']
        : controller.leagues;
    var selected = controller.settings['league']?.toString() ?? 'Standard';
    if (!leagues.contains(selected)) selected = leagues.first;
    return _StepCard(
      icon: 'market',
      title: l.welcomeLeagueTitle,
      hint: l.welcomeLeagueHint,
      child: _SettingRow(
        label: l.league,
        child: SizedBox(
          width: 320,
          child: DropdownButtonFormField<String>(
            initialValue: selected,
            icon: const AppSvg('chevron_down', size: 14),
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final league in leagues)
                DropdownMenuItem(value: league, child: Text(league)),
            ],
            onChanged: (value) {
              if (value != null) _update({'league': value});
            },
          ),
        ),
      ),
    );
  }

  Widget _overlayStep(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = controller.settings;
    final mode = settings['overlayMode'] == 'minimal' ? 'minimal' : 'floating';
    final fontScale = mode == 'minimal' ? minimalFontScale : floatingFontScale;
    return _StepCard(
      icon: 'overlay',
      title: l.welcomeOverlayTitle,
      hint: l.welcomeOverlayHint,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    title: l.floating,
                    selected: mode == 'floating',
                    onTap: () => unawaited(_selectOverlayMode('floating')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeCard(
                    title: l.minimal,
                    selected: mode == 'minimal',
                    onTap: () => unawaited(_selectOverlayMode('minimal')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: brandYellow.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: brandYellow.withValues(alpha: .35)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const AppSvg('mouse', size: 18, color: brandYellow),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.welcomeOverlayDragHint)),
                    TextButton(
                      onPressed: () => unawaited(widget.onShowOverlayPreview()),
                      child: Text(l.showOverlay),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ToggleTile(
                    label: l.alwaysOnTop,
                    value: settings['alwaysOnTop'] as bool? ?? true,
                    onChanged: (value) => _update({'alwaysOnTop': value}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ToggleTile(
                    label: l.clickThrough,
                    value: settings['clickThrough'] as bool? ?? false,
                    onChanged: (value) => _update({'clickThrough': value}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LabeledSlider(
              label: l.backgroundOpacity,
              value: backgroundOpacity,
              onChanged: (value) => setState(() => backgroundOpacity = value),
              onChangeEnd: (value) => _update({'backgroundOpacity': value}),
            ),
            _LabeledSlider(
              label: l.textOpacity,
              value: textOpacity,
              onChanged: (value) => setState(() => textOpacity = value),
              onChangeEnd: (value) => _update({'textOpacity': value}),
            ),
            _LabeledSlider(
              label: mode == 'minimal' ? l.minimalFontSize : l.floatingFontSize,
              value: fontScale,
              min: .75,
              max: 1.5,
              onChanged: (value) => setState(() {
                if (mode == 'minimal') {
                  minimalFontScale = value;
                } else {
                  floatingFontScale = value;
                }
              }),
              onChangeEnd: (value) => _update({
                mode == 'minimal' ? 'minimalFontScale' : 'floatingFontScale':
                    value,
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeTitleBar extends StatelessWidget {
  const _WelcomeTitleBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
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
                    const AppSvg('logo', size: 22),
                    const SizedBox(width: 9),
                    Text(
                      AppLocalizations.of(context).appTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'v$appVersionFull',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _WindowAction(icon: 'minimize', onTap: windowManager.minimize),
          _WindowAction(icon: 'close', onTap: onClose),
        ],
      ),
    ),
  );
}

class _WelcomeRail extends StatelessWidget {
  const _WelcomeRail({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = [
      l.welcomeAppearanceStep,
      l.welcomeLeagueStep,
      l.welcomeOverlayStep,
    ];
    return Container(
      width: 230,
      padding: const EdgeInsets.fromLTRB(24, 44, 20, 24),
      decoration: BoxDecoration(
        color: context.colors.card.withValues(alpha: .65),
        border: Border(right: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            _StepIndicator(
              number: index + 1,
              label: labels[index],
              selected: index == step,
              completed: index < step,
            ),
            if (index != labels.length - 1) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.number,
    required this.label,
    required this.selected,
    required this.completed,
  });

  final int number;
  final String label;
  final bool selected;
  final bool completed;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected || completed
              ? brandYellow
              : context.colors.background,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected || completed ? brandYellow : context.colors.border,
          ),
        ),
        child: completed
            ? const AppSvg('check', size: 17)
            : Text(
                '$number',
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF181A20)
                      : context.colors.mutedForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? null : context.colors.mutedForeground,
          ),
        ),
      ),
    ],
  );
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.icon,
    required this.title,
    required this.hint,
    required this.child,
  });

  final String icon;
  final String title;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.colors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: brandYellow.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: AppSvg(icon, size: 21, color: brandYellow),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hint,
                      style: TextStyle(color: context.colors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Align(alignment: Alignment.topCenter, child: child),
          ),
        ],
      ),
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      child,
    ],
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: selected
            ? brandYellow.withValues(alpha: .1)
            : context.colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? brandYellow : context.colors.border,
        ),
      ),
      child: Row(
        children: [
          AppSvg(selected ? 'radio_selected' : 'radio_unselected', size: 18),
          const SizedBox(width: 9),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: context.colors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          FSwitch(value: value, onChange: onChanged),
        ],
      ),
    ),
  );
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    this.min = 0,
    this.max = 1,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 150, child: Text(label)),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: brandYellow,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
      SizedBox(
        width: 46,
        child: Text(
          '${(value * 100).round()}%',
          textAlign: TextAlign.right,
          style: TextStyle(color: context.colors.mutedForeground),
        ),
      ),
    ],
  );
}

class _WindowAction extends StatelessWidget {
  const _WindowAction({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      width: 48,
      height: 54,
      child: Center(child: AppSvg(icon, size: 14)),
    ),
  );
}
