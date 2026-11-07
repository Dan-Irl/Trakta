/// Parsing, redirect resolution and validation of Skatteverket's
/// normalbelopp list. Pure functions so they
/// can be tested against recorded API responses and CSV files.
library;

import 'package:trakta_core/trakta_core.dart';

const fallbackName = 'Övriga länder och områden';

/// A row as published, before redirects are resolved.
final class RawRow {
  const RawRow({required this.name, required this.code, required this.value});

  /// "land eller område", trimmed.
  final String name;

  /// "landskod", or null when empty.
  final String? code;

  /// "normalbelopp" as published: a number ("1 226", 1226) or "Se Myanmar".
  final String value;

  @override
  String toString() => '$name ($code): $value';
}

final _nbsp = RegExp('[\\s  ]');

/// Parses an amount like `1226`, `"1 226"` or `"1 226"`. Returns null if
/// the value is not a number (e.g. a redirect).
int? parseAmount(String value) {
  final cleaned = value.replaceAll(_nbsp, '');
  if (cleaned.isEmpty) return null;
  return int.tryParse(cleaned);
}

/// Returns the redirect target for values like "Se Myanmar", else null.
String? parseRedirect(String value) {
  final m = RegExp(r'^se\s+(.+?)\s*$', caseSensitive: false).firstMatch(value.trim());
  return m?.group(1);
}

String _normalize(String s) => s.trim().toLowerCase();

/// Picks a field from an API row by trying several spellings.
Object? _field(Map<String, Object?> row, List<String> candidates) {
  for (final c in candidates) {
    for (final e in row.entries) {
      if (_normalize(e.key) == _normalize(c)) return e.value;
    }
  }
  return null;
}

/// Parses the rowstore API's `results` array. Field names come from the
/// open-source traktamente-mcp client; unknown shapes throw with the keys seen.
List<RawRow> parseApiResults(List<Object?> results) {
  final rows = <RawRow>[];
  for (final r in results) {
    final row = (r! as Map).cast<String, Object?>();
    final name = _field(row, ['land eller område', 'land_eller_omrade', 'land', 'land eller omrade']);
    final code = _field(row, ['landskod', 'landkod', 'kod']);
    final value = _field(row, ['normalbelopp', 'belopp']);
    if (name == null || value == null) {
      throw FormatException('Unexpected API row shape, keys: ${row.keys.toList()}');
    }
    final codeStr = code?.toString().trim();
    rows.add(RawRow(
      name: name.toString().trim(),
      code: (codeStr == null || codeStr.isEmpty) ? null : codeStr.toUpperCase(),
      value: value.toString().trim(),
    ));
  }
  return rows;
}

/// Parses Skatteverket's semicolon-separated CSV (header row first). Handles
/// quoted fields and a UTF-8 BOM.
List<RawRow> parseCsv(String text) {
  final lines = text
      .replaceFirst('﻿', '')
      .split(RegExp(r'\r?\n'))
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return const [];
  List<String> split(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (ch == ';' && !quoted) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString());
    return out.map((s) => s.trim()).toList();
  }

  final header = split(lines.first).map(_normalize).toList();
  int col(List<String> names) {
    for (final n in names) {
      final i = header.indexOf(_normalize(n));
      if (i >= 0) return i;
    }
    throw FormatException('CSV header missing one of $names: $header');
  }

  final nameCol = col(['land eller område', 'land']);
  final valueCol = col(['normalbelopp', 'belopp']);
  final codeCol = header.indexOf('landskod');
  return [
    for (final line in lines.skip(1))
      if (split(line) case final cells when cells.length > valueCol)
        RawRow(
          name: cells[nameCol],
          code: codeCol >= 0 && codeCol < cells.length && cells[codeCol].isNotEmpty
              ? cells[codeCol].toUpperCase()
              : null,
          value: cells[valueCol],
        ),
  ];
}

/// Result of [resolveRows]: the rates to store, and any problems found.
final class ResolvedRates {
  const ResolvedRates(this.rates, this.errors);
  final List<ForeignRate> rates;
  final List<String> errors;
}

