import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'app_version.dart';
import 'host_client.dart';
import 'models.dart';
import 'steam_stats_service.dart';
import 'update_service.dart';

enum UpdatePhase {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  installing,
  installerOpened,
  failed,
}

class AppController extends ChangeNotifier {
  AppController({
    HostClient? host,
    UpdateService? updateService,
    SteamStatsService? steamStatsService,
    this.startHost = true,
  }) : host = host ?? HostClient(),
       updateService = updateService ?? UpdateService(),
       steamStatsService = steamStatsService ?? SteamStatsService();
  final HostClient host;
  final UpdateService updateService;
  final SteamStatsService steamStatsService;
  final bool startHost;
  StreamSubscription<Map<String, dynamic>>? _events;
  Timer? _onlinePlayersTimer;

  TrackerSnapshot snapshot = TrackerSnapshot.empty;
  List<SessionRow> sessions = [];
  List<Map<String, dynamic>> historyMaps = [];
  List<MarketPrice> marketPrices = [];
  Map<String, dynamic> mapDetail = const {};
  Map<String, dynamic> settings = defaultSettings;
  Map<String, dynamic> offsets = const {};
  List<String> leagues = const ['Standard'];
  String? selectedSessionId;
  String? selectedMapId;
  String marketQuery = '';
  String? error;
  bool databaseCorrupted = false;
  bool loading = true;
  bool screenCaptureActive = false;
  UpdatePhase updatePhase = UpdatePhase.idle;
  UpdateRelease? availableUpdate;
  String? updateError;
  int updateDownloadPercent = 0;
  int? onlinePlayers;
  DateTime _lastSnapshotNotify = DateTime.fromMillisecondsSinceEpoch(0);

  /// Minimum spacing between rebuilds driven by `trackerSnapshot` pushes from the host.
  static const snapshotNotifyInterval = Duration(seconds: 1);

  Locale get locale {
    final language = settings['language'] as String? ?? '';
    if (language == 'zh') return const Locale('zh');
    if (language == 'en') return const Locale('en');
    return PlatformDispatcher.instance.locale.languageCode
            .toLowerCase()
            .startsWith('zh')
        ? const Locale('zh')
        : const Locale('en');
  }

  bool get darkMode {
    switch (settings['themeMode']) {
      case 'dark':
        return true;
      case 'light':
        return false;
      default:
        return PlatformDispatcher.instance.platformBrightness ==
            Brightness.dark;
    }
  }

  List<CostPreset> get costPresets =>
      listOfMaps(settings['costPresets']).map(CostPreset.fromJson).toList();

  String get selectedCostPresetId =>
      settings['selectedCostPresetId']?.toString() ?? '';

  String get updateSource => settings['updateSource']?.toString() ?? 'cdn';

  String get customUpdateCdn => settings['customUpdateCdn']?.toString() ?? '';

  bool get isInstalledEdition => updateService.isInstalledEdition;

  String get leagueName {
    final league = settings['league']?.toString().trim() ?? '';
    return league.isEmpty ? 'Standard' : league;
  }

  String get defaultCostPresetId =>
      costPresets
          .where((preset) => preset.isDefault)
          .map((preset) => preset.id)
          .firstOrNull ??
      selectedCostPresetId;

