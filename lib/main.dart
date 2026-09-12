import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:window_manager/window_manager.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'dialogs.dart';
import 'l10n/app_localizations.dart';
import 'overlay_window.dart';
import 'recent_loot_window.dart';
import 'screens/main_shell.dart';
import 'system_proxy.dart';
import 'window_coordinator.dart';
import 'windows_runtime.dart';

/// Runs [app] with the framework's semantics tree suppressed.
///
/// The Windows engine rebuilds a native `ui::AXTree` out of every semantics update, and this app
/// dies from that path reliably: the engine logs
///   "Failed to update ui::AXTree, error: N will not be in the tree and is not the new root" and
///   "Nodes left pending by the update: 19 20"
/// and the accessibility bridge then dereferences a null node and faults with an access violation
/// inside flutter_windows.dll, which surfaces as "Lost connection to device" / a silent exit.
/// It reproduces on a tab switch -- the first switch to the market tab does it every time -- which
/// is what shuffles a large subtree in and out of the semantics tree.
///
/// These are upstream bugs (flutter/flutter#98099, #190357, #192180; fixed by pull #190903, which
/// the engine this build links against does not carry). Suppressing semantics leaves the
/// accessibility tree at a bare root, so there is no node graph left for the engine to get wrong.
/// The cost is that the panel is no longer exposed to screen readers / UI Automation, which is an
/// acceptable trade for an elevated game overlay; narrow or drop this once the pinned engine
/// carries the upstream fix.
void _runWithoutSemantics(Widget app) => runApp(ExcludeSemantics(child: app));

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before anything can request an item icon. NetworkImage keeps one shared HttpClient for the whole
  // process, so the proxy override has to be installed before the first image is asked for.
  await useSystemProxy();
  // The window definition is read next, and it only needs desktop_multi_window -- the one plugin
  // every window has. window_manager is initialised below the overlay branch on purpose: if it
  // cannot come up, that must not stop the overlay from rendering its first frame.
  final currentWindow = await WindowController.fromCurrentEngine();
  final arguments = currentWindow.arguments.isEmpty
      ? const <String, dynamic>{}
      : (jsonDecode(currentWindow.arguments) as Map).cast<String, dynamic>();
  if (arguments['kind'] == 'overlay') {
    await configureOverlayWindow();
    _runWithoutSemantics(
      OverlayApplication(
        currentWindow: currentWindow,
        ownerId: arguments['ownerId'] as String? ?? '',
      ),
    );
    return;
  }
  if (arguments['kind'] == 'recentLoot') {
    await configureRecentLootWindow();
    _runWithoutSemantics(
      RecentLootApplication(
        currentWindow: currentWindow,
        ownerId: arguments['ownerId'] as String? ?? '',
      ),
    );
    return;
  }

  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(980, 680),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  final controller = AppController();
  final coordinator = WindowCoordinator(
    currentWindow: currentWindow,
    app: controller,
  );
  await coordinator.initialize();
  _runWithoutSemantics(
    MainApplication(controller: controller, coordinator: coordinator),
  );
  await controller.initialize();
}

class MainApplication extends StatefulWidget {
  const MainApplication({
    required this.controller,
    required this.coordinator,
    super.key,
  });
  final AppController controller;
  final WindowCoordinator coordinator;
  @override
  State<MainApplication> createState() => _MainApplicationState();
}

class _MainApplicationState extends State<MainApplication> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    // Tracker snapshots arrive continuously. Rebuilding MaterialApp while a native desktop text
    // input owns focus can make Windows drop that focus, interrupting typing in search and settings
    // fields. The next notification after editing finishes will refresh the shell normally.
    if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.coordinator.dispose();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = buildForuiTheme(widget.controller.darkMode);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: widget.controller.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...FLocalizations.localizationsDelegates,
      ],
      theme: theme.toApproximateMaterialTheme().copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: theme.colors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.colors.border),
          ),
        ),
      ),
      builder: (context, child) => applyFontScale(
        context,
        fontScaleSetting(widget.controller.settings, 'mainFontScale'),
        FTheme(
          data: theme,
          platform: FPlatformVariant.macOS,
          child: FTooltipGroup(child: child!),
        ),
      ),
      home: _DesktopShell(
        controller: widget.controller,
        coordinator: widget.coordinator,
      ),
    );
  }
}

