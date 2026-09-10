import 'dart:io';

import 'package:flutter/foundation.dart';

/// Windows key holding the per-user proxy configuration.
const String _internetSettings =
    r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

/// Makes Dart's HttpClient honour the Windows system proxy.
///
/// Dart's HttpClient ignores it; .NET does not. That asymmetry is visible in this app: the tracker
/// host reaches poe.ninja for prices through the proxy, while the panel could not fetch a single
/// item icon, because GGG's art CDN (`web.poecdn.com`) is only reachable through the proxy here.
///
/// Must run before the first image is requested: `NetworkImage` creates one shared HttpClient and
/// keeps it for the life of the process, so the override has to be installed up front.
Future<void> useSystemProxy() async {
  final proxy = await _readProxy();
  if (proxy.isEmpty) return;
  // A configured-but-not-running proxy is worse than no proxy at all: every request would fail
  // instantly instead of falling back to a working direct route.
  if (!await _isListening(proxy)) {
    debugPrint('http: system proxy $proxy is not listening, using direct connections');
    return;
  }
  HttpOverrides.global = _ProxyOverrides(proxy);
  debugPrint('http: routing requests through the system proxy $proxy');
}

Future<String> _readProxy() async {
  for (final name in const [
    'HTTPS_PROXY',
    'https_proxy',
    'HTTP_PROXY',
    'http_proxy',
  ]) {
    final value = Platform.environment[name];
    if (value != null && value.trim().isNotEmpty) return _normalize(value);
  }
  return _readWindowsProxy();
}

/// Read through `reg query` rather than dart:ffi: this happens once at startup, and it keeps the
/// dependency surface at zero.
Future<String> _readWindowsProxy() async {
  if (!Platform.isWindows) return '';
  try {
    final result = await Process.run('reg', const [
      'query',
      _internetSettings,
    ]).timeout(const Duration(seconds: 5));
    if (result.exitCode != 0) return '';
    final output = result.stdout.toString();
    final enabled = RegExp(
      r'ProxyEnable\s+REG_DWORD\s+0x([0-9a-fA-F]+)',
    ).firstMatch(output);
    if (enabled == null || int.parse(enabled.group(1)!, radix: 16) == 0) {
      return '';
    }
    final server = RegExp(r'ProxyServer\s+REG_SZ\s+(\S+)').firstMatch(output);
    if (server == null) return '';
    return _normalize(server.group(1)!);
  } catch (error) {
    debugPrint('http: could not read the system proxy: $error');
    return '';
  }
}

/// Accepts both `host:port` and WinINet's `http=host:port;https=host:port` form.
String _normalize(String value) {
  var text = value.trim();
  if (text.contains('=')) {
    final parts = <String, String>{};
    for (final entry in text.split(';')) {
      final index = entry.indexOf('=');
      if (index > 0) {
        parts[entry.substring(0, index).trim().toLowerCase()] = entry
            .substring(index + 1)
            .trim();
      }
    }
    text = parts['https'] ?? parts['http'] ?? '';
  }
  // Dart wants a scheme-less host:port after the PROXY keyword.
  return text.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://'), '');
}

Future<bool> _isListening(String hostPort) async {
  final index = hostPort.lastIndexOf(':');
  if (index <= 0) return false;
  final port = int.tryParse(hostPort.substring(index + 1));
  if (port == null) return false;
  try {
    final socket = await Socket.connect(
      hostPort.substring(0, index),
      port,
      timeout: const Duration(milliseconds: 500),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

class _ProxyOverrides extends HttpOverrides {
  _ProxyOverrides(this.proxy);

  final String proxy;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..findProxy = (_) => 'PROXY $proxy';
}
