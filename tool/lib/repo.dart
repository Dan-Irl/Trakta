import 'dart:convert';
import 'dart:io';

import 'package:trakta_core/trakta_core.dart';

/// Repository root: the first directory above cwd containing `rules/` and a
/// `pubspec.yaml` declaring the workspace.
Directory findRepoRoot([Directory? from]) {
  var dir = (from ?? Directory.current).absolute;
  while (true) {
    final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
    if (Directory('${dir.path}${Platform.pathSeparator}rules').existsSync() &&
        pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('workspace:')) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not find the Trakta repository root above ${Directory.current.path}');
    }
    dir = parent;
  }
}

String p(Directory root, List<String> parts) => [root.path, ...parts].join(Platform.pathSeparator);

Map<String, Object?> readJson(File f) => (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();

/// Year pack files (`rules/2026.json` …), sorted by year.
List<File> packFiles(Directory rulesDir) => rulesDir
    .listSync()
    .whereType<File>()
    .where((f) => RegExp(r'^\d{4}\.json$').hasMatch(f.uri.pathSegments.last))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

/// Encodes a rules pack with two-space indentation and one foreign rate per
/// line, so yearly diffs stay readable in pull requests.
String encodePack(Map<String, Object?> pack) {
  const encoder = JsonEncoder.withIndent('  ');
  final rates = pack['foreignRates'];
  if (rates is! List) return '${encoder.convert(pack)}\n';
  const marker = '"__FOREIGN_RATES__"';
  final copy = {...pack, 'foreignRates': '__FOREIGN_RATES__'};
  final ratesJson = [
    for (final r in rates)
      '    {${(r as Map).entries.map((e) => '${jsonEncode(e.key)}: ${jsonEncode(e.value)}').join(', ')}}',
  ].join(',\n');
  return '${encoder.convert(copy).replaceFirst(marker, '[\n$ratesJson\n  ]')}\n';
}

List<Map<String, Object?>> ratesToJson(List<ForeignRate> rates) => [for (final r in rates) r.toJson()];
