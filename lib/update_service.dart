import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _latestReleaseUrl =
    'https://api.github.com/repos/zifox666/POE2LootTracker/releases/latest';
const defaultUpdateCdnPrefix = 'https://gh-proxy.org/';

Uri resolveUpdateUrl(
  Uri githubUrl, {
  required String source,
  String customCdn = '',
}) {
  if (source == 'native') return githubUrl;
  final prefix = switch (source) {
    'cdn' => defaultUpdateCdnPrefix,
    'custom' => customCdn.trim(),
    _ => throw UpdateException('Unsupported update source: $source'),
  };
  final prefixUri = Uri.tryParse(prefix);
  if (prefixUri == null ||
      prefixUri.scheme != 'https' ||
      prefixUri.host.isEmpty) {
    throw const UpdateException(
      'The custom update CDN must be a valid HTTPS URL.',
    );
  }
  final separator = prefix.endsWith('/') ? '' : '/';
  return Uri.parse('$prefix$separator$githubUrl');
}

class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.tag,
    required this.installerUrl,
    required this.checksumUrl,
    required this.releasePage,
    required this.notes,
  });

  final String version;
  final String tag;
  final Uri installerUrl;
  final Uri checksumUrl;
  final Uri releasePage;
  final String notes;
}

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion(this.major, this.minor, this.patch);

  factory SemanticVersion.parse(String text) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(text.trim());
    if (match == null) {
      throw UpdateException('Unsupported release version: $text');
    }
    return SemanticVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(SemanticVersion other) {
    for (final pair in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      final result = pair.$1.compareTo(pair.$2);
      if (result != 0) return result;
    }
    return 0;
  }

  @override
  String toString() => '$major.$minor.$patch';
}

UpdateRelease? parseLatestRelease(
  Map<String, dynamic> json, {
  required String currentVersion,
  bool allowCurrentVersion = false,
}) {
  final tag = json['tag_name']?.toString() ?? '';
  final latest = SemanticVersion.parse(tag);
  final comparison = latest.compareTo(SemanticVersion.parse(currentVersion));
  if (comparison < 0 || (comparison == 0 && !allowCurrentVersion)) {
    return null;
  }

  final installerName = 'POE2LootTracker-$tag-windows-x64-setup.exe';
  final checksumName = '$installerName.sha256';
  Uri? installerUrl;
  Uri? checksumUrl;
  final assets = json['assets'];
  if (assets is List) {
    for (final value in assets) {
      if (value is! Map) continue;
      final asset = value.cast<String, dynamic>();
      final name = asset['name']?.toString();
      final rawUrl = asset['browser_download_url']?.toString() ?? '';
      final url = Uri.tryParse(rawUrl);
      if (url == null || !url.hasScheme) continue;
      if (name == installerName) installerUrl = url;
      if (name == checksumName) checksumUrl = url;
    }
  }
  if (installerUrl == null || checksumUrl == null) {
    throw UpdateException(
      'Release $tag is missing $installerName or its SHA-256 file.',
    );
  }

  final page = Uri.tryParse(json['html_url']?.toString() ?? '');
  if (page == null || !page.hasScheme) {
    throw UpdateException('Release $tag has no valid GitHub page.');
  }
  return UpdateRelease(
    version: latest.toString(),
    tag: tag,
    installerUrl: installerUrl,
    checksumUrl: checksumUrl,
    releasePage: page,
    notes: json['body']?.toString() ?? '',
  );
}

class UpdateService {
  UpdateService({
    HttpClient? client,
    Uri? latestReleaseEndpoint,
    bool? installedEdition,
  }) : _client = client ?? HttpClient(),
       _latestReleaseEndpoint =
           latestReleaseEndpoint ?? Uri.parse(_latestReleaseUrl),
       _installedEdition = installedEdition;

  final HttpClient _client;
  final Uri _latestReleaseEndpoint;
  final bool? _installedEdition;

  bool get isInstalledEdition =>
      _installedEdition ??
      File(
        '${File(Platform.resolvedExecutable).parent.path}\\installed.marker',
      ).existsSync();

  Future<UpdateRelease?> checkForUpdate(
    String currentVersion, {
    String source = 'cdn',
    String customCdn = '',
    bool allowCurrentVersion = false,
  }) async {
    final response = await _get(
      resolveUpdateUrl(
        _latestReleaseEndpoint,
        source: source,
        customCdn: customCdn,
      ),
    );
    if (response.statusCode == HttpStatus.notFound) {
      await response.drain<void>();
      return null;
    }
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw UpdateException(
        'GitHub update check failed (HTTP ${response.statusCode}).',
      );
    }
    final value = jsonDecode(body);
    if (value is! Map) {
      throw const UpdateException(
        'GitHub returned an invalid release response.',
      );
    }
    return parseLatestRelease(
      value.cast<String, dynamic>(),
      currentVersion: currentVersion,
      allowCurrentVersion: allowCurrentVersion,
    );
  }

  Future<void> downloadAndLaunch(
    UpdateRelease release, {
    String source = 'cdn',
    String customCdn = '',
    void Function(int received, int total)? onProgress,
  }) async {
    final work = await Directory.systemTemp.createTemp(
      'poe2-loot-tracker-setup-',
    );
    try {
      final checksumFile = File('${work.path}\\release.sha256');
      final installerFile = File('${work.path}\\setup.exe');
      await _download(
        resolveUpdateUrl(
          release.checksumUrl,
          source: source,
          customCdn: customCdn,
        ),
        checksumFile,
      );
      await _download(
        resolveUpdateUrl(
          release.installerUrl,
          source: source,
          customCdn: customCdn,
        ),
        installerFile,
        onProgress: onProgress,
      );

      final checksumText = await checksumFile.readAsString();
      final expected = RegExp(
        r'^\s*([a-fA-F0-9]{64})\b',
      ).firstMatch(checksumText)?.group(1)?.toLowerCase();
      if (expected == null) {
        throw const UpdateException('The release SHA-256 file is invalid.');
      }
      final actual = (await sha256.bind(installerFile.openRead()).first)
          .toString();
      if (actual != expected) {
        throw const UpdateException(
          'The downloaded update failed SHA-256 verification.',
        );
      }

      await Process.start(
        installerFile.path,
        const [],
        mode: ProcessStartMode.detached,
      );
    } catch (_) {
      if (await work.exists()) await work.delete(recursive: true);
      rethrow;
    }
  }

  Future<HttpClientResponse> _get(Uri url) async {
    final request = await _client.getUrl(url);
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set(HttpHeaders.userAgentHeader, 'POE2LootTracker updater')
      ..set('X-GitHub-Api-Version', '2022-11-28');
    return request.close();
  }

  Future<void> _download(
    Uri url,
    File destination, {
    void Function(int received, int total)? onProgress,
  }) async {
    final response = await _get(url);
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw UpdateException(
        'Update download failed (HTTP ${response.statusCode}).',
      );
    }
    final output = destination.openWrite();
    var received = 0;
    try {
      await for (final chunk in response) {
        output.add(chunk);
        received += chunk.length;
        onProgress?.call(received, response.contentLength);
      }
    } finally {
      await output.close();
    }
  }

  Future<void> openReleasePage(UpdateRelease release) async {
    await Process.start('explorer.exe', [
      release.releasePage.toString(),
    ], mode: ProcessStartMode.detached);
  }

  void close() => _client.close(force: true);
}
