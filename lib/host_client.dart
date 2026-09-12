import 'dart:async';
import 'dart:convert';
import 'dart:io';

class HostClient {
  Process? _process;
  Future<void>? _starting;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _pending = <String, Completer<dynamic>>{};
  int _nextId = 1;
  bool _disposed = false;
  String? _lastError;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isRunning => _process != null;
  String? get lastError => _lastError;

  /// Spawns the tracker host if it is not running. Callers that arrive while a spawn is already in
  /// flight share that attempt instead of starting a second process.
  ///
  /// The sharing matters: every tab lives in an IndexedStack and is therefore built by the first
  /// frame, which `main()` schedules *before* `AppController.initialize()` has finished spawning
  /// the host. A tab that loads host data from `initState` used to lose that race on every launch.
  Future<void> start() {
    if (_process != null) return Future<void>.value();
    return _starting ??= _start();
  }

  Future<void> _start() async {
    try {
      _lastError = null;
      final executable = _findExecutable();
      final process = await Process.start(
        executable,
        const [],
        mode: ProcessStartMode.normal,
      );
      _process = process;
      _stdoutSubscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleLine);
      _stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.trim().isNotEmpty) {
              _events.add({
                'type': 'hostLog',
                'payload': {'message': line},
              });
            }
          });
      unawaited(
        process.exitCode.then((code) {
          if (!_events.isClosed) {
            _events.add({
              'type': 'hostError',
              'payload': {'code': 'host_exited', 'message': '$code'},
            });
          }
          for (final completer in _pending.values) {
            if (!completer.isCompleted) {
              completer.completeError(
                StateError('Tracker host exited ($code).'),
              );
            }
          }
          _pending.clear();
          _process = null;
          // Let a later request wait for (or trigger) a fresh spawn instead of reusing the future
          // of the process that just died.
          _starting = null;
        }),
      );
    } catch (_) {
      _starting = null;
      rethrow;
    }
  }

  Future<dynamic> request(
    String type, [
    Map<String, dynamic> payload = const {},
  ]) async {
    // Wait out an in-flight spawn rather than failing: the first frame can build before
    // AppController.initialize() has got the host up.
    final starting = _starting;
    if (starting != null) await starting;
    final process = _process;
    if (process == null) throw StateError('Tracker host is not running.');
    final id = 'flutter-${_nextId++}';
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    process.stdin.writeln(
      jsonEncode({'v': 1, 'id': id, 'type': type, 'payload': payload}),
    );
    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('Tracker host request timed out: $type');
      },
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final process = _process;
    if (process != null) {
      await process.stdin.close();
      try {
        await process.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        process.kill();
        await process.exitCode;
      }
    }
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    await _events.close();
  }

  void _handleLine(String line) {
    try {
      final message = (jsonDecode(line) as Map).cast<String, dynamic>();
      final type = message['type'] as String? ?? '';
      final id = message['id'] as String?;
      final payload = message['payload'];
      if (type == 'result' && id != null) {
        final completer = _pending.remove(id);
        if (completer == null) return;
        final result = payload is Map
            ? payload.cast<String, dynamic>()
            : const <String, dynamic>{};
        if (result['ok'] == true) {
          completer.complete(result['data']);
        } else {
          final error = result['error'] is Map
              ? (result['error'] as Map).cast<String, dynamic>()
              : const <String, dynamic>{};
          completer.completeError(
            HostException(
              error['code']?.toString() ?? 'host_error',
              error['message']?.toString() ?? 'Unknown host error',
            ),
          );
        }
      } else {
        if (type == 'hostError' && payload is Map) {
          _lastError = payload['message']?.toString();
        }
        _events.add({'type': type, 'payload': payload});
      }
    } catch (_) {
      // Third-party diagnostics are not part of the JSON protocol and are ignored.
    }
  }

  String _findExecutable() {
    final separator = Platform.pathSeparator;
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      '$executableDirectory${separator}tracker_host${separator}tracker_host.exe',
      '${Directory.current.path}${separator}tracker_host${separator}bin${separator}x64${separator}Debug${separator}net10.0-windows${separator}tracker_host.exe',
      '${Directory.current.path}${separator}tracker_host${separator}bin${separator}x64${separator}Release${separator}net10.0-windows${separator}win-x64${separator}tracker_host.exe',
    ];
    return candidates.firstWhere(
      (candidate) => File(candidate).existsSync(),
      orElse: () => candidates.first,
    );
  }
}

class HostException implements Exception {
  const HostException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => '$code: $message';
}