  Future<void> initialize() async {
    if (!startHost) {
      loading = false;
      notifyListeners();
      return;
    }
    try {
      await host.start();
      _events = host.events.listen(_handleEvent);
      final values = await Future.wait([
        host.request('getSnapshot'),
        host.request('getSettings'),
        host.request('listSessions'),
        // Fetched here rather than lazily by the settings tab: the tabs are all built by the first
        // frame, which runs before this method has spawned the host, so a tab that asked for this
        // itself lost the race and threw "Tracker host is not running" on every launch.
        host.request('getOffsetProfile'),
      ]);
      _readSnapshot(values[0]);
      _readSettings(values[1]);
      _readSessions(values[2]);
      offsets = _asMap(values[3]);
      await refreshMarket();
    } catch (exception) {
      final message = host.lastError ?? exception.toString();
      databaseCorrupted = databaseCorrupted || _isDatabaseCorruption(message);
      error ??= message;
    } finally {
      loading = false;
      notifyListeners();
    }
    unawaited(checkForUpdates(silent: true));
    unawaited(refreshOnlinePlayers());
    _onlinePlayersTimer ??= Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(refreshOnlinePlayers()),
    );
  }

  Future<void> refreshOnlinePlayers() async {
    try {
      final players = await steamStatsService.currentPlayers();
      if (players == onlinePlayers) return;
      onlinePlayers = players;
      notifyListeners();
    } catch (exception) {
      // Network failures must not compete with tracking errors or make the title bar noisy.  A
      // later periodic refresh will retry, and the UI deliberately keeps its last known value.
      debugPrint('steam: player count refresh failed: $exception');
    }
  }

  Future<void> checkForUpdates({
    bool silent = false,
    bool allowCurrentVersion = false,
  }) async {
    if (updatePhase == UpdatePhase.checking ||
        updatePhase == UpdatePhase.downloading ||
        updatePhase == UpdatePhase.installing) {
      return;
    }
    updatePhase = UpdatePhase.checking;
    updateError = null;
    notifyListeners();
    try {
      availableUpdate = await updateService.checkForUpdate(
        appVersion,
        source: updateSource,
        customCdn: customUpdateCdn,
        allowCurrentVersion: allowCurrentVersion,
      );
      updatePhase = availableUpdate == null
          ? UpdatePhase.upToDate
          : UpdatePhase.available;
    } catch (exception) {
      updateError = exception.toString();
      updatePhase = silent ? UpdatePhase.idle : UpdatePhase.failed;
      if (silent) debugPrint('update check failed: $exception');
    }
    notifyListeners();
  }

  Future<void> forceInstallLatestUpdate() async {
    await checkForUpdates(allowCurrentVersion: true);
    if (updatePhase == UpdatePhase.available) {
      await installAvailableUpdate();
    }
  }

  Future<void> installAvailableUpdate() async {
    final release = availableUpdate;
    if (release == null || updatePhase != UpdatePhase.available) return;
    if (!isInstalledEdition) {
      try {
        await updateService.openReleasePage(release);
      } catch (exception) {
        updateError = exception.toString();
        updatePhase = UpdatePhase.failed;
        notifyListeners();
      }
      return;
    }
    updatePhase = UpdatePhase.downloading;
    updateDownloadPercent = 0;
    updateError = null;
    notifyListeners();
    try {
      await updateService.downloadAndLaunch(
        release,
        source: updateSource,
        customCdn: customUpdateCdn,
        onProgress: (received, total) {
          if (total <= 0) return;
          final percent = (received * 100 ~/ total).clamp(0, 100);
          if (percent == updateDownloadPercent) return;
          updateDownloadPercent = percent;
          notifyListeners();
        },
      );
      updatePhase = UpdatePhase.installerOpened;
      notifyListeners();
    } catch (exception) {
      updateError = exception.toString();
      updatePhase = UpdatePhase.failed;
      notifyListeners();
    }
  }

  Future<void> refreshSessions() async {
    _readSessions(await host.request('listSessions'));
    notifyListeners();
  }

  Future<void> selectSession(String? id) async {
    selectedSessionId = id;
    selectedMapId = null;
    mapDetail = const {};
    if (id == null || id == snapshot.activeSessionId) {
      historyMaps = [];
    } else {
      historyMaps = listOfMaps(
        await host.request('listMaps', {'sessionId': id}),
      );
    }
    notifyListeners();
  }

  Future<void> selectMap(String? id) async {
    selectedMapId = id;
    mapDetail = id == null
        ? const {}
        : _asMap(await host.request('getMapDetail', {'mapId': id}));
    notifyListeners();
  }

  Future<void> refreshMarket([String? query]) async {
    if (query != null) marketQuery = query;
    final data = await host.request('listMarketPrices', {
      'query': marketQuery,
      'limit': 1000,
    });
    marketPrices = listOfMaps(data).map(MarketPrice.fromJson).toList();
    notifyListeners();
  }

  Future<void> requestPriceRefresh() async {
    await host.request('refreshMarketPrices');
    notifyListeners();
  }

  Future<void> setManualPrice(String itemKey, double priceEx) async {
    await host.request('setManualPrice', {
      'itemKey': itemKey,
      'priceEx': priceEx,
    });
    await refreshMarket();
  }

  Future<void> clearManualPrice(String itemKey) async {
    await host.request('clearManualPrice', {'itemKey': itemKey});
    await refreshMarket();
  }

  Future<void> pauseOrResume() async {
    final result = await host.request(
      snapshot.trackingPaused ? 'resumeTracking' : 'pauseTracking',
    );
    _readSnapshot(result);
    notifyListeners();
  }

  Future<void> newSession() async {
    _readSnapshot(await host.request('startNewSession'));
    selectedSessionId = null;
    selectedMapId = null;
    await refreshSessions();
  }

  Future<void> updateSettings(Map<String, dynamic> changes) async {
    final next = <String, dynamic>{...settings, ...changes};
    _readSettings(await host.request('updateSettings', next));
    notifyListeners();
  }

  Future<void> saveCostPreset(CostPreset preset) async {
    final presets = [
      for (final value in costPresets)
        preset.isDefault && value.id != preset.id
            ? value.copyWith(isDefault: false)
            : value,
    ];
    final index = presets.indexWhere((value) => value.id == preset.id);
    if (index < 0) {
      presets.add(preset);
    } else {
      presets[index] = preset;
    }
    await updateSettings({
      'costPresets': presets.map((value) => value.toJson()).toList(),
      'selectedCostPresetId':
          presets
              .where((value) => value.isDefault)
              .map((value) => value.id)
              .firstOrNull ??
          '',
    });
  }

  Future<void> deleteCostPreset(String id) async {
    final presets = costPresets.where((value) => value.id != id).toList();
    await updateSettings({
      'costPresets': presets.map((value) => value.toJson()).toList(),
      'selectedCostPresetId':
          presets
              .where((value) => value.isDefault)
              .map((value) => value.id)
              .firstOrNull ??
          '',
    });
  }

  Future<void> selectCostPreset(String? id) async {
    _readSettings(
      await host.request('selectCostPreset', {'presetId': id ?? ''}),
    );
    _readSnapshot(await host.request('getSnapshot'));
    notifyListeners();
  }

  Future<void> loadOffsets() async {
    offsets = _asMap(await host.request('getOffsetProfile'));
    notifyListeners();
  }

  Future<Map<String, dynamic>> testOffsets(Map<String, String> values) async {
    final result = _asMap(
      await host.request('testOffsetProfile', {'offsets': values}),
    );
    await loadOffsets();
    return result;
  }

  Future<Map<String, dynamic>> applyOffsets(Map<String, String> values) async {
    final result = _asMap(
      await host.request('applyOffsetProfile', {'offsets': values}),
    );
    await loadOffsets();
    return result;
  }

  Future<void> restoreOffsets() async {
    await host.request('restoreDefaultOffsets');
    await loadOffsets();
  }

  Future<Map<String, dynamic>> getWindowState(String key) async =>
      _asMap(await host.request('getWindowState', {'windowKey': key}));

  Future<void> saveWindowState(
    String key,
    double x,
    double y,
    double width,
    double height,
  ) async {
    await host.request('updateWindowState', {
      'windowKey': key,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    });
  }

  void applyForwardedState(Map<String, dynamic> state) {
    if (state['snapshot'] is Map) _readSnapshot(state['snapshot']);
    if (state['settings'] is Map) settings = _asMap(state['settings']);
    if (state['screenCaptureActive'] is bool) {
      screenCaptureActive = state['screenCaptureActive'] as bool;
    }
    notifyListeners();
  }

  Map<String, dynamic> forwardedState() => {
    'snapshot': snapshotToJson(snapshot),
    'settings': settings,
    'screenCaptureActive': screenCaptureActive,
  };

  void _handleEvent(Map<String, dynamic> event) {
    if (event['type'] == 'trackerSnapshot') {
      // Keep every snapshot -- only the notification is rate-limited. The host pushes one every
      // 250 ms (tracker_host/Program.cs), and each push used to notify, which rebuilt the entire
      // widget tree -- and with it the semantics tree the Windows accessibility bridge walks --
      // four times a second. Every duration on screen is rendered in whole seconds, so collapsing
      // those into one update per second costs nothing visible and quarters that churn.
      final previousPickup = snapshot.recentPickups.isEmpty
          ? null
          : snapshot.recentPickups.first;
      _readSnapshot(event['payload']);
      final newestPickup = snapshot.recentPickups.isEmpty
          ? null
          : snapshot.recentPickups.first;
      final pickupChanged =
          previousPickup?.key != newestPickup?.key ||
          previousPickup?.count != newestPickup?.count ||
          previousPickup?.pickedUpUtc != newestPickup?.pickedUpUtc;
      final now = DateTime.now();
      if (!pickupChanged &&
          now.difference(_lastSnapshotNotify) < snapshotNotifyInterval) {
        return;
      }
      _lastSnapshotNotify = now;
      notifyListeners();
      return;
    }
    if (event['type'] == 'settingsChanged') _readSettings(event['payload']);
    if (event['type'] == 'screenCaptureChanged') {
      screenCaptureActive =
          _asMap(event['payload'])['active'] as bool? ?? false;
    }
    if (event['type'] == 'hostError') {
      final message = _asMap(event['payload'])['message']?.toString() ?? '';
      databaseCorrupted = databaseCorrupted || _isDatabaseCorruption(message);
      error = message;
    }
    notifyListeners();
  }

  /// Records a failure that the shell should surface to the user.
  ///
  /// Nothing read [error] before this, so every failure -- a dead host, a window that could not be
  /// created -- was invisible: exactly what "the button does nothing" looked like from the outside.
  void setError(String? message) {
    final next = message ?? '';
    if (error == next || (error == null && next.isEmpty)) return;
    error = next;
    notifyListeners();
  }

  void _readSnapshot(dynamic value) {
    if (value is Map) {
      snapshot = TrackerSnapshot.fromJson(value.cast<String, dynamic>());
      _snapshotReceivedAt = DateTime.now();
    }
  }

  DateTime? _snapshotReceivedAt;

  /// The in-map clock, advanced locally since the last host push.
  ///
  /// The overlay window runs no tracker host of its own: its clock arrives inside the pushed state,
  /// which only lands a few times a second, and stops landing entirely if a push is late or fails.
  /// Interpolating here keeps the timer moving in between while never inventing time the host did
  /// not report -- it only advances while the pushed snapshot says the player is on a map, so a
  /// session in town still shows the last map frozen, which is what actually happened.
  Duration get liveMapTime {
    if (!snapshot.inMap) return snapshot.mapTime;
    final received = _snapshotReceivedAt;
    if (received == null) return snapshot.mapTime;
    return snapshot.mapTime + DateTime.now().difference(received);
  }

  void _readSettings(dynamic value) {
    final map = _asMap(value);
    if (map['settings'] is Map) {
      settings = <String, dynamic>{
        ...defaultSettings,
        ..._asMap(map['settings']),
      };
    }
    if (map['leagues'] is List) {
      leagues = (map['leagues'] as List)
          .map((entry) => entry.toString())
          .toList();
    }
  }

  void _readSessions(dynamic value) =>
      sessions = listOfMaps(value).map(SessionRow.fromJson).toList();
  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? value.cast<String, dynamic>() : const {};

  @override
  void dispose() {
    _events?.cancel();
    _onlinePlayersTimer?.cancel();
    if (startHost) unawaited(host.dispose());
    updateService.close();
    steamStatsService.close();
    super.dispose();
  }
}

