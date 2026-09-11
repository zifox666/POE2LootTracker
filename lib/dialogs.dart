import 'dart:async';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'l10n/app_localizations.dart';
import 'widgets/common.dart';

/// The usage disclaimer, shown at every launch.
///
/// Its confirm button stays disabled for [seconds] so the text has actually been on screen long
/// enough to read: 10 seconds the first time the app is ever used, 3 seconds after that. The dialog
/// itself cannot be dismissed with the usual barrier tap or back gesture.
Future<void> showUsageWarning(BuildContext context, {required int seconds}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UsageWarningDialog(seconds: seconds),
  );
}

/// Offers an update discovered by the automatic startup check.
Future<bool> confirmUpdateAvailable(
  BuildContext context, {
  required String version,
}) async {
  final l = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: context.colors.card,
          title: Text(l.updateDialogTitle),
          content: Text(l.updateDialogBody(version)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l.later),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l.downloadAndInstall),
            ),
          ],
        ),
      ) ??
      false;
}

/// Keeps update progress visible after the startup prompt starts the download.
Future<void> showUpdateProgress(
  BuildContext context, {
  required AppController controller,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _UpdateProgressDialog(controller: controller),
);

class _UpdateProgressDialog extends StatefulWidget {
  const _UpdateProgressDialog({required this.controller});

  final AppController controller;

  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.installAvailableUpdate());
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final phase = widget.controller.updatePhase;
      final percent = widget.controller.updateDownloadPercent;
      final failed = phase == UpdatePhase.failed;
      final status = switch (phase) {
        UpdatePhase.downloading => l.downloadingUpdate(percent),
        UpdatePhase.installing => l.installingUpdate,
        UpdatePhase.failed => l.updateCheckFailed(
          widget.controller.updateError ?? '',
        ),
        _ => l.downloadingUpdate(percent),
      };
      return PopScope(
        canPop: failed,
        child: AlertDialog(
          backgroundColor: context.colors.card,
          title: Text(l.updateDialogTitle),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status),
                if (!failed) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: phase == UpdatePhase.downloading && percent > 0
                        ? percent / 100
                        : null,
                  ),
                ],
              ],
            ),
          ),
          actions: failed
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      MaterialLocalizations.of(context).closeButtonLabel,
                    ),
                  ),
                ]
              : null,
        ),
      );
    },
  );
}

class _UsageWarningDialog extends StatefulWidget {
  const _UsageWarningDialog({required this.seconds});

  final int seconds;

  @override
  State<_UsageWarningDialog> createState() => _UsageWarningDialogState();
}

class _UsageWarningDialogState extends State<_UsageWarningDialog> {
  late int remaining = widget.seconds;
  Timer? ticker;

  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => remaining = remaining > 0 ? remaining - 1 : 0);
      if (remaining == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: context.colors.card,
      title: Text(l.startupWarningTitle),
      content: Text(l.startupWarningBody),
      actions: [
        TextButton(
          onPressed: remaining > 0 ? null : () => Navigator.pop(context),
          child: Text(
            remaining > 0 ? l.acknowledgeIn(remaining) : l.acknowledge,
          ),
        ),
      ],
    );
  }
}

/// Asks before a new session starts. Returns whether the caller should go ahead.
///
/// A ticked "remember my choice" turns the question off for good by storing
/// `confirmNewSession: false`, which the settings tab can turn back on. It is only honoured when the
/// user confirms -- remembering a *cancel* would silently make the button do nothing later.
Future<bool> confirmNewSession(
  BuildContext context,
  AppController controller,
) async {
  if (controller.settings['confirmNewSession'] != true) return true;
  final l = AppLocalizations.of(context);
  var remember = false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(l.newSession),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.confirmNewSessionBody),
            const SizedBox(height: 12),
            _RememberChoice(
              value: remember,
              onChanged: (value) => setState(() => remember = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.newSession),
          ),
        ],
      ),
    ),
  );
  if (confirmed == true && remember) {
    await controller.updateSettings({'confirmNewSession': false});
  }
  return confirmed == true;
}

