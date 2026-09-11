class LootEntry {
  const LootEntry({
    required this.key,
    required this.name,
    required this.count,
    required this.unitEx,
    required this.totalEx,
    required this.priced,
    required this.iconUrl,
  });
  final String key;
  final String name;
  final int count;
  final double unitEx;
  final double totalEx;
  final bool priced;
  final String iconUrl;

  factory LootEntry.fromJson(Map<String, dynamic> json) => LootEntry(
    key: json['key'] as String? ?? '',
    name: json['name'] as String? ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
    unitEx: (json['unitEx'] as num?)?.toDouble() ?? 0,
    totalEx: (json['totalEx'] as num?)?.toDouble() ?? 0,
    priced: json['priced'] as bool? ?? false,
    iconUrl: json['iconUrl'] as String? ?? '',
  );
}

class RecentPickupEntry extends LootEntry {
  const RecentPickupEntry({
    required super.key,
    required super.name,
    required super.count,
    required super.unitEx,
    required super.totalEx,
    required super.priced,
    required super.iconUrl,
    required this.pickedUpUtc,
  });

  final DateTime? pickedUpUtc;

  factory RecentPickupEntry.fromJson(Map<String, dynamic> json) =>
      RecentPickupEntry(
        key: json['key'] as String? ?? '',
        name: json['name'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        unitEx: (json['unitEx'] as num?)?.toDouble() ?? 0,
        totalEx: (json['totalEx'] as num?)?.toDouble() ?? 0,
        priced: json['priced'] as bool? ?? false,
        iconUrl: json['iconUrl'] as String? ?? '',
        pickedUpUtc: DateTime.tryParse(json['pickedUpUtc'] as String? ?? ''),
      );
}

class MapSummary {
  const MapSummary({
    required this.id,
    required this.name,
    required this.areaLevel,
    required this.activeTime,
    required this.profitEx,
    required this.costEx,
    required this.lootTypes,
    required this.kills,
    required this.active,
  });
  final String id;
  final String name;
  final int areaLevel;
  final Duration activeTime;
  final double profitEx;

  /// Positive value of what the map consumed, tracked next to [profitEx] (which is net) so the map
  /// log can show spending and income in separate columns.
  final double costEx;
  final int lootTypes;
  final List<int> kills;
  final bool active;

  /// Tolerant of both payload shapes on purpose: `snapshot.maps` carries `activeTime` plus the live
  /// `active` flag, while a historical session's rows from `listMaps` carry `activeMs` instead and
  /// have neither `active` nor (for rows written before it existed) a cost.
  factory MapSummary.fromJson(Map<String, dynamic> json) => MapSummary(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    areaLevel: (json['areaLevel'] as num?)?.toInt() ?? 0,
    activeTime: parseDuration(json['activeTime'] ?? json['activeMs']),
    profitEx: (json['profitEx'] as num?)?.toDouble() ?? 0,
    costEx: (json['costEx'] as num?)?.toDouble() ?? 0,
    lootTypes: (json['lootTypes'] as num?)?.toInt() ?? 0,
    kills: intList(json['kills']),
    active: json['active'] as bool? ?? false,
  );
}

class TrackerSnapshot {
  const TrackerSnapshot({
    required this.activeSessionId,
    required this.resumedSession,
    required this.sessionStartedUtc,
    required this.gameConnected,
    required this.inMap,
    required this.trackingPaused,
    required this.status,
    required this.mapName,
    required this.currentCostPresetId,
    required this.currentCostName,
    required this.currentCostEx,
    required this.mapTime,
    required this.sessionTime,
    required this.activeTime,
    required this.currentProfitEx,
    required this.totalProfitEx,
    required this.perHourEx,
    required this.divineRate,
    required this.mapCount,
    required this.kills,
    required this.loot,
    required this.recentPickups,
    required this.maps,
    required this.priceUpdatedUtc,
    required this.priceStatus,
    required this.priceError,
  });
  final String activeSessionId;

