import 'dart:convert';
import 'dart:io';

const poe2SteamAppId = 2694490;

/// Reads the same live Steam player-count data represented by SteamDB's charts.
///
/// Steam exposes this small endpoint without a key, which is a more stable application integration
/// point than scraping SteamDB's rendered chart page. SteamDB remains useful for the complete
/// history, while this service only needs the current number.
class SteamStatsService {
  SteamStatsService({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<int> currentPlayers() async {
    final request = await _client.getUrl(
      Uri.https(
        'api.steampowered.com',
        '/ISteamUserStats/GetNumberOfCurrentPlayers/v1/',
        {'appid': '$poe2SteamAppId'},
      ),
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'POE2LootTracker');
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Steam player count failed (HTTP ${response.statusCode}).',
      );
    }
    return parseCurrentPlayers(body);
  }

  void close() => _client.close(force: true);
}

int parseCurrentPlayers(String body) {
  final value = jsonDecode(body);
  final response = value is Map ? value['response'] : null;
  final count = response is Map ? response['player_count'] : null;
  if (count is! num || count < 0) {
    throw const FormatException('Steam returned an invalid player count.');
  }
  return count.toInt();
}
