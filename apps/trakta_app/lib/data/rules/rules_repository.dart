import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:trakta_core/trakta_core.dart';

/// Loads the rules packs bundled in assets/rules/ (copied from /rules by
/// tool/bin/sync_rules.dart). The app never downloads rules; a new income
/// year arrives with an app update.
class RulesRepository {
  RulesRepository([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<RulesLibrary> load() async {
    final index = jsonDecode(await _bundle.loadString('assets/rules/index.json')) as Map<String, Object?>;
    final years = (index['years']! as List).cast<int>();
    final packs = <RulesPack>[];
    for (final y in years) {
      final json = jsonDecode(await _bundle.loadString('assets/rules/$y.json')) as Map<String, Object?>;
      final pack = RulesPack.fromJson(json);
      final problems = validateRulesPack(pack);
      if (problems.isNotEmpty) {
        throw StateError('Bundled rules pack $y is invalid: ${problems.join('; ')}');
      }
      packs.add(pack);
    }
    return RulesLibrary(packs);
  }
}
