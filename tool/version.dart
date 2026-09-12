// Synchronises every version number in the project from the single source of truth.
//
// `pubspec.yaml` owns the version. Nothing else is allowed to be edited by hand, because the three
// places that need a version disagree in ways nobody notices until a release is already published:
//
//   * Flutter reads `pubspec.yaml` itself and passes it to the Windows runner's CMake, which stamps
//     the number into the .exe's version resource (windows/CMakeLists.txt sets FLUTTER_VERSION, and
//     Runner.rc turns that into FILEVERSION/PRODUCTVERSION). That path needs no help from here.
//   * Dart cannot read a version resource at runtime, so the number the *running app* compares
//     against the newest GitHub release has to be compiled in. That is `lib/app_version.dart`,
//     which this tool generates.
//   * The .NET tracking host is a separate assembly with its own identity in TrackerHost.csproj.
//
// Before this existed, pubspec.yaml said 1.0.0+1 while TrackerHost.csproj said 2.0.0, so a build
// carried two different answers to "what version is this?" depending on which half was asked.
//
// Usage:
//   dart run tool/version.dart           rewrite lib/app_version.dart and TrackerHost.csproj
//   dart run tool/version.dart --check   fail if either file has drifted from pubspec.yaml
//   dart run tool/version.dart --print   print the version from pubspec.yaml and nothing else
//   dart run tool/version.dart --tag     print the git tag a release of this version must use
//   dart run tool/version.dart --expect-tag v1.2.3
//                                        assert that the given tag matches pubspec.yaml, for CI

import 'dart:io';

/// The version from `pubspec.yaml`. New versions are bare `1.2.3`; `+45` remains readable so old
/// revisions can still run this tool.
class ProjectVersion {
  const ProjectVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
  });

  final int major;
  final int minor;
  final int patch;
  final int? build;

  /// The semver half, `1.2.3`. This is what a release tag carries.
  String get semantic => '$major.$minor.$patch';

  /// The version exactly as represented by the supported current or legacy pubspec forms.
  String get full => build == null ? semantic : '$semantic+$build';

  /// The four-part form Windows version resources want, `1.2.3.45`.
  String get numeric => '$semantic.${build ?? 0}';

  /// The release tag, `v1.2.3`. Legacy pubspec build metadata is deliberately omitted.
  String get tag => 'v$semantic';

  @override
  String toString() => full;
}

/// Thrown for any condition the caller is expected to report rather than debug.
class ToolFailure implements Exception {
  ToolFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

final _versionLine = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true);

ProjectVersion readPubspecVersion() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    throw ToolFailure(
      'pubspec.yaml was not found in ${Directory.current.path}. Run this tool from the project '
      'root, which is what `dart run tool/version.dart` does by default.',
    );
  }
  final match = _versionLine.firstMatch(file.readAsStringSync());
  if (match == null) {
    throw ToolFailure('pubspec.yaml has no top-level `version:` line to read.');
  }
  return parseVersion(match.group(1)!);
}

ProjectVersion parseVersion(String text) {
  // Dependencies carry `^`/`>=` constraints; a version never does. Catching the shape here means a
  // malformed pubspec reports itself instead of producing a nonsense tag later.
  final match = RegExp(
    r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$',
  ).firstMatch(text.trim());
  if (match == null) {
    throw ToolFailure(
      'pubspec.yaml declares the version "$text", which is not MAJOR.MINOR.PATCH or the '
      'legacy MAJOR.MINOR.PATCH+BUILD form.',
    );
  }
  return ProjectVersion(
    major: int.parse(match.group(1)!),
    minor: int.parse(match.group(2)!),
    patch: int.parse(match.group(3)!),
    build: match.group(4) == null ? null : int.parse(match.group(4)!),
  );
}

/// The generated Dart constant, compiled into the shell so the running app knows its own version.
String renderAppVersion(ProjectVersion version) =>
    '''
// GENERATED CODE - DO NOT MODIFY BY HAND.
//
// Written by `dart run tool/version.dart` from the `version:` line in pubspec.yaml. Edit pubspec.yaml
// and re-run the tool; a hand edit here is reverted by the next run, and CI fails the build if this
// file disagrees with pubspec.yaml.

/// The semantic version, `1.2.3`. Release tags and update comparisons use exactly this.
const String appVersion = '${version.semantic}';

/// The canonical project version for display and diagnostics.
const String appVersionFull = '${version.full}';

/// The git tag a release of this version must carry, `v1.2.3`.
const String appVersionTag = '${version.tag}';

/// [appVersion] split into comparable numbers.
const List<int> appVersionParts = <int>[${version.major}, ${version.minor}, ${version.patch}];
''';