  /// True when the host restored a session from a previous run, which is what the startup prompt
  /// asks about: the alternative is silently appending to a session the user thought was finished.
  final bool resumedSession;
  final DateTime? sessionStartedUtc;
  final bool gameConnected;
  final bool inMap;
  final bool trackingPaused;
  final String status;
  final String mapName;
  final String currentCostPresetId;
  final String currentCostName;
  final double currentCostEx;
  final Duration mapTime;
  final Duration sessionTime;

  /// Total time spent inside maps across the session. Average map time divides this, not
  /// [sessionTime] -- time spent in town is not map time.
  final Duration activeTime;
  final double currentProfitEx;
  final double totalProfitEx;
  final double perHourEx;
  final double divineRate;
  final int mapCount;
  final List<int> kills;
  final List<LootEntry> loot;
  final List<RecentPickupEntry> recentPickups;
  final List<MapSummary> maps;
  final DateTime? priceUpdatedUtc;
  final String priceStatus;
  final String priceError;

  double get averageProfitEx => mapCount > 0 ? totalProfitEx / mapCount : 0;

  /// In-map time per map. Deliberately [activeTime] and not [sessionTime]: the session clock also
  /// covers time spent in town, which would inflate the average.
  Duration get averageMapTime => mapCount > 0
      ? Duration(milliseconds: activeTime.inMilliseconds ~/ mapCount)
      : Duration.zero;

  factory TrackerSnapshot.fromJson(Map<String, dynamic> json) =>
      TrackerSnapshot(
        activeSessionId: json['activeSessionId'] as String? ?? '',
        resumedSession: json['resumedSession'] as bool? ?? false,
        sessionStartedUtc: DateTime.tryParse(
          json['sessionStartedUtc'] as String? ?? '',
        ),
        gameConnected: json['gameConnected'] as bool? ?? false,
        inMap: json['inMap'] as bool? ?? false,
        trackingPaused: json['trackingPaused'] as bool? ?? false,
        status: json['status'] as String? ?? '',
        mapName: json['mapName'] as String? ?? '—',
        currentCostPresetId: json['currentCostPresetId'] as String? ?? '',
        currentCostName: json['currentCostName'] as String? ?? '',
        currentCostEx: (json['currentCostEx'] as num?)?.toDouble() ?? 0,
        mapTime: parseDuration(json['mapTime']),
        sessionTime: parseDuration(json['sessionTime']),
        activeTime: parseDuration(json['activeTime']),
        currentProfitEx: (json['currentProfitEx'] as num?)?.toDouble() ?? 0,
        totalProfitEx: (json['totalProfitEx'] as num?)?.toDouble() ?? 0,
        perHourEx: (json['perHourEx'] as num?)?.toDouble() ?? 0,
        divineRate: (json['divineRate'] as num?)?.toDouble() ?? 0,
        mapCount: (json['mapCount'] as num?)?.toInt() ?? 0,
        kills: intList(json['kills']),
        loot: listOfMaps(json['loot']).map(LootEntry.fromJson).toList(),
        recentPickups: listOfMaps(
          json['recentPickups'],
        ).map(RecentPickupEntry.fromJson).toList(),
        maps: listOfMaps(json['maps']).map(MapSummary.fromJson).toList(),
        priceUpdatedUtc: DateTime.tryParse(
          json['priceUpdatedUtc'] as String? ?? '',
        ),
        priceStatus: (json['priceStatus'] ?? 'idle').toString().toLowerCase(),
        priceError: json['priceError'] as String? ?? '',
      );

