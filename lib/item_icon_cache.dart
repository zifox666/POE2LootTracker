import 'dart:io';

/// Persists downloaded market icons alongside the host's other cache files.
///
/// The host stores its database and price cache under `%APPDATA%\\POE2LootTracker`.
/// Keeping image files there means they survive app restarts without adding a
/// second application-data location.
class ItemIconCache {
  ItemIconCache._();

  static final _inFlight = <String, Future<File?>>{};

  static final Directory cacheDirectory = Directory(
    [
      Platform.environment['APPDATA'] ?? Directory.current.path,
      'POE2LootTracker',
      'cache',
      'item-icons',
    ].join(Platform.pathSeparator),
  );

  /// Returns the local file reserved for [uri]. It may not exist yet.
  static File cacheFileFor(Uri uri) => File(
    '${cacheDirectory.path}${Platform.pathSeparator}${_fileName(uri)}.img',
  );

  /// Returns the local image, downloading it once when it is missing.
  static Future<File?> load(Uri uri) {
    final key = uri.toString();
    final current = _inFlight[key];
    if (current != null) return current;

    final future = _load(uri);
    _inFlight[key] = future;
    future.then<void>(
      (_) => _inFlight.remove(key),
      onError: (Object error, StackTrace stackTrace) => _inFlight.remove(key),
    );
    return future;
  }

  static Future<File?> _load(Uri uri) async {
    final target = cacheFileFor(uri);
    if (target.existsSync()) return target;

    await cacheDirectory.create(recursive: true);
    final temporary = File('${target.path}.part');
    if (temporary.existsSync()) await temporary.delete();

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      await response.pipe(temporary.openWrite());
      await temporary.rename(target.path);
      return target;
    } finally {
      client.close(force: true);
    }
  }

  static String _fileName(Uri uri) {
    var hash = 0xcbf29ce484222325;
    for (final codeUnit in uri.toString().codeUnits) {
      hash = ((hash ^ codeUnit) * 0x100000001b3).toUnsigned(64);
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
