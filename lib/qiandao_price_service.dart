import 'dart:convert';
import 'dart:io';

const _compiledQiandaoUrl = String.fromEnvironment('QIANDAO_URL');
const _compiledAdapterToken = String.fromEnvironment('ADAPTER_TOKEN');

class QiandaoPriceService {
  QiandaoPriceService({HttpClient? client, String? baseUrl, String? token})
    : _client = client ?? HttpClient(),
      _baseUrl =
          baseUrl ??
          (_compiledQiandaoUrl.isEmpty
              ? Platform.environment['QIANDAO_URL'] ?? ''
              : _compiledQiandaoUrl),
      _token =
          token ??
          (_compiledAdapterToken.isEmpty
              ? Platform.environment['ADAPTER_TOKEN'] ?? ''
              : _compiledAdapterToken);

  final HttpClient _client;
  final String _baseUrl;
  final String _token;

  bool configured({String? baseUrl, String? token}) =>
      (baseUrl ?? _baseUrl).trim().isNotEmpty &&
      (baseUrl != null || (token ?? _token).isNotEmpty);

  Future<double> divineRmbPrice({String? baseUrl, String? token}) async {
    final effectiveBaseUrl = (baseUrl ?? _baseUrl).trim();
    final effectiveToken = token ?? _token;
    final base = effectiveBaseUrl.endsWith('/')
        ? effectiveBaseUrl.substring(0, effectiveBaseUrl.length - 1)
        : effectiveBaseUrl;
    final uri = Uri.parse('$base/v1/poe2/prices').replace(
      queryParameters: const {
        'tagId': '1707645',
        'leagueId': '3794866',
        'name': '神圣石',
        'offset': '0',
        'limit': '20',
      },
    );
    final request = await _client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (effectiveToken.isNotEmpty) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $effectiveToken',
      );
    }
    request.headers.set(HttpHeaders.userAgentHeader, 'POE2LootTracker');
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Qiandao price failed (HTTP ${response.statusCode}).',
        uri: uri,
      );
    }
    return parseDivineRmbPrice(body);
  }

  void close() => _client.close(force: true);
}

double parseDivineRmbPrice(String body) {
  final envelope = jsonDecode(body);
  final data = envelope is Map ? envelope['data'] : null;
  final items = data is Map ? data['items'] : null;
  if (items is! List) {
    throw const FormatException('Qiandao response has no price items.');
  }
  for (final item in items) {
    if (item is! Map || item['spuName'] != '神圣石') continue;
    final price = item['rmbPrice'];
    if (price is num && price.isFinite && price > 0) return price.toDouble();
  }
  throw const FormatException('Qiandao response has no Divine Orb RMB price.');
}
