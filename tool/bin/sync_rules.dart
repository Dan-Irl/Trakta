// Copies rules/<year>.json into the app's bundled assets
// (apps/trakta_app/assets/rules/). The app loads packs only from there.
//
//   dart run tool/bin/sync_rules.dart          # from the repo root
//   dart run tool/bin/sync_rules.dart --check  # CI: fail if out of sync
import 'dart:convert';
import 'dart:io';

import 'package:trakta_tool/repo.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  final root = findRepoRoot();
  final src = Directory(p(root, ['rules']));
  final dst = Directory(p(root, ['apps', 'trakta_app', 'assets', 'rules']))..createSync(recursive: true);

  final files = packFiles(src);
  final years = <int>[];
  var outOfSync = false;
  for (final f in files) {
    final name = f.uri.pathSegments.last;
    years.add(int.parse(name.substring(0, 4)));
    final target = File(p(dst.absolute, [name]));
    final content = f.readAsStringSync();
    if (target.existsSync() && target.readAsStringSync() == content) continue;
    outOfSync = true;
    if (check) {
      stderr.writeln('Out of sync: ${target.path}');
    } else {
      target.writeAsStringSync(content);
      print('Copied $name');
    }
  }
  for (final stale in packFiles(dst)) {
    final name = stale.uri.pathSegments.last;
    if (!files.any((f) => f.uri.pathSegments.last == name)) {
      outOfSync = true;
      if (check) {
        stderr.writeln('Stale asset: ${stale.path}');
      } else {
        stale.deleteSync();
        print('Removed stale $name');
      }
    }
  }
  final index = File(p(dst.absolute, ['index.json']));
  final indexJson = '${const JsonEncoder.withIndent('  ').convert({'years': years})}\n';
  if (!index.existsSync() || index.readAsStringSync() != indexJson) {
    outOfSync = true;
    if (check) {
      stderr.writeln('Out of sync: ${index.path}');
    } else {
      index.writeAsStringSync(indexJson);
      print('Wrote index.json $years');
    }
  }
  if (check && outOfSync) {
    stderr.writeln('Run: dart run tool/bin/sync_rules.dart');
    exit(1);
  }
  print(outOfSync && !check ? 'Rules synced.' : 'Rules already in sync.');
}