/// Rewrites the four version properties in TrackerHost.csproj.
///
/// Matched by name rather than by line number: the project file is edited by hand and by Visual
/// Studio, so the properties move around.
String renderCsproj(String source, ProjectVersion version) {
  var output = source;

  void setProperty(String name, String value) {
    final existing = RegExp('<$name>[^<]*</$name>');
    if (existing.hasMatch(output)) {
      output = output.replaceFirst(existing, '<$name>$value</$name>');
      return;
    }
    // Absent properties are inserted just after <Version>, which every project file that this tool
    // touches already has, so the three stay adjacent and readable.
    final anchor = RegExp(r'<Version>[^<]*</Version>');
    final match = anchor.firstMatch(output);
    if (match == null) {
      throw ToolFailure(
        'TrackerHost.csproj has neither a <Version> nor a <$name> property to write. Add a '
        '<Version> element to its first <PropertyGroup>.',
      );
    }
    output = output.replaceRange(
      match.end,
      match.end,
      '\n    <$name>$value</$name>',
    );
  }

  setProperty('Version', version.semantic);
  setProperty('AssemblyVersion', version.numeric);
  setProperty('FileVersion', version.numeric);
  setProperty('InformationalVersion', version.full);
  return output;
}

const _appVersionPath = 'lib/app_version.dart';
const _csprojPath = 'tracker_host/TrackerHost.csproj';

/// A planned or applied write, kept so `--check` can report drift without touching anything.
class _Target {
  _Target(this.path, this.expected);
  final String path;
  final String expected;
}

List<_Target> _plan(ProjectVersion version) {
  final csproj = File(_csprojPath);
  if (!csproj.existsSync()) {
    throw ToolFailure('$_csprojPath was not found.');
  }
  return [
    _Target(_appVersionPath, renderAppVersion(version)),
    _Target(_csprojPath, renderCsproj(csproj.readAsStringSync(), version)),
  ];
}

void _write(List<_Target> targets) {
  for (final target in targets) {
    final file = File(target.path);
    final current = file.existsSync() ? file.readAsStringSync() : null;
    if (current == target.expected) {
      stdout.writeln('unchanged  ${target.path}');
      continue;
    }
    file.writeAsStringSync(target.expected);
    stdout.writeln('updated    ${target.path}');
  }
}

/// Reports every file whose contents do not match what pubspec.yaml implies.
bool _check(List<_Target> targets) {
  var drifted = false;
  for (final target in targets) {
    final file = File(target.path);
    if (!file.existsSync()) {
      stderr.writeln('drift: ${target.path} does not exist');
      drifted = true;
      continue;
    }
    if (file.readAsStringSync() == target.expected) continue;
    stderr.writeln('drift: ${target.path} does not match pubspec.yaml');
    drifted = true;
  }
  if (drifted) {
    stderr.writeln(
      '\nRun `dart run tool/version.dart` and commit the result. Every version number in this '
      'project is generated from the `version:` line in pubspec.yaml.',
    );
  }
  return drifted;
}

void main(List<String> arguments) {
  try {
    final version = readPubspecVersion();

    if (arguments.contains('--print')) {
      stdout.writeln(version.full);
      return;
    }
    if (arguments.contains('--tag')) {
      stdout.writeln(version.tag);
      return;
    }

    final expectIndex = arguments.indexOf('--expect-tag');
    if (expectIndex >= 0) {
      final supplied = expectIndex + 1 < arguments.length
          ? arguments[expectIndex + 1]
          : '';
      if (supplied.isEmpty) {
        throw ToolFailure('--expect-tag needs the tag to compare against.');
      }
      if (supplied != version.tag) {
        throw ToolFailure(
          'the tag "$supplied" does not match pubspec.yaml, which is at ${version.full} and '
          'therefore expects the tag "${version.tag}". Bump the `version:` line in pubspec.yaml, '
          'commit it, and tag that commit.',
        );
      }
      stdout.writeln('${version.tag} matches pubspec.yaml (${version.full})');
      return;
    }

    final targets = _plan(version);

    if (arguments.contains('--check')) {
      if (_check(targets)) exit(1);
      stdout.writeln(
        'version ${version.full} is in sync across pubspec.yaml, '
        '$_appVersionPath and $_csprojPath',
      );
      return;
    }

    _write(targets);
    stdout.writeln('version ${version.full} (tag ${version.tag})');
  } on ToolFailure catch (failure) {
    stderr.writeln('version: ${failure.message}');
    exit(1);
  }
}
