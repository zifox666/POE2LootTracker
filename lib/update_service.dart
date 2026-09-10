import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _latestReleaseUrl =
    'https://api.github.com/repos/zifox666/POE2LootTracker/releases/latest';

class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.tag,
    required this.archiveUrl,
    required this.checksumUrl,
    required this.releasePage,
    required this.notes,
  });

  final String version;
  final String tag;
  final Uri archiveUrl;
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
}) {
  final tag = json['tag_name']?.toString() ?? '';
  final latest = SemanticVersion.parse(tag);
  if (latest.compareTo(SemanticVersion.parse(currentVersion)) <= 0) {
    return null;
  }

  final archiveName = 'POE2LootTracker-$tag-windows-x64.zip';
  final checksumName = '$archiveName.sha256';
  Uri? archiveUrl;
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
      if (name == archiveName) archiveUrl = url;
      if (name == checksumName) checksumUrl = url;
    }
  }
  if (archiveUrl == null || checksumUrl == null) {
    throw UpdateException(
      'Release $tag is missing $archiveName or its SHA-256 file.',
    );
  }

  final page = Uri.tryParse(json['html_url']?.toString() ?? '');
  if (page == null || !page.hasScheme) {
    throw UpdateException('Release $tag has no valid GitHub page.');
  }
  return UpdateRelease(
    version: latest.toString(),
    tag: tag,
    archiveUrl: archiveUrl,
    checksumUrl: checksumUrl,
    releasePage: page,
    notes: json['body']?.toString() ?? '',
  );
}

class UpdateService {
  UpdateService({HttpClient? client, Uri? latestReleaseEndpoint})
    : _client = client ?? HttpClient(),
      _latestReleaseEndpoint =
          latestReleaseEndpoint ?? Uri.parse(_latestReleaseUrl);

  final HttpClient _client;
  final Uri _latestReleaseEndpoint;

  Future<UpdateRelease?> checkForUpdate(String currentVersion) async {
    final response = await _get(_latestReleaseEndpoint);
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
    );
  }

  Future<void> downloadAndLaunch(
    UpdateRelease release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final work = await Directory.systemTemp.createTemp(
      'poe2-loot-tracker-update-',
    );
    try {
      final checksumFile = File('${work.path}\\release.sha256');
      final archiveFile = File('${work.path}\\release.zip');
      await _download(release.checksumUrl, checksumFile);
      await _download(release.archiveUrl, archiveFile, onProgress: onProgress);

      final checksumText = await checksumFile.readAsString();
      final expected = RegExp(
        r'^\s*([a-fA-F0-9]{64})\b',
      ).firstMatch(checksumText)?.group(1)?.toLowerCase();
      if (expected == null) {
        throw const UpdateException('The release SHA-256 file is invalid.');
      }
      final actual = (await sha256.bind(archiveFile.openRead()).first)
          .toString();
      if (actual != expected) {
        throw const UpdateException(
          'The downloaded update failed SHA-256 verification.',
        );
      }

      final executable = File(Platform.resolvedExecutable);
      final script = File('${work.path}\\install-update.ps1');
      await script.writeAsString(
        _renderUpdaterScript(
          processId: pid,
          workDirectory: work.path,
          archivePath: archiveFile.path,
          installDirectory: executable.parent.path,
          executableName: executable.uri.pathSegments.last,
        ),
      );
      await Process.start('powershell.exe', [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script.path,
      ], mode: ProcessStartMode.detached);
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

  void close() => _client.close(force: true);
}

String _powerShellQuote(String value) => "'${value.replaceAll("'", "''")}'";

String _renderUpdaterScript({
  required int processId,
  required String workDirectory,
  required String archivePath,
  required String installDirectory,
  required String executableName,
}) {
  final work = _powerShellQuote(workDirectory);
  final archive = _powerShellQuote(archivePath);
  final install = _powerShellQuote(installDirectory);
  final executable = _powerShellQuote(executableName);
  return '''
\$ErrorActionPreference = 'Stop'
\$appProcessId = $processId
\$workDirectory = $work
\$archivePath = $archive
\$installDirectory = $install
\$executableName = $executable
\$stageDirectory = Join-Path \$workDirectory 'staged'
\$errorLog = Join-Path \$env:TEMP 'POE2LootTracker-update-error.log'

try {
  while (Get-Process -Id \$appProcessId -ErrorAction SilentlyContinue) {
    Start-Sleep -Milliseconds 250
  }
  Expand-Archive -LiteralPath \$archivePath -DestinationPath \$stageDirectory -Force
  if (-not (Test-Path -LiteralPath (Join-Path \$stageDirectory \$executableName))) {
    throw 'The update archive does not contain the application executable.'
  }
  Copy-Item -Path (Join-Path \$stageDirectory '*') -Destination \$installDirectory -Recurse -Force
  Start-Process -FilePath (Join-Path \$installDirectory \$executableName) -WorkingDirectory \$installDirectory
  Remove-Item -LiteralPath \$workDirectory -Recurse -Force -ErrorAction SilentlyContinue
} catch {
  \$_ | Out-String | Set-Content -LiteralPath \$errorLog -Encoding UTF8
  \$installedExecutable = Join-Path \$installDirectory \$executableName
  if (Test-Path -LiteralPath \$installedExecutable) {
    Start-Process -FilePath \$installedExecutable -WorkingDirectory \$installDirectory
  }
}
''';
}