bool _isDatabaseCorruption(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('sqlite error 11') ||
      normalized.contains('file is not a database') ||
      (normalized.contains('database') && normalized.contains('malformed'));
}

const defaultSettings = <String, dynamic>{
  'backgroundOpacity': 0.94,
  'textOpacity': 1.0,
  'alwaysOnTop': true,
  'clickThrough': false,
  'overlayMode': 'floating',
  'overlayWindowStyle': 'frameless',
  'floatingFontScale': 1.0,
  'minimalFontScale': 1.0,
  'mainFontScale': 1.0,
  'transparentOverlayBorder': false,
  'frostedGlass': false,
  'frostedGlassGlow': 0.5,
  'frostedGlassOpacity': 0.7,
  'frostedGlassBlur': 0.65,
  'pickupToastsEnabled': true,
  'pickupToastMaxVisible': 3,
  'pickupToastDurationSeconds': 2.5,
  'themeMode': 'dark',
  'themeModeConfigured': true,
  'language': '',
  'league': 'Standard',
  'priceCacheMinutes': 30,
  'riskAcknowledged': false,
  'welcomeCompleted': false,
  'confirmNewSession': true,
  'updateSource': 'cdn',
  'customUpdateCdn': '',
  // "" asks on every close, "exit" quits, "overlay" keeps tracking in the small window.
  'closeAction': '',
};