/// Asks whether to carry on with the session the host restored, or start a fresh one.
///
/// Returns `true` to keep accumulating into the restored session, `false` to reset it. The host
/// reports `resumedSession` once it has loaded a previous run's session, so this is only asked when
/// there really is something to continue; a first launch has nothing to ask about.
///
/// Dismissing the dialog keeps the session too: it is already loaded and intact, so the harmless
/// answer is the one that changes nothing.
Future<bool> confirmResumeSession(
  BuildContext context, {
  required AppController controller,
}) async {
  final snapshot = controller.snapshot;
  final l = AppLocalizations.of(context);
  final started = snapshot.sessionStartedUtc?.toLocal();
  final localized = MaterialLocalizations.of(context);
  final time = started == null
      ? '—'
      : '${localized.formatMediumDate(started)} '
            '${localized.formatTimeOfDay(TimeOfDay.fromDateTime(started))}';
  final profit = formatAmount(snapshot.totalProfitEx, snapshot.divineRate);
  final profitText = '${profit.value} ${profit.unit}';

  final keep = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: context.colors.card,
      title: Text(l.resumeSessionTitle),
      content: Text(l.resumeSessionBody(time, snapshot.mapCount, profitText)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l.newSession),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l.continueSession),
        ),
      ],
    ),
  );
  return keep != false;
}