/// Hosts the desktop runtime and the first-run warning.
///
/// This must stay *below* the [MaterialApp] built by [_MainApplicationState]:
/// both [AppLocalizations.of] and [showDialog] need a `Localizations`/`Navigator`
/// ancestor, but the state that creates the [MaterialApp] sits above it.
class _DesktopShell extends StatefulWidget {
  const _DesktopShell({required this.controller, required this.coordinator});
  final AppController controller;
  final WindowCoordinator coordinator;
  @override
  State<_DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<_DesktopShell> {
  late final WindowsRuntime runtime = WindowsRuntime(
    app: widget.controller,
    windows: widget.coordinator,
  );
  bool runtimeStarted = false;
  bool warningScheduled = false;
  bool resumeAsked = false;
  bool startupDialogsFinished = false;
  bool updatePromptScheduled = false;
  String? promptedUpdateVersion;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    // Alt+F4 and the taskbar's Close land here instead of destroying the window, so they get the
    // same dialog as the title bar's own close button.
    runtime.onCloseRequested = _closeMainWindow;
    runtime.onNewSessionRequested = _newSession;
    // The overlay's own new-session button lands here, so it asks the same question the title bar
    // and the settings tab do instead of discarding the session on its own.
    widget.coordinator.onNewSession = _newSession;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localizations = AppLocalizations.of(context);
    if (runtimeStarted) {
      unawaited(runtime.updateMenu(localizations));
      return;
    }
    runtimeStarted = true;
    unawaited(
      runtime.initialize().then((_) => runtime.updateMenu(localizations)),
    );
  }

  void _changed() {
    if (widget.controller.loading) return;
    // Shown on every launch, not just the first: it is a disclaimer, and the only thing the earlier
    // acknowledgement decides is how long it locks its own button.
    _scheduleWarning();
    if (startupDialogsFinished) _scheduleUpdatePrompt();
    if (runtimeStarted) {
      unawaited(runtime.restoreMainState());
      if (mounted) unawaited(runtime.updateMenu(AppLocalizations.of(context)));
    }
  }

  void _scheduleWarning() {
    if (warningScheduled) return;
    warningScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showUsageWarning());
  }

  Future<void> _showUsageWarning() async {
    if (!mounted) return;
    final firstRun = widget.controller.settings['riskAcknowledged'] != true;
    await showUsageWarning(context, seconds: firstRun ? 10 : 3);
    // The warning is intentionally displayed on every launch, but an already acknowledged value
    // does not need to be written on every launch. More importantly, failure to persist this one
    // convenience flag must never escape a post-frame callback and terminate the Flutter engine.
    if (firstRun) {
      try {
        await widget.controller.updateSettings({'riskAcknowledged': true});
      } catch (error) {
        debugPrint('startup: saving the usage acknowledgement failed: $error');
        widget.controller.setError('settings: $error');
      }
    }
    if (!mounted) return;
    await _maybeAskResume();
    if (!mounted) return;
    startupDialogsFinished = true;
    _scheduleUpdatePrompt();
  }

  void _scheduleUpdatePrompt() {
    final release = widget.controller.availableUpdate;
    if (!startupDialogsFinished ||
        updatePromptScheduled ||
        release == null ||
        widget.controller.updatePhase != UpdatePhase.available ||
        promptedUpdateVersion == release.version) {
      return;
    }
    updatePromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updatePromptScheduled = false;
      if (mounted) unawaited(_showUpdatePrompt());
    });
  }

  Future<void> _showUpdatePrompt() async {
    final release = widget.controller.availableUpdate;
    if (!mounted ||
        release == null ||
        widget.controller.updatePhase != UpdatePhase.available ||
        promptedUpdateVersion == release.version) {
      return;
    }
    promptedUpdateVersion = release.version;
    final install = await confirmUpdateAvailable(
      context,
      version: release.version,
      installedEdition: widget.controller.isInstalledEdition,
    );
    if (install && mounted) {
      if (widget.controller.isInstalledEdition) {
        await showUpdateProgress(context, controller: widget.controller);
      } else {
        await widget.controller.installAvailableUpdate();
      }
    }
  }

  /// Asks whether to keep adding to the session the host restored, or start a new one.
  ///
  /// Once per launch, and only when there is actually something to continue: the previous behaviour
  /// silently opened a new session, so a user who wanted to keep collecting had to say so before
  /// their first map. The controller has already read the host's snapshot by the time the warning is
  /// dismissed -- the warning is scheduled from the first notification after `loading` goes false,
  /// which happens only after `getSnapshot` returned -- so `resumedSession` is settled here and no
  /// waiting is needed.
  Future<void> _maybeAskResume() async {
    if (resumeAsked || !mounted) return;
    resumeAsked = true;
    if (!widget.controller.snapshot.resumedSession) return;
    if (await confirmResumeSession(context, controller: widget.controller)) {
      return;
    }
    await widget.controller.newSession();
  }

  Future<void> _newSession() async {
    if (!mounted) return;
    if (!await confirmNewSession(context, widget.controller)) return;
    await widget.controller.newSession();
  }

  Future<void> _closeMainWindow() async {
    if (!mounted) return;
    await confirmCloseMainWindow(
      context,
      controller: widget.controller,
      onExit: runtime.shutdown,
      onOverlay: () async {
        await widget.coordinator.showOverlay();
      },
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    unawaited(runtime.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MainShell(
    controller: widget.controller,
    onShowOverlay: widget.coordinator.showOverlay,
    onShowRecentLoot: widget.coordinator.previewRecentLoot,
    onNewSession: _newSession,
    onCloseWindow: _closeMainWindow,
  );
}
