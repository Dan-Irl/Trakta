import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/tokens.dart';
import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/trip_repository.dart';
import '../../l10n/app_localizations.dart';
import '../common/country_picker.dart';
import '../common/format.dart';

/// Edits one day and returns the changed row, or null when dismissed. The
/// caller stores it, or keeps it with an unsaved trip.
Future<TripDayRow?> showDayEditSheet(
  BuildContext context, {
  required TripDayRow row,
  required bool hasNight,
  required String tripCountry,
  required DayMeals tripMeals,
  required LodgingKind tripLodging,
}) {
  return showModalBottomSheet<TripDayRow>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _DayEditSheet(
      row: row,
      hasNight: hasNight,
      tripCountry: tripCountry,
      tripMeals: tripMeals,
      tripLodging: tripLodging,
    ),
  );
}

String mealLabel(AppLocalizations l, MealStatus s) => switch (s) {
      MealStatus.none => l.mealNone,
      MealStatus.paid => l.mealPaid,
      MealStatus.hotelIncluded => l.mealHotelIncluded,
      MealStatus.representation => l.mealRepresentation,
      MealStatus.transportIncluded => l.mealTransportIncluded,
      MealStatus.unused => l.mealUnused,
    };

/// Dropdown for something a trip sets and a single day can change, like a
/// meal or the lodging. With [inherited] (on a day), the first choice is
/// null: "same as the trip", showing what the trip gives that day.
class TripChoiceField<T extends Object> extends StatelessWidget {
  const TripChoiceField({
    super.key,
    required this.label,
    required this.value,
    this.inherited,
    this.helperText,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final T? inherited;
  final String? helperText;
  final List<T> options;
  final String Function(AppLocalizations l, T option) optionLabel;

  /// Called with null only when [inherited] is set.
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final inherited = this.inherited;
    return DropdownButtonFormField<T?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, helperText: helperText, helperMaxLines: 3),
      items: [
        if (inherited != null)
          DropdownMenuItem(value: null, child: Text(l.sameAsTrip(optionLabel(l, inherited)))),
        for (final o in options) DropdownMenuItem(value: o, child: Text(optionLabel(l, o))),
      ],
      onChanged: onChanged,
    );
  }
}

/// Lodging a whole trip can have; receipts belong to single nights.
const tripLodgingOptions = [LodgingKind.standard, LodgingKind.employerPaid, LodgingKind.none];

String lodgingLabel(AppLocalizations l, LodgingKind k) => switch (k) {
      LodgingKind.standard => l.lodgingStandard,
      LodgingKind.receipt => l.lodgingReceipt,
      LodgingKind.employerPaid => l.lodgingEmployerPaid,
      LodgingKind.none => l.lodgingNone,
    };

class _DayEditSheet extends ConsumerStatefulWidget {
  const _DayEditSheet({
    required this.row,
    required this.hasNight,
    required this.tripCountry,
    required this.tripMeals,
    required this.tripLodging,
  });

  final TripDayRow row;
  final bool hasNight;

  /// The trip's country (Swedish name, "Sverige" for Sweden).
  final String tripCountry;

  /// The trip's meals on this day, used where the day has none of its own.
  final DayMeals tripMeals;

  /// The trip's lodging, used where the night has none of its own.
  final LodgingKind tripLodging;

  @override
  ConsumerState<_DayEditSheet> createState() => _DayEditSheetState();
}

class _DayEditSheetState extends ConsumerState<_DayEditSheet> {
  late TripDayRow _row = widget.row;
  // Created on first use: it needs the locale, and only receipts use it.
  TextEditingController? _costController;
  TextEditingController get _cost => _costController ??=
      TextEditingController(text: oreToInput(widget.row.lodgingCostOre, AppLocalizations.of(context).localeName));

  @override
  void dispose() {
    _costController?.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      _row.copyWith(lodgingCostOre: Value(_row.lodging == LodgingKind.receipt ? parseKronorToOre(_cost.text) : null)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final date = CalendarDate.parse(_row.date);
    final library = ref.watch(rulesLibraryProvider).value;
    final pack = library == null ? null : packForYear(library, date.year);
    final tripCountry = widget.tripCountry;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.md),
        children: [
          Text(formatDayDate(context, date),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.md),
          if (pack != null) ...[
            CountryField(
              label: l.chooseCountry,
              helperText: l.countryDayHelp,
              pack: pack,
              value: _row.countryOverride,
              inherited: tripCountry,
              // Picking the trip's own country clears the override.
              onChanged: (v) => setState(() => _row = _row.copyWith(
                    countryOverride: Value(v == null || _sameCountry(v, tripCountry) ? null : v),
                  )),
            ),
            const SizedBox(height: Space.md),
          ],
          TripChoiceField(
            label: l.breakfast,
            value: _row.breakfast,
            inherited: widget.tripMeals.breakfast,
            options: MealStatus.values,
            optionLabel: mealLabel,
            onChanged: (v) => setState(() => _row = _row.copyWith(breakfast: Value(v))),
          ),
          const SizedBox(height: Space.md),
          TripChoiceField(
            label: l.lunch,
            value: _row.lunch,
            inherited: widget.tripMeals.lunch,
            options: MealStatus.values,
            optionLabel: mealLabel,
            onChanged: (v) => setState(() => _row = _row.copyWith(lunch: Value(v))),
          ),
          const SizedBox(height: Space.md),
          TripChoiceField(
            label: l.dinner,
            value: _row.dinner,
            inherited: widget.tripMeals.dinner,
            options: MealStatus.values,
            optionLabel: mealLabel,
            onChanged: (v) => setState(() => _row = _row.copyWith(dinner: Value(v))),
          ),
          if (widget.hasNight) ...[
            const SizedBox(height: Space.md),
            TripChoiceField(
              label: l.lodging,
              value: _row.lodging,
              inherited: widget.tripLodging,
              options: LodgingKind.values,
              optionLabel: lodgingLabel,
              onChanged: (v) => setState(() => _row = _row.copyWith(lodging: Value(v))),
            ),
            if (_row.lodging == LodgingKind.receipt) ...[
              const SizedBox(height: Space.md),
              TextField(
                controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.lodgingCost, suffixText: l.currencySuffix),
              ),
            ],
          ],
          const SizedBox(height: Space.lg),
          FilledButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
    );
  }
}

bool _sameCountry(String a, String b) =>
    (isSwedenKey(a) && isSwedenKey(b)) || a.trim().toLowerCase() == b.trim().toLowerCase();
