import 'package:flutter_test/flutter_test.dart';
import 'package:poe2_loot_tracker/update_service.dart';

void main() {
  group('resolveUpdateUrl', () {
    final github = Uri.parse('https://github.com/owner/repo/releases/file.zip');

    test('supports CDN, native, and custom prefixes', () {
      expect(
        resolveUpdateUrl(github, source: 'cdn').toString(),
        'https://gh-proxy.org/$github',
      );
      expect(resolveUpdateUrl(github, source: 'native'), github);
      expect(
        resolveUpdateUrl(
          github,
          source: 'custom',
          customCdn: 'https://mirror.example/proxy',
        ).toString(),
        'https://mirror.example/proxy/$github',
      );
    });

    test('rejects an empty or insecure custom prefix', () {
      expect(
        () => resolveUpdateUrl(github, source: 'custom'),
        throwsA(isA<UpdateException>()),
      );
      expect(
        () => resolveUpdateUrl(
          github,
          source: 'custom',
          customCdn: 'http://mirror.example',
        ),
        throwsA(isA<UpdateException>()),
      );
    });
  });

  group('SemanticVersion', () {
    test('compares each numeric component', () {
      expect(
        SemanticVersion.parse(
              'v2.0.0',
            ).compareTo(SemanticVersion.parse('1.99.99')) >
            0,
        isTrue,
      );
      expect(
        SemanticVersion.parse(
              '1.2.10',
            ).compareTo(SemanticVersion.parse('1.2.9')) >
            0,
        isTrue,
      );
      expect(
        SemanticVersion.parse(
          '1.2.3',
        ).compareTo(SemanticVersion.parse('v1.2.3')),
        0,
      );
    });

    test('rejects release tags outside the supported format', () {
      expect(
        () => SemanticVersion.parse('v1.2'),
        throwsA(isA<UpdateException>()),
      );
    });
  });

  group('parseLatestRelease', () {
    test('returns the matching Windows archive for a newer version', () {
      final release = parseLatestRelease(
        _release('v1.3.0'),
        currentVersion: '1.2.9',
      );

      expect(release, isNotNull);
      expect(release!.version, '1.3.0');
      expect(release.archiveUrl.path, endsWith('.zip'));
      expect(release.checksumUrl.path, endsWith('.zip.sha256'));
    });

    test('does not offer the current or an older version', () {
      expect(
        parseLatestRelease(_release('v1.2.3'), currentVersion: '1.2.3'),
        isNull,
      );
      expect(
        parseLatestRelease(_release('v1.2.2'), currentVersion: '1.2.3'),
        isNull,
      );
    });

    test('can return the current release for a forced reinstall', () {
      final release = parseLatestRelease(
        _release('v1.2.3'),
        currentVersion: '1.2.3',
        allowCurrentVersion: true,
      );

      expect(release?.version, '1.2.3');
    });

    test('rejects a newer release without its checksum', () {
      final json = _release('v2.0.0');
      (json['assets'] as List).removeLast();

      expect(
        () => parseLatestRelease(json, currentVersion: '1.0.0'),
        throwsA(isA<UpdateException>()),
      );
    });
  });
}

Map<String, dynamic> _release(String tag) {
  final archive = 'POE2LootTracker-$tag-windows-x64.zip';
  return {
    'tag_name': tag,
    'html_url': 'https://github.com/zifox666/POE2LootTracker/releases/tag/$tag',
    'body': 'Release notes',
    'assets': [
      {
        'name': archive,
        'browser_download_url': 'https://example.test/$archive',
      },
      {
        'name': '$archive.sha256',
        'browser_download_url': 'https://example.test/$archive.sha256',
      },
    ],
  };
}
