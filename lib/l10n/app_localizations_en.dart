// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'POE2 LootTracker';

  @override
  String get lootStats => 'Loot statistics';

  @override
  String get mapLog => 'Map log';

  @override
  String get cost => 'Cost';

  @override
  String get costSettings => 'Cost settings';

  @override
  String get costSettingsHint =>
      'Associate each cost with any number of maps. Map matching checks Simplified Chinese, Traditional Chinese, and English names; unmatched maps use the default cost.';

  @override
  String get addCostPreset => 'Add cost';

  @override
  String get editCostPreset => 'Edit cost';

  @override
  String get deleteCostPreset => 'Delete cost';

  @override
  String deleteCostPresetBody(String name) {
    return 'Delete \"$name\"? This does not change historical map costs.';
  }

  @override
  String get noCostPresets => 'No cost presets yet';

  @override
  String get costName => 'Cost name';

  @override
  String get costPrice => 'Cost price';

  @override
  String get optionalMapName => 'Map name (optional)';

  @override
  String get optionalMapNameHint => 'Exact map name for automatic selection';

  @override
  String get mapNames => 'Maps';

  @override
  String get mapNamesHint =>
      'Each selected map is matched by its Simplified Chinese, Traditional Chinese, and English area names.';

  @override
  String get chooseMaps => 'Choose maps';

  @override
  String get searchMaps => 'Search maps in any language';

  @override
  String get noMapsSelected => 'No maps selected';

  @override
  String get defaultCost => 'Default';

  @override
  String get defaultCostHint =>
      'Used when the entered map is not assigned to another cost.';

  @override
  String get manualOnly => 'No assigned maps · available for manual switching';

  @override
  String get invalidCostPreset =>
      'Enter a cost name and a price greater than zero.';

  @override
  String get activeCost => 'Active cost';

  @override
  String get noCostPreset => 'No cost';

  @override
  String get manualCostFallback => 'Manual fallback for maps without a match';

  @override
  String mapMatch(String name) {
    return 'Auto: $name';
  }

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get profit => 'Profit';

  @override
  String get duration => 'Duration';

  @override
  String get noMaps => 'No maps recorded yet';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String pageOf(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get marketPrices => 'Market prices';

  @override
  String get settings => 'Settings';

  @override
  String get currentSession => 'Current session';

  @override
  String get selectSession => 'Session';

  @override
  String get selectMap => 'Map run';

  @override
  String get allMaps => 'All maps';

  @override
  String get currentMap => 'Current map';

  @override
  String get totalRevenue => 'Total revenue';

  @override
  String get revenuePerHour => 'Revenue per hour';

  @override
  String get mapCount => 'Maps';

  @override
  String get sessionTime => 'Session time';

  @override
  String get mapTime => 'Map time';

  @override
  String get totalMapTime => 'Total map time';

  @override
  String get efficiency => 'Efficiency';

  @override
  String get monsterKills => 'Monster kills';

  @override
  String get totalKills => 'Total kills';

  @override
  String get averageMapTime => 'Average map time';

  @override
  String get averageRevenue => 'Average per map';

  @override
  String get normal => 'Normal';

  @override
  String get magic => 'Magic';

  @override
  String get rare => 'Rare';

  @override
  String get unique => 'Unique';

  @override
  String get kills => 'Monster kills';

  @override
  String get lootDetails => 'Loot details';

  @override
  String get item => 'Item';

  @override
  String get quantity => 'Quantity';

  @override
  String get unitPrice => 'Unit price';

  @override
  String get total => 'Total';

  @override
  String get noLoot => 'No loot recorded for this selection';

  @override
  String get pickups => 'Pickups';

  @override
  String get pickupNotifications => 'Pickup notifications';

  @override
  String get maxVisiblePickups => 'Maximum visible pickups';

  @override
  String get pickupDisplayDuration => 'Display duration';

  @override
  String get seconds => 'seconds';

  @override
  String get costs => 'Costs';

  @override
  String get noCosts => 'No costs yet';

  @override
  String get waitingForPickups => 'Waiting for pickups';

  @override
  String get noPrices => 'No market prices match the current filter';

  @override
  String get allCategories => 'All categories';

  @override
  String get searchPrices => 'Search items';

  @override
  String get league => 'League';

  @override
  String get season => 'Season';

  @override
  String get onlinePlayers => 'Steam players online';

  @override
  String get syncStatus => 'Sync status';

  @override
  String get syncIdle => 'Idle';

  @override
  String get syncing => 'Syncing';

  @override
  String get syncReady => 'Ready';

  @override
  String get syncError => 'Error';

  @override
  String get divineRate => 'Divine rate';

  @override
  String get lastUpdated => 'Last updated';

  @override
  String get refresh => 'Refresh';

  @override
  String get manualPrice => 'Manual price';

  @override
  String get clear => 'Clear';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get systemDefault => 'System default';

  @override
  String get english => 'English';

  @override
  String get chinese => 'Chinese';

  @override
  String get overlayMode => 'Overlay mode';

  @override
  String get floating => 'Floating';

  @override
  String get minimal => 'Minimal';

  @override
  String get windowAppearance => 'Window appearance';

  @override
  String get framelessWindow => 'Frameless';

  @override
  String get normalWindow => 'normalWindow';

  @override
  String get alwaysOnTop => 'Always on top';

  @override
  String get clickThrough => 'Click through';

  @override
  String get textOpacity => 'Text opacity';

  @override
  String get backgroundOpacity => 'Background opacity';

  @override
  String get priceRefresh => 'Price refresh interval';

  @override
  String get minutes => 'minutes';

  @override
  String get tracking => 'Tracking';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get newSession => 'New session';

  @override
  String get confirmNewSessionBody =>
      'The current session will be closed and a new one started.';

  @override
  String get closeWindowTitle => 'Close the main window';

  @override
  String get closeWindowBody =>
      'Quit the tracker, or keep it running in the small window?';

  @override
  String get minimizeToOverlay => 'Minimize to the small window';

  @override
  String get closeBehavior => 'Closing the main window';

  @override
  String get askEveryTime => 'Ask every time';

  @override
  String get rememberChoice => 'Remember my choice';

  @override
  String get confirmNewSession => 'Confirm a new session';

  @override
  String get resumeSessionTitle => 'Resume the previous session?';

  @override
  String resumeSessionBody(String time, int count, String profit) {
    return 'The last session started at $time with $count maps and $profit recorded. Keep adding to it, or start a new session?';
  }

  @override
  String get continueSession => 'Continue the previous session';

  @override
  String get showOverlay => 'Show overlay';

  @override
  String get previewPickupNotifications => 'Preview pickup notifications';

  @override
  String get showMain => 'Show main window';

  @override
  String get exitApp => 'Exit';

  @override
  String get updates => 'Updates';

  @override
  String get updateSource => 'Update source';

  @override
  String get updateSourceCdn => 'CDN (recommended)';

  @override
  String get updateSourceNative => 'GitHub direct';

  @override
  String get updateSourceCustom => 'Custom CDN';

  @override
  String updateCdnHint(String url) {
    return 'Checks and downloads through $url';
  }

  @override
  String get customUpdateCdn => 'CDN prefix';

  @override
  String get customUpdateCdnHint => 'For example: https://gh-proxy.org/';

  @override
  String get save => 'Save';

  @override
  String currentVersion(String version) {
    return 'Current version $version';
  }

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkingForUpdates => 'Checking GitHub for updates...';

  @override
  String get upToDate => 'You are using the latest release.';

  @override
  String updateAvailable(String version) {
    return 'Version $version is available.';
  }

  @override
  String get downloadAndInstall => 'Download and install';

  @override
  String get forceOverwriteUpdate => 'Force overwrite update';

  @override
  String get forceOverwriteUpdateHint =>
      'Downloads and reinstalls the latest release even when its version matches the current app. Intended for updater testing.';

  @override
  String get updateDialogTitle => 'Update available';

  @override
  String updateDialogBody(String version) {
    return 'Version $version is available. Download and install it now? The app will close and restart automatically.';
  }

  @override
  String get later => 'Later';

  @override
  String downloadingUpdate(int percent) {
    return 'Downloading update... $percent%';
  }

  @override
  String get installingUpdate =>
      'Installing update; the app will restart shortly...';

  @override
  String updateCheckFailed(String message) {
    return 'Update failed: $message';
  }

  @override
  String get offsetSettings => 'Memory offsets';

  @override
  String get testOffsets => 'Test offsets';

  @override
  String get apply => 'Apply';

  @override
  String get restoreDefaults => 'Restore defaults';

  @override
  String get copy => 'Copy';

  @override
  String get playerInventory => 'Player and inventory';

  @override
  String get entity => 'Entity';

  @override
  String get components => 'Components';

  @override
  String get itemOffsets => 'Items';

  @override
  String get serverDataOffset => 'Server data player vector';

  @override
  String get playerInventoriesOffset => 'Player inventories vector';

  @override
  String get inventoryStride => 'Inventory array stride';

  @override
  String get inventoryIdOffset => 'Inventory array ID';

  @override
  String get inventoryPointerOffset => 'Inventory array pointer';

  @override
  String get inventorySizeOffset => 'Inventory size';

  @override
  String get inventoryItemsOffset => 'Inventory item list';

  @override
  String get inventoryItemPointerOffset => 'Inventory item pointer';

  @override
  String get mainInventoryId => 'Main inventory ID';

  @override
  String get entityDetailsPointerOffset => 'Entity details pointer';

  @override
  String get entityNameOffset => 'Entity name';

  @override
  String get entityComponentListOffset => 'Entity component list';

  @override
  String get entityComponentLookupOffset => 'Entity component lookup';

  @override
  String get componentBucketOffset => 'Component lookup bucket';

  @override
  String get componentNameStride => 'Component name stride';

  @override
  String get stackCountOffset => 'Stack count';

  @override
  String get modsRarityOffset => 'Item rarity';

  @override
  String get renderArtOffset => 'Render art';

  @override
  String get baseNameRowOffset => 'Display-name row';

  @override
  String get baseNameOffset => 'Display name';

  @override
  String get pendingValidation => 'Pending validation';

  @override
  String get validationPassed => 'Validation passed';

  @override
  String get validationFailed => 'Validation failed';

  @override
  String get connected => 'Connected';

  @override
  String get waitingForGame => 'Waiting for game';

  @override
  String get safeZone => 'Safe zone';

  @override
  String get trackingActive => 'Tracking';

  @override
  String get loading => 'Loading';

  @override
  String get retry => 'Retry';

  @override
  String get startupWarningTitle => 'Administrator access required';

  @override
  String get startupWarningBody =>
      'Loot tracking reads the running game process. Launch only when you understand and accept the game publisher\'s rules and associated risk.';

  @override
  String get acknowledge => 'Continue';

  @override
  String acknowledgeIn(int seconds) {
    return 'Continue in ${seconds}s';
  }

  @override
  String mapLevel(int level) {
    return 'Area level $level';
  }

  @override
  String itemsCount(int count) {
    return '$count items';
  }
}
