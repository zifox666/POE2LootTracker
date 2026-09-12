import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'POE2 LootTracker'**
  String get appTitle;

  /// No description provided for @lootStats.
  ///
  /// In en, this message translates to:
  /// **'Loot statistics'**
  String get lootStats;

  /// No description provided for @mapLog.
  ///
  /// In en, this message translates to:
  /// **'Map log'**
  String get mapLog;

  /// No description provided for @cost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get cost;

  /// No description provided for @costSettings.
  ///
  /// In en, this message translates to:
  /// **'Cost settings'**
  String get costSettings;

  /// No description provided for @costSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Associate each cost with any number of maps. Map matching checks Simplified Chinese, Traditional Chinese, and English names; unmatched maps use the default cost.'**
  String get costSettingsHint;

  /// No description provided for @addCostPreset.
  ///
  /// In en, this message translates to:
  /// **'Add cost'**
  String get addCostPreset;

  /// No description provided for @editCostPreset.
  ///
  /// In en, this message translates to:
  /// **'Edit cost'**
  String get editCostPreset;

  /// No description provided for @deleteCostPreset.
  ///
  /// In en, this message translates to:
  /// **'Delete cost'**
  String get deleteCostPreset;

  /// No description provided for @deleteCostPresetBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This does not change historical map costs.'**
  String deleteCostPresetBody(String name);

  /// No description provided for @noCostPresets.
  ///
  /// In en, this message translates to:
  /// **'No cost presets yet'**
  String get noCostPresets;

  /// No description provided for @costName.
  ///
  /// In en, this message translates to:
  /// **'Cost name'**
  String get costName;

  /// No description provided for @costPrice.
  ///
  /// In en, this message translates to:
  /// **'Cost price'**
  String get costPrice;

  /// No description provided for @optionalMapName.
  ///
  /// In en, this message translates to:
  /// **'Map name (optional)'**
  String get optionalMapName;

  /// No description provided for @optionalMapNameHint.
  ///
  /// In en, this message translates to:
  /// **'Exact map name for automatic selection'**
  String get optionalMapNameHint;

  /// No description provided for @mapNames.
  ///
  /// In en, this message translates to:
  /// **'Maps'**
  String get mapNames;

  /// No description provided for @mapNamesHint.
  ///
  /// In en, this message translates to:
  /// **'Each selected map is matched by its Simplified Chinese, Traditional Chinese, and English area names.'**
  String get mapNamesHint;

  /// No description provided for @chooseMaps.
  ///
  /// In en, this message translates to:
  /// **'Choose maps'**
  String get chooseMaps;

  /// No description provided for @searchMaps.
  ///
  /// In en, this message translates to:
  /// **'Search maps in any language'**
  String get searchMaps;

  /// No description provided for @noMapsSelected.
  ///
  /// In en, this message translates to:
  /// **'No maps selected'**
  String get noMapsSelected;

  /// No description provided for @defaultCost.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultCost;

  /// No description provided for @defaultCostHint.
  ///
  /// In en, this message translates to:
  /// **'Used when the entered map is not assigned to another cost.'**
  String get defaultCostHint;

  /// No description provided for @manualOnly.
  ///
  /// In en, this message translates to:
  /// **'No assigned maps · available for manual switching'**
  String get manualOnly;

  /// No description provided for @invalidCostPreset.
  ///
  /// In en, this message translates to:
  /// **'Enter a cost name and a price greater than zero.'**
  String get invalidCostPreset;

  /// No description provided for @activeCost.
  ///
  /// In en, this message translates to:
  /// **'Active cost'**
  String get activeCost;

  /// No description provided for @noCostPreset.
  ///
  /// In en, this message translates to:
  /// **'No cost'**
  String get noCostPreset;

  /// No description provided for @manualCostFallback.
  ///
  /// In en, this message translates to:
  /// **'Manual fallback for maps without a match'**
  String get manualCostFallback;

  /// No description provided for @mapMatch.
  ///
  /// In en, this message translates to:
  /// **'Auto: {name}'**
  String mapMatch(String name);

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @profit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profit;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @noMaps.
  ///
  /// In en, this message translates to:
  /// **'No maps recorded yet'**
  String get noMaps;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageOf(int current, int total);

  /// No description provided for @marketPrices.
  ///
  /// In en, this message translates to:
  /// **'Market prices'**
  String get marketPrices;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @searchSettings.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get searchSettings;

  /// No description provided for @settingsSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get settingsSearchResults;

  /// No description provided for @noSettingsFound.
  ///
  /// In en, this message translates to:
  /// **'No matching settings'**
  String get noSettingsFound;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalSettings;

  /// No description provided for @overlaySettings.
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get overlaySettings;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationSettings;

  /// No description provided for @trackingSettings.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get trackingSettings;

  /// No description provided for @dataSettings.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get dataSettings;

  /// No description provided for @updateSettings.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updateSettings;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedSettings;

  /// No description provided for @gameSettings.
  ///
  /// In en, this message translates to:
  /// **'Game and prices'**
  String get gameSettings;

  /// No description provided for @applicationBehavior.
  ///
  /// In en, this message translates to:
  /// **'Application behavior'**
  String get applicationBehavior;

  /// No description provided for @windowBehavior.
  ///
  /// In en, this message translates to:
  /// **'Window behavior'**
  String get windowBehavior;

  /// No description provided for @appearanceSettings.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSettings;

  /// No description provided for @typographySettings.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get typographySettings;

  /// No description provided for @currentSession.
  ///
  /// In en, this message translates to:
  /// **'Current session'**
  String get currentSession;

  /// No description provided for @selectSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get selectSession;

  /// No description provided for @selectMap.
  ///
  /// In en, this message translates to:
  /// **'Map run'**
  String get selectMap;

  /// No description provided for @allMaps.
  ///
  /// In en, this message translates to:
  /// **'All maps'**
  String get allMaps;

  /// No description provided for @currentMap.
  ///
  /// In en, this message translates to:
  /// **'Current map'**
  String get currentMap;

  /// No description provided for @totalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total revenue'**
  String get totalRevenue;

  /// No description provided for @revenuePerHour.
  ///
  /// In en, this message translates to:
  /// **'Revenue per hour'**
  String get revenuePerHour;

  /// No description provided for @mapCount.
  ///
  /// In en, this message translates to:
  /// **'Maps'**
  String get mapCount;

  /// No description provided for @sessionTime.
  ///
  /// In en, this message translates to:
  /// **'Session time'**
  String get sessionTime;

  /// No description provided for @mapTime.
  ///
  /// In en, this message translates to:
  /// **'Map time'**
  String get mapTime;

  /// No description provided for @totalMapTime.
  ///
  /// In en, this message translates to:
  /// **'Total map time'**
  String get totalMapTime;

  /// No description provided for @efficiency.
  ///
  /// In en, this message translates to:
  /// **'Efficiency'**
  String get efficiency;

  /// No description provided for @monsterKills.
  ///
  /// In en, this message translates to:
  /// **'Monster kills'**
  String get monsterKills;

  /// No description provided for @totalKills.
  ///
  /// In en, this message translates to:
  /// **'Total kills'**
  String get totalKills;

  /// No description provided for @averageMapTime.
  ///
  /// In en, this message translates to:
  /// **'Average map time'**
  String get averageMapTime;

  /// No description provided for @averageRevenue.
  ///
  /// In en, this message translates to:
  /// **'Average per map'**
  String get averageRevenue;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @magic.
  ///
  /// In en, this message translates to:
  /// **'Magic'**
  String get magic;

  /// No description provided for @rare.
  ///
  /// In en, this message translates to:
  /// **'Rare'**
  String get rare;

  /// No description provided for @unique.
  ///
  /// In en, this message translates to:
  /// **'Unique'**
  String get unique;

  /// No description provided for @kills.
  ///
  /// In en, this message translates to:
  /// **'Monster kills'**
  String get kills;

  /// No description provided for @lootDetails.
  ///
  /// In en, this message translates to:
  /// **'Loot details'**
  String get lootDetails;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get item;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @unitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get unitPrice;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @noLoot.
  ///
  /// In en, this message translates to:
  /// **'No loot recorded for this selection'**
  String get noLoot;

  /// No description provided for @pickups.
  ///
  /// In en, this message translates to:
  /// **'Pickups'**
  String get pickups;

  /// No description provided for @pickupNotifications.
  ///
  /// In en, this message translates to:
  /// **'Pickup notifications'**
  String get pickupNotifications;

  /// No description provided for @maxVisiblePickups.
  ///
  /// In en, this message translates to:
  /// **'Maximum visible pickups'**
  String get maxVisiblePickups;

  /// No description provided for @pickupDisplayDuration.
  ///
  /// In en, this message translates to:
  /// **'Display duration'**
  String get pickupDisplayDuration;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get seconds;

  /// No description provided for @costs.
  ///
  /// In en, this message translates to:
  /// **'Costs'**
  String get costs;

  /// No description provided for @noCosts.
  ///
  /// In en, this message translates to:
  /// **'No costs yet'**
  String get noCosts;

  /// No description provided for @waitingForPickups.
  ///
  /// In en, this message translates to:
  /// **'Waiting for pickups'**
  String get waitingForPickups;

  /// No description provided for @noPrices.
  ///
  /// In en, this message translates to:
  /// **'No market prices match the current filter'**
  String get noPrices;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategories;

  /// No description provided for @searchPrices.
  ///
  /// In en, this message translates to:
  /// **'Search items'**
  String get searchPrices;

  /// No description provided for @league.
  ///
  /// In en, this message translates to:
  /// **'League'**
  String get league;

  /// No description provided for @season.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get season;

  /// No description provided for @onlinePlayers.
  ///
  /// In en, this message translates to:
  /// **'Steam players online'**
  String get onlinePlayers;

  /// No description provided for @syncStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync status'**
  String get syncStatus;

  /// No description provided for @syncIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get syncIdle;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get syncing;

  /// No description provided for @syncReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get syncReady;

  /// No description provided for @syncError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get syncError;

  /// No description provided for @divineRate.
  ///
  /// In en, this message translates to:
  /// **'Divine rate'**
  String get divineRate;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get lastUpdated;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @manualPrice.
  ///
  /// In en, this message translates to:
  /// **'Manual price'**
  String get manualPrice;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @overlayMode.
  ///
  /// In en, this message translates to:
  /// **'Overlay mode'**
  String get overlayMode;

  /// No description provided for @floating.
  ///
  /// In en, this message translates to:
  /// **'Floating'**
  String get floating;

  /// No description provided for @minimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get minimal;

  /// No description provided for @windowAppearance.
  ///
  /// In en, this message translates to:
  /// **'Window appearance'**
  String get windowAppearance;

  /// No description provided for @framelessWindow.
  ///
  /// In en, this message translates to:
  /// **'Frameless'**
  String get framelessWindow;

  /// No description provided for @normalWindow.
  ///
  /// In en, this message translates to:
  /// **'normalWindow'**
  String get normalWindow;

  /// No description provided for @alwaysOnTop.
  ///
  /// In en, this message translates to:
  /// **'Always on top'**
  String get alwaysOnTop;

  /// No description provided for @clickThrough.
  ///
  /// In en, this message translates to:
  /// **'Click through'**
  String get clickThrough;

  /// No description provided for @textOpacity.
  ///
  /// In en, this message translates to:
  /// **'Text opacity'**
  String get textOpacity;

  /// No description provided for @backgroundOpacity.
  ///
  /// In en, this message translates to:
  /// **'Background opacity'**
  String get backgroundOpacity;

  /// No description provided for @frostedGlass.
  ///
  /// In en, this message translates to:
  /// **'Frosted glass (experimental)'**
  String get frostedGlass;

  /// No description provided for @frostedGlassGlow.
  ///
  /// In en, this message translates to:
  /// **'Glow intensity'**
  String get frostedGlassGlow;

  /// No description provided for @frostedGlassOpacity.
  ///
  /// In en, this message translates to:
  /// **'Glass background opacity'**
  String get frostedGlassOpacity;

  /// No description provided for @frostedGlassBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur intensity'**
  String get frostedGlassBlur;

  /// No description provided for @databaseManagement.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get databaseManagement;

  /// No description provided for @resetDatabase.
  ///
  /// In en, this message translates to:
  /// **'Reset database'**
  String get resetDatabase;

  /// No description provided for @resetDatabaseHint.
  ///
  /// In en, this message translates to:
  /// **'Delete all tracking history, settings, and market cache stored in the database, then restart the app.'**
  String get resetDatabaseHint;

  /// No description provided for @resetDatabaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset database?'**
  String get resetDatabaseTitle;

  /// No description provided for @resetDatabaseBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes all tracking history, settings, and market cache stored in the database, then restarts the app. This cannot be undone.'**
  String get resetDatabaseBody;

  /// No description provided for @databaseCorruptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Database corrupted'**
  String get databaseCorruptedTitle;

  /// No description provided for @databaseCorruptedBody.
  ///
  /// In en, this message translates to:
  /// **'The tracking service cannot start because the database is corrupted. Delete the entire database and restart the app? All tracking history and settings will be permanently lost.'**
  String get databaseCorruptedBody;

  /// No description provided for @deleteDatabaseAndRestart.
  ///
  /// In en, this message translates to:
  /// **'Delete and restart'**
  String get deleteDatabaseAndRestart;

  /// No description provided for @transparentOverlayBorder.
  ///
  /// In en, this message translates to:
  /// **'Transparent overlay border'**
  String get transparentOverlayBorder;

  /// No description provided for @floatingFontSize.
  ///
  /// In en, this message translates to:
  /// **'Floating overlay font size'**
  String get floatingFontSize;

  /// No description provided for @minimalFontSize.
  ///
  /// In en, this message translates to:
  /// **'Minimal mode font size'**
  String get minimalFontSize;

  /// No description provided for @mainFontSize.
  ///
  /// In en, this message translates to:
  /// **'Main interface font size'**
  String get mainFontSize;

  /// No description provided for @priceRefresh.
  ///
  /// In en, this message translates to:
  /// **'Price refresh interval'**
  String get priceRefresh;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// No description provided for @tracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get tracking;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @newSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get newSession;

  /// No description provided for @confirmNewSessionBody.
  ///
  /// In en, this message translates to:
  /// **'The current session will be closed and a new one started.'**
  String get confirmNewSessionBody;

  /// No description provided for @closeWindowTitle.
  ///
  /// In en, this message translates to:
  /// **'Close the main window'**
  String get closeWindowTitle;

  /// No description provided for @closeWindowBody.
  ///
  /// In en, this message translates to:
  /// **'Quit the tracker, or keep it running in the small window?'**
  String get closeWindowBody;

  /// No description provided for @minimizeToOverlay.
  ///
  /// In en, this message translates to:
  /// **'Minimize to the small window'**
  String get minimizeToOverlay;

  /// No description provided for @closeBehavior.
  ///
  /// In en, this message translates to:
  /// **'Closing the main window'**
  String get closeBehavior;

  /// No description provided for @askEveryTime.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get askEveryTime;

  /// No description provided for @rememberChoice.
  ///
  /// In en, this message translates to:
  /// **'Remember my choice'**
  String get rememberChoice;

  /// No description provided for @confirmNewSession.
  ///
  /// In en, this message translates to:
  /// **'Confirm a new session'**
  String get confirmNewSession;

  /// No description provided for @resumeSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Resume the previous session?'**
  String get resumeSessionTitle;

  /// No description provided for @resumeSessionBody.
  ///
  /// In en, this message translates to:
  /// **'The last session started at {time} with {count} maps and {profit} recorded. Keep adding to it, or start a new session?'**
  String resumeSessionBody(String time, int count, String profit);

  /// No description provided for @continueSession.
  ///
  /// In en, this message translates to:
  /// **'Continue the previous session'**
  String get continueSession;

  /// No description provided for @showOverlay.
  ///
  /// In en, this message translates to:
  /// **'Show overlay'**
  String get showOverlay;

  /// No description provided for @previewPickupNotifications.
  ///
  /// In en, this message translates to:
  /// **'Preview pickup notifications'**
  String get previewPickupNotifications;

  /// No description provided for @showMain.
  ///
  /// In en, this message translates to:
  /// **'Show main window'**
  String get showMain;

  /// No description provided for @exitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitApp;

  /// No description provided for @updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// No description provided for @updateSource.
  ///
  /// In en, this message translates to:
  /// **'Update source'**
  String get updateSource;

  /// No description provided for @updateSourceCdn.
  ///
  /// In en, this message translates to:
  /// **'CDN (recommended)'**
  String get updateSourceCdn;

  /// No description provided for @updateSourceNative.
  ///
  /// In en, this message translates to:
  /// **'GitHub direct'**
  String get updateSourceNative;

  /// No description provided for @updateSourceCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom CDN'**
  String get updateSourceCustom;

  /// No description provided for @updateCdnHint.
  ///
  /// In en, this message translates to:
  /// **'Checks and downloads through {url}'**
  String updateCdnHint(String url);

  /// No description provided for @customUpdateCdn.
  ///
  /// In en, this message translates to:
  /// **'CDN prefix'**
  String get customUpdateCdn;

  /// No description provided for @customUpdateCdnHint.
  ///
  /// In en, this message translates to:
  /// **'For example: https://gh-proxy.org/'**
  String get customUpdateCdnHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @currentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version {version}'**
  String currentVersion(String version);

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking GitHub for updates...'**
  String get checkingForUpdates;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You are using the latest release.'**
  String get upToDate;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available.'**
  String updateAvailable(String version);

  /// No description provided for @downloadAndInstall.
  ///
  /// In en, this message translates to:
  /// **'Download and install'**
  String get downloadAndInstall;

  /// No description provided for @forceOverwriteUpdate.
  ///
  /// In en, this message translates to:
  /// **'Force overwrite update'**
  String get forceOverwriteUpdate;

  /// No description provided for @forceOverwriteUpdateHint.
  ///
  /// In en, this message translates to:
  /// **'Downloads and reinstalls the latest release even when its version matches the current app. Intended for updater testing.'**
  String get forceOverwriteUpdateHint;

  /// No description provided for @openLatestRelease.
  ///
  /// In en, this message translates to:
  /// **'Open latest release'**
  String get openLatestRelease;

  /// No description provided for @openReleasePage.
  ///
  /// In en, this message translates to:
  /// **'Open download page'**
  String get openReleasePage;

  /// No description provided for @portableUpdateHint.
  ///
  /// In en, this message translates to:
  /// **'Portable editions open the latest GitHub Release so you can download and replace the files manually.'**
  String get portableUpdateHint;

  /// No description provided for @updateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateDialogTitle;

  /// No description provided for @updateDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available. Download and open the installer now?'**
  String updateDialogBody(String version);

  /// No description provided for @portableUpdateDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available. Open its GitHub Release page to download the portable edition?'**
  String portableUpdateDialogBody(String version);

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @downloadingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Downloading update... {percent}%'**
  String downloadingUpdate(int percent);

  /// No description provided for @installingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Opening the update installer...'**
  String get installingUpdate;

  /// No description provided for @installerOpened.
  ///
  /// In en, this message translates to:
  /// **'The installer is open. Follow it to complete the update.'**
  String get installerOpened;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {message}'**
  String updateCheckFailed(String message);

  /// No description provided for @offsetSettings.
  ///
  /// In en, this message translates to:
  /// **'Memory offsets'**
  String get offsetSettings;

  /// No description provided for @testOffsets.
  ///
  /// In en, this message translates to:
  /// **'Test offsets'**
  String get testOffsets;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @restoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get restoreDefaults;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @playerInventory.
  ///
  /// In en, this message translates to:
  /// **'Player and inventory'**
  String get playerInventory;

  /// No description provided for @entity.
  ///
  /// In en, this message translates to:
  /// **'Entity'**
  String get entity;

  /// No description provided for @components.
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get components;

  /// No description provided for @itemOffsets.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemOffsets;

  /// No description provided for @serverDataOffset.
  ///
  /// In en, this message translates to:
  /// **'Server data player vector'**
  String get serverDataOffset;

  /// No description provided for @playerInventoriesOffset.
  ///
  /// In en, this message translates to:
  /// **'Player inventories vector'**
  String get playerInventoriesOffset;

  /// No description provided for @inventoryStride.
  ///
  /// In en, this message translates to:
  /// **'Inventory array stride'**
  String get inventoryStride;

  /// No description provided for @inventoryIdOffset.
  ///
  /// In en, this message translates to:
  /// **'Inventory array ID'**
  String get inventoryIdOffset;

  /// No description provided for @inventoryPointerOffset.
  ///
  /// In en, this message translates to:
  /// **'Inventory array pointer'**
  String get inventoryPointerOffset;

  /// No description provided for @inventorySizeOffset.
  ///
  /// In en, this message translates to:
  /// **'Inventory size'**
  String get inventorySizeOffset;

  /// No description provided for @inventoryItemsOffset.
  ///
  /// In en, this message translates to:
  /// **'Inventory item list'**
  String get inventoryItemsOffset;

  /// No description provided for @inventoryItemPointerOffset.
  ///
  /// In en, this message translates to:
  /// **'Inventory item pointer'**
  String get inventoryItemPointerOffset;

  /// No description provided for @mainInventoryId.
  ///
  /// In en, this message translates to:
  /// **'Main inventory ID'**
  String get mainInventoryId;

  /// No description provided for @entityDetailsPointerOffset.
  ///
  /// In en, this message translates to:
  /// **'Entity details pointer'**
  String get entityDetailsPointerOffset;

  /// No description provided for @entityNameOffset.
  ///
  /// In en, this message translates to:
  /// **'Entity name'**
  String get entityNameOffset;

  /// No description provided for @entityComponentListOffset.
  ///
  /// In en, this message translates to:
  /// **'Entity component list'**
  String get entityComponentListOffset;

  /// No description provided for @entityComponentLookupOffset.
  ///
  /// In en, this message translates to:
  /// **'Entity component lookup'**
  String get entityComponentLookupOffset;

  /// No description provided for @componentBucketOffset.
  ///
  /// In en, this message translates to:
  /// **'Component lookup bucket'**
  String get componentBucketOffset;

  /// No description provided for @componentNameStride.
  ///
  /// In en, this message translates to:
  /// **'Component name stride'**
  String get componentNameStride;

  /// No description provided for @stackCountOffset.
  ///
  /// In en, this message translates to:
  /// **'Stack count'**
  String get stackCountOffset;

  /// No description provided for @modsRarityOffset.
  ///
  /// In en, this message translates to:
  /// **'Item rarity'**
  String get modsRarityOffset;

  /// No description provided for @renderArtOffset.
  ///
  /// In en, this message translates to:
  /// **'Render art'**
  String get renderArtOffset;

  /// No description provided for @baseNameRowOffset.
  ///
  /// In en, this message translates to:
  /// **'Display-name row'**
  String get baseNameRowOffset;

  /// No description provided for @baseNameOffset.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get baseNameOffset;

  /// No description provided for @pendingValidation.
  ///
  /// In en, this message translates to:
  /// **'Pending validation'**
  String get pendingValidation;

  /// No description provided for @validationPassed.
  ///
  /// In en, this message translates to:
  /// **'Validation passed'**
  String get validationPassed;

  /// No description provided for @validationFailed.
  ///
  /// In en, this message translates to:
  /// **'Validation failed'**
  String get validationFailed;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @waitingForGame.
  ///
  /// In en, this message translates to:
  /// **'Waiting for game'**
  String get waitingForGame;

  /// No description provided for @safeZone.
  ///
  /// In en, this message translates to:
  /// **'Safe zone'**
  String get safeZone;

  /// No description provided for @trackingActive.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get trackingActive;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @startupWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Administrator access required'**
  String get startupWarningTitle;

  /// No description provided for @startupWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Loot tracking reads the running game process. Launch only when you understand and accept the game publisher\'s rules and associated risk.'**
  String get startupWarningBody;

  /// No description provided for @acknowledge.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get acknowledge;

  /// No description provided for @acknowledgeIn.
  ///
  /// In en, this message translates to:
  /// **'Continue in {seconds}s'**
  String acknowledgeIn(int seconds);

  /// No description provided for @mapLevel.
  ///
  /// In en, this message translates to:
  /// **'Area level {level}'**
  String mapLevel(int level);

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemsCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
