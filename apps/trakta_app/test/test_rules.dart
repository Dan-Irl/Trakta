import 'dart:convert';
import 'dart:io';

import 'package:trakta_core/trakta_core.dart';

/// Loads the bundled packs straight from assets/rules (flutter test runs with
/// the package directory as cwd).
RulesLibrary testLibrary() {
  final index = jsonDecode(File('assets/rules/index.json').readAsStringSync()) as Map<String, Object?>;
  return RulesLibrary([
    for (final y in (index['years']! as List).cast<int>())
      RulesPack.fromJson(jsonDecode(File('assets/rules/$y.json').readAsStringSync()) as Map<String, Object?>),
  ]);
}