Map<String, dynamic> snapshotToJson(TrackerSnapshot value) => {
  'activeSessionId': value.activeSessionId,
  'gameConnected': value.gameConnected,
  'inMap': value.inMap,
  'trackingPaused': value.trackingPaused,
  'status': value.status,
  'mapName': value.mapName,
  'currentCostPresetId': value.currentCostPresetId,
  'currentCostName': value.currentCostName,
  'currentCostEx': value.currentCostEx,
  'mapTime': value.mapTime.inMilliseconds,
  'sessionTime': value.sessionTime.inMilliseconds,
  // Also pushed: the overlay has no host of its own, so anything it displays has to travel in this
  // payload. Leaving it out made the overlay's "average map time" read 00:00.
  'activeTime': value.activeTime.inMilliseconds,
  'currentProfitEx': value.currentProfitEx,
  'totalProfitEx': value.totalProfitEx,
  'perHourEx': value.perHourEx,
  'divineRate': value.divineRate,
  'mapCount': value.mapCount,
  'kills': value.kills,
  'loot': value.loot
      .map(
        (e) => {
          'key': e.key,
          'name': e.name,
          'count': e.count,
          'unitEx': e.unitEx,
          'totalEx': e.totalEx,
          'priced': e.priced,
          'iconUrl': e.iconUrl,
        },
      )
      .toList(),
  'recentPickups': value.recentPickups
      .map(
        (e) => {
          'key': e.key,
          'name': e.name,
          'count': e.count,
          'unitEx': e.unitEx,
          'totalEx': e.totalEx,
          'priced': e.priced,
          'iconUrl': e.iconUrl,
          'pickedUpUtc': e.pickedUpUtc?.toIso8601String(),
        },
      )
      .toList(),
  'maps': value.maps
      .map(
        (e) => {
          'id': e.id,
          'name': e.name,
          'areaLevel': e.areaLevel,
          'activeTime': e.activeTime.inMilliseconds,
          'profitEx': e.profitEx,
          'costEx': e.costEx,
          'lootTypes': e.lootTypes,
          'kills': e.kills,
          'active': e.active,
        },
      )
      .toList(),
  'priceUpdatedUtc': value.priceUpdatedUtc?.toIso8601String(),
  'priceStatus': value.priceStatus,
  'priceError': value.priceError,
};