/// Closing the main window: quit the tracker, or keep it running in the small window.
///
/// A remembered answer is stored as `closeAction` ("exit" / "overlay") and applied directly next
/// time, which is what makes the dialog optional rather than annoying.
Future<void> confirmCloseMainWindow(
  BuildContext context, {
  required AppController controller,
  required Future<void> Function() onExit,
  required Future<void> Function() onOverlay,
}) async {
  final remembered = controller.settings['closeAction']?.toString() ?? '';
  if (remembered == 'exit') {
    await onExit();
    return;
  }
  if (remembered == 'overlay') {
    await onOverlay();
    return;
  }

  final l = AppLocalizations.of(context);
  var remember = false;
  final choice = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(l.closeWindowTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.closeWindowBody),
            const SizedBox(height: 12),
            _RememberChoice(
              value: remember,
              onChanged: (value) => setState(() => remember = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'overlay'),
            child: Text(l.minimizeToOverlay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'exit'),
            child: Text(l.exitApp),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return;
  if (remember) {
    await controller.updateSettings({'closeAction': choice});
  }
  if (choice == 'exit') {
    await onExit();
  } else {
    await onOverlay();
  }
}

/// Sets an item's manual price, in whichever of the two currencies the user picks.
///
/// Shared by the market table, the loot panel and the overlay. An item poe.ninja does not price is
/// exactly when a manual price is wanted, and the loot views had no way to set one -- the button
/// only existed in the market table, which lists items that already have a price.
///
/// The write goes through [onApply] / [onClear] rather than an [AppController] because the overlay's
/// controller runs with `startHost: false` and owns no tracker host; it forwards the change to the
/// main engine instead. [onApply] always receives **Exalted**, whichever unit was typed: the dialog
/// does the conversion, so no caller has to know about it.
Future<void> showManualPriceDialog(
  BuildContext context, {
  required String itemKey,
  required String name,
  required double divineRate,
  required Future<void> Function(double priceEx) onApply,
  required Future<void> Function() onClear,
  double? currentEx,
}) async {
  if (itemKey.isEmpty) return;
  final priceEx = await showDialog<double>(
    context: context,
    builder: (_) => _ManualPriceDialog(
      name: name,
      currentEx: currentEx,
      divineRate: divineRate,
    ),
  );
  if (priceEx == -1) await onClear();
  if (priceEx != null && priceEx > 0) await onApply(priceEx);
}

/// Two decimals with trailing zeros dropped, matching how amounts are shown everywhere else.
String _trim(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

class _ManualPriceDialog extends StatefulWidget {
  const _ManualPriceDialog({
    required this.name,
    required this.divineRate,
    this.currentEx,
  });

  final String name;
  final double divineRate;
  final double? currentEx;

  @override
  State<_ManualPriceDialog> createState() => _ManualPriceDialogState();
}

class _ManualPriceDialogState extends State<_ManualPriceDialog> {
  /// Owned here, and NOT by [showManualPriceDialog].
  ///
  /// `showDialog`'s future completes as soon as the route is popped, which is before the exit
  /// animation has run and the fields are unmounted. Creating the controller at the call site and
  /// disposing it right after the await therefore pulled it out from under a still-live
  /// `EditableText`, and the framework answered with a stream of element/render-tree assertions
  /// (`_lifecycleState == active`, `child._parent == this`) for every frame of the teardown.
  late final TextEditingController input = TextEditingController(
    text: _initialText(),
  );

  /// Whether the number in the field means Divine or Exalted. Seeded from the value being edited
  /// using the same rule the rest of the UI uses to choose a display unit, so opening a price does
  /// not silently reinterpret it; a brand-new price starts at the Exalted side, which is what an
  /// item poe.ninja has no listing for is usually worth.
  late bool divine =
      widget.divineRate > 0 &&
      ((widget.currentEx ?? 0) / widget.divineRate).abs() > 0.3;

  String _initialText() {
    final current = widget.currentEx;
    if (current == null) return '';
    return _trim(divine ? current / widget.divineRate : current);
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  /// Switches the unit while keeping the *price* the same: the number is converted rather than
  /// reinterpreted, so flipping the toggle can never silently multiply a price by the divine rate.
  void _setUnit(bool toDivine) {
    if (toDivine == divine) return;
    final typed = double.tryParse(input.text.trim());
    final rate = widget.divineRate;
    setState(() {
      if (typed != null && typed > 0 && rate > 0) {
        final exalted = divine ? typed * rate : typed;
        input.text = _trim(toDivine ? exalted / rate : exalted);
      }
      divine = toDivine;
    });
  }

  void _apply() {
    final typed = double.tryParse(input.text.trim());
    if (typed == null || typed <= 0) {
      Navigator.pop(context);
      return;
    }
    final rate = widget.divineRate;
    Navigator.pop(context, divine && rate > 0 ? typed * rate : typed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rate = widget.divineRate;
    final typed = double.tryParse(input.text.trim());
    // Spelling out the other side of the conversion is what makes the toggle unambiguous.
    String? equivalent;
    if (typed != null && typed > 0 && rate > 0) {
      final exalted = divine ? typed * rate : typed;
      equivalent = divine
          ? '≈ ${_trim(exalted)} E'
          : '≈ ${_trim(exalted / rate)} D';
    }

    return AlertDialog(
      backgroundColor: context.colors.card,
      title: Text(widget.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: input,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.manualPrice),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _apply(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _unit(context, 'D', divine, () => _setUnit(true)),
              const SizedBox(width: 6),
              _unit(context, 'E', !divine, () => _setUnit(false)),
              const SizedBox(width: 10),
              if (equivalent != null)
                Text(
                  equivalent,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.mutedForeground,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        // -1 is the sentinel for "clear", matching what the caller checks.
        if (widget.currentEx != null)
          TextButton(
            onPressed: () => Navigator.pop(context, -1.0),
            child: Text(l.clear),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(onPressed: _apply, child: Text(l.apply)),
      ],
    );
  }

  /// The Divine side is only offered when a rate is known: without one there is no conversion to
  /// apply, and silently treating "1" as one Exalted is at least honest.
  Widget _unit(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final enabled = label != 'D' || widget.divineRate > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? brandYellow.withValues(alpha: .14) : null,
          border: Border.all(
            color: selected ? brandYellow : context.colors.border,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: !enabled
                  ? context.colors.mutedForeground
                  : selected
                  ? brandYellow
                  : context.colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _RememberChoice extends StatelessWidget {
  const _RememberChoice({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 24,
        height: 24,
        child: Checkbox(
          value: value,
          onChanged: (next) => onChanged(next ?? false),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        AppLocalizations.of(context).rememberChoice,
        style: const TextStyle(fontSize: 12),
      ),
    ],
  );
}