  static const empty = TrackerSnapshot(
    activeSessionId: '',
    resumedSession: false,
    sessionStartedUtc: null,
    gameConnected: false,
    inMap: false,
    trackingPaused: false,
    status: '',
    mapName: '—',
    currentCostPresetId: '',
    currentCostName: '',
    currentCostEx: 0,
    mapTime: Duration.zero,
    sessionTime: Duration.zero,
    activeTime: Duration.zero,
    currentProfitEx: 0,
    totalProfitEx: 0,
    perHourEx: 0,
    divineRate: 0,
    mapCount: 0,
    kills: [0, 0, 0, 0],
    loot: [],
    recentPickups: [],
    maps: [],
    priceUpdatedUtc: null,
    priceStatus: 'idle',
    priceError: '',
  );
}

class SessionRow {
  SessionRow.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String? ?? '',
      startedUtc = DateTime.tryParse(json['startedUtc'] as String? ?? ''),
      status = json['status'] as String? ?? '',
      league = json['league'] as String? ?? '',
      mapCount = (json['mapCount'] as num?)?.toInt() ?? 0,
      activeMs = (json['activeMs'] as num?)?.toInt() ?? 0,
      profitEx = (json['profitEx'] as num?)?.toDouble() ?? 0;
  final String id;
  final DateTime? startedUtc;
  final String status;
  final String league;
  final int mapCount;
  final int activeMs;
  final double profitEx;
}

class MarketPrice {
  MarketPrice.fromJson(Map<String, dynamic> json)
    : key = json['key'] as String? ?? '',
      name = json['name'] as String? ?? '',
      priceEx = (json['priceEx'] as num?)?.toDouble() ?? 0,
      manualPriceEx = (json['manualPriceEx'] as num?)?.toDouble(),
      iconUrl = json['iconUrl'] as String? ?? '',
      category = json['category'] as String? ?? '',
      fetchedUtc = DateTime.tryParse(json['fetchedUtc'] as String? ?? '');
  final String key;
  final String name;
  final double priceEx;
  final double? manualPriceEx;
  final String iconUrl;

  /// The poe.ninja economy section this row was fetched under ("Currency", "Runes", ...). Empty
  /// when unknown, which is what a price cache written before categories existed looks like.
  final String category;
  final DateTime? fetchedUtc;
}

class CostPreset {
  const CostPreset({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    this.mapNames = const [],
    this.isDefault = false,
  });

  final String id;
  final String name;
  final double amount;
  final String currency;
  final List<String> mapNames;
  final bool isDefault;

  factory CostPreset.fromJson(Map<String, dynamic> json) {
    final names = <String>{
      if (json['mapNames'] is List)
        for (final value in json['mapNames'] as List)
          if (value.toString().trim().isNotEmpty) value.toString().trim(),
      if ((json['mapName']?.toString().trim() ?? '').isNotEmpty)
        json['mapName'].toString().trim(),
    };
    return CostPreset(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString().toUpperCase() == 'D' ? 'D' : 'E',
      mapNames: names.toList(),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  CostPreset copyWith({bool? isDefault}) => CostPreset(
    id: id,
    name: name,
    amount: amount,
    currency: currency,
    mapNames: mapNames,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'currency': currency,
    'mapNames': mapNames,
    'isDefault': isDefault,
  };
}

List<Map<String, dynamic>> listOfMaps(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((entry) => entry.cast<String, dynamic>())
          .toList()
    : const [];
List<int> intList(dynamic value) {
  final result = value is List
      ? value.map((entry) => (entry as num?)?.toInt() ?? 0).toList()
      : <int>[];
  while (result.length < 4) {
    result.add(0);
  }
  return result.take(4).toList();
}

Duration parseDuration(dynamic value) {
  if (value is num) return Duration(milliseconds: value.toInt());
  final text = value?.toString() ?? '';
  final match = RegExp(
    r'(?:(\d+)\.)?(\d+):(\d+):(\d+)(?:\.(\d+))?',
  ).firstMatch(text);
  if (match == null) return Duration.zero;
  final fraction = (match.group(5) ?? '').padRight(3, '0').substring(0, 3);
  return Duration(
    days: int.parse(match.group(1) ?? '0'),
    hours: int.parse(match.group(2)!),
    minutes: int.parse(match.group(3)!),
    seconds: int.parse(match.group(4)!),
    milliseconds: int.parse(fraction),
  );
}
