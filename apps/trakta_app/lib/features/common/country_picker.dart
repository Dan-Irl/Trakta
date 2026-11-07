import 'package:flutter/material.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'country_names.dart';
import 'format.dart';

/// One country the user can pick: Sweden, a row from the rules pack's
/// foreign list, or the pack's "other countries" fallback.
class CountryOption {
  const CountryOption({required this.name, required this.code, required this.kr, this.isFallback = false});

  /// Skatteverket's Swedish name, the value stored and passed to the engine.
  final String name;

  /// ISO 3166-1 alpha-2, null for a few redirect rows and the fallback.
  final String? code;

  /// Normalbelopp (or the domestic full-day amount) in whole kronor.
  final int kr;
  final bool isFallback;
}

/// The pack for [year], or the newest pack when the year has none yet.
RulesPack? packForYear(RulesLibrary library, int year) => library.forYear(year) ?? library.packs.lastOrNull;

/// Emoji flag for an ISO alpha-2 code ("DE" → 🇩🇪), empty when unknown.
String flagEmoji(String? code) {
  if (code == null || code.length != 2) return '';
  final c = code.toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(c)) return '';
  return String.fromCharCodes(c.codeUnits.map((u) => 0x1F1E6 + u - 0x41));
}

/// ISO code for a stored country name, "SE" for Sweden.
String? countryCode(RulesPack? pack, String name) => isSwedenKey(name) ? swedenCode : pack?.lookup(name)?.code;

/// "🇩🇪 Germany (Tyskland)" in English, "🇩🇪 Tyskland" in Swedish.
String countryLabel(AppLocalizations l, RulesPack? pack, String name) {
  final flag = flagEmoji(countryCode(pack, name));
  final text = countryName(l, isSwedenKey(name) ? swedenName : name);
  return flag.isEmpty ? text : '$flag $text';
}

/// Sweden first, then the pack's countries by displayed name, fallback last.
List<CountryOption> countryOptions(RulesPack pack, AppLocalizations l) {
  final foreign = [
    for (final r in pack.pickableCountries) CountryOption(name: r.name, code: r.code, kr: r.kr),
  ]..sort((a, b) => _fold(countryName(l, a.name)).compareTo(_fold(countryName(l, b.name))));
  final fallback = pack.fallbackRate;
  return [
    CountryOption(name: swedenName, code: swedenCode, kr: pack.domestic.fullDayKr),
    ...foreign,
    CountryOption(name: fallback.name, code: null, kr: fallback.kr, isFallback: true),
  ];
}

/// Filters [options] by Swedish name, English name or ISO code, ignoring case
/// and accents ("osterrike" finds Österrike). Best matches first: exact code,
/// then names starting with the query, then words starting with it, then
/// names containing it.
List<CountryOption> searchCountries(List<CountryOption> options, String query) {
  final q = _fold(query.trim());
  if (q.isEmpty) return options;
  int? rank(CountryOption o) {
    if (o.code != null && o.code!.toLowerCase() == q) return 0;
    final names = [o.name, ?englishCountryName(o.name), if (o.name == swedenName) 'Sweden'].map(_fold);
    if (names.any((n) => n.startsWith(q))) return 1;
    if (names.any((n) => n.split(' ').any((w) => w.startsWith(q)))) return 2;
    if (names.any((n) => n.contains(q))) return 3;
    return null;
  }

  final ranked = [
    for (final (i, o) in options.indexed)
      if (rank(o) case final r?) (rank: r, index: i, option: o),
  ]..sort((a, b) => a.rank != b.rank ? a.rank.compareTo(b.rank) : a.index.compareTo(b.index));
  return [for (final r in ranked) r.option];
}

const _accents = {
  'å': 'a', 'ä': 'a', 'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', //
  'ö': 'o', 'ø': 'o', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ü': 'u', 'ù': 'u', 'ú': 'u', 'û': 'u',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ç': 'c', 'č': 'c', 'ć': 'c', 'ñ': 'n',
  'š': 's', 'ș': 's', 'ş': 's', 'ž': 'z', 'ț': 't', 'ţ': 't', 'ł': 'l', 'ý': 'y', '-': ' ',
};

String _fold(String s) => s.toLowerCase().split('').map((c) => _accents[c] ?? c).join();

/// Opens a searchable country list and returns the chosen Swedish name.
Future<String?> showCountryPicker(BuildContext context, {required RulesPack pack, String? selected}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _CountrySheet(pack: pack, selected: selected),
    );

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.pack, this.selected});

  final RulesPack pack;
  final String? selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  final _query = TextEditingController();
  late final List<CountryOption> _options = countryOptions(widget.pack, AppLocalizations.of(context));

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _isSelected(CountryOption o) {
    final s = widget.selected;
    if (s == null) return false;
    return isSwedenKey(s) ? o.name == swedenName : o.name.toLowerCase() == s.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final results = searchCountries(_options, _query.text);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l.countrySearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                          onPressed: () => setState(_query.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (results.isNotEmpty) Navigator.pop(context, results.first.name);
                },
              ),
            ),
            const SizedBox(height: Space.sm),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(l.countryNoMatch,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final o = results[i];
                        final selected = _isSelected(o);
                        return ListTile(
                          leading: CountryFlag(code: o.code),
                          title: Text(countryName(l, o.name)),
                          subtitle: Text(l.amountPerDay(context.money(Ore.kr(o.kr)))),
                          trailing: selected
                              ? Icon(Icons.check, color: theme.colorScheme.primary)
                              : o.code == null
                                  ? null
                                  : Text(o.code!,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          selected: selected,
                          onTap: () => Navigator.pop(context, o.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flag emoji for [code], or a globe for rows without a code.
class CountryFlag extends StatelessWidget {
  const CountryFlag({super.key, required this.code});

  final String? code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flag = flagEmoji(code);
    return SizedBox(
      width: Space.xl,
      child: Center(
        child: flag.isEmpty
            ? Icon(Icons.public, color: theme.colorScheme.onSurfaceVariant)
            : Text(flag, style: theme.textTheme.headlineSmall),
      ),
    );
  }
}

/// A form field showing the chosen country with its flag; tapping it opens
/// [showCountryPicker]. [value] is a Swedish name ("Sverige" for Sweden).
///
/// With [inherited] set (a day inside a trip), a null [value] means "same as
/// the trip" and a clear button resets a different choice back to null.
class CountryField extends StatelessWidget {
  const CountryField({
    super.key,
    required this.label,
    required this.pack,
    required this.value,
    required this.onChanged,
    this.inherited,
    this.helperText,
  });

  final String label;
  final RulesPack pack;
  final String? value;
  final String? inherited;
  final String? helperText;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final shown = value ?? inherited ?? swedenName;
    final name = countryName(l, isSwedenKey(shown) ? swedenName : shown);
    final canReset = inherited != null && value != null;

    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(Radii.base)),
      onTap: () async {
        final picked = await showCountryPicker(context, pack: pack, selected: shown);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          helperMaxLines: 3,
          suffixIcon: canReset
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l.countrySameAsTrip(countryName(l, inherited!)),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Row(
          children: [
            Text(flagEmoji(countryCode(pack, shown))),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                value == null && inherited != null ? l.countrySameAsTrip(name) : name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