/// Resolves redirects so the app never does lookups at runtime.
/// [knownCodes] fills in codes for rows without `landskod` (by Swedish name).
ResolvedRates resolveRows(List<RawRow> raw, {Map<String, String> knownCodes = const {}}) {
  final errors = <String>[];
  final byName = <String, RawRow>{};
  for (final r in raw) {
    if (byName.containsKey(_normalize(r.name))) {
      errors.add('Duplicate row "${r.name}"');
    }
    byName[_normalize(r.name)] = r;
  }

  String? codeFor(RawRow r) {
    if (r.code != null) return r.code;
    for (final e in knownCodes.entries) {
      if (_normalize(e.key) == _normalize(r.name)) return e.value;
    }
    return null;
  }

  final rates = <ForeignRate>[];
  final usedCodes = <String>{};
  for (final r in raw) {
    final amount = parseAmount(r.value);
    String? redirectTo;
    int? kr = amount;
    if (amount == null) {
      final target = parseRedirect(r.value);
      if (target == null) {
        errors.add('"${r.name}": value "${r.value}" is neither an amount nor a redirect');
        continue;
      }
      final t = byName[_normalize(target)];
      if (t == null) {
        errors.add('"${r.name}" redirects to unknown "$target"');
        continue;
      }
      final tAmount = parseAmount(t.value);
      if (tAmount == null) {
        errors.add('"${r.name}" redirects to "${t.name}", which is itself a redirect');
        continue;
      }
      redirectTo = t.name; // canonical casing, fixes "Se övriga länder och områden"
      kr = tAmount;
    }
    if (kr == null || kr <= 0) {
      errors.add('"${r.name}" has non-positive amount');
      continue;
    }
    var code = r.name == fallbackName ? null : codeFor(r);
    if (code != null && !usedCodes.add(code)) {
      // Redirect aliases may share the target's code; keep the code on the
      // canonical row only.
      code = null;
    }
    rates.add(ForeignRate(name: r.name, code: code, kr: kr, redirectTo: redirectTo));
  }

  if (!rates.any((r) => r.name == fallbackName)) errors.add('Fallback row "$fallbackName" missing');
  if (rates.length <= 100) errors.add('Only ${rates.length} rows, expected more than 100');
  rates.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  // Keep the fallback last, as on Skatteverket's page.
  final fb = rates.where((r) => r.name == fallbackName).toList();
  rates
    ..removeWhere((r) => r.name == fallbackName)
    ..addAll(fb);
  return ResolvedRates(rates, errors);
}

/// Differences between two sets of rates (by name).
final class RatesDiff {
  RatesDiff(this.added, this.removed, this.changed, this.bigChanges);
  final List<ForeignRate> added;
  final List<ForeignRate> removed;
  final List<({ForeignRate from, ForeignRate to})> changed;

  /// Changes over ±30 % for a human to review.
  final List<({ForeignRate from, ForeignRate to})> bigChanges;

  bool get isEmpty => added.isEmpty && removed.isEmpty && changed.isEmpty;

  @override
  String toString() {
    final b = StringBuffer();
    for (final a in added) {
      b.writeln('  + ${a.name}: ${a.kr} kr');
    }
    for (final r in removed) {
      b.writeln('  - ${r.name}: ${r.kr} kr');
    }
    for (final c in changed) {
      final pct = ((c.to.kr - c.from.kr) * 100 / c.from.kr).toStringAsFixed(1);
      final flag = bigChanges.contains(c) ? '  <-- over ±30 %, review' : '';
      final codeNote = c.from.code != c.to.code ? ' (code ${c.from.code} -> ${c.to.code})' : '';
      b.writeln('  ~ ${c.to.name}: ${c.from.kr} -> ${c.to.kr} kr ($pct %)$codeNote$flag');
    }
    return b.toString();
  }
}

RatesDiff diffRates(List<ForeignRate> before, List<ForeignRate> after) {
  final b = {for (final r in before) _normalize(r.name): r};
  final a = {for (final r in after) _normalize(r.name): r};
  final added = [for (final e in a.entries) if (!b.containsKey(e.key)) e.value];
  final removed = [for (final e in b.entries) if (!a.containsKey(e.key)) e.value];
  final changed = <({ForeignRate from, ForeignRate to})>[];
  final big = <({ForeignRate from, ForeignRate to})>[];
  for (final e in a.entries) {
    final old = b[e.key];
    if (old == null) continue;
    if (old.kr != e.value.kr || old.redirectTo != e.value.redirectTo || old.code != e.value.code) {
      final c = (from: old, to: e.value);
      changed.add(c);
      if ((e.value.kr - old.kr).abs() * 100 > old.kr * 30) big.add(c);
    }
  }
  return RatesDiff(added, removed, changed, big);
}
