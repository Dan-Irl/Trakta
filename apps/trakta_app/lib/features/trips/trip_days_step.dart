import 'package:flutter/material.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/tokens.dart';
import '../../data/calculation/trip_calculations.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../common/format.dart';
import '../common/reason_text.dart';
import 'day_edit_sheet.dart';
import 'day_summary.dart';
import 'trip_detail_screen.dart' show TripBanner, TripSummaryCard;

/// Step 2 of creating a trip: every day the trip gives, calculated from the
/// trip's details, so single days can be changed before anything is saved.
class TripDaysStep extends StatelessWidget {
  const TripDaysStep({super.key, required this.calc, required this.onDayChanged});

  /// The unsaved trip, calculated.
  final TripCalculation calc;
  final ValueChanged<TripDayRow> onDayChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = calc.result;
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.sm),
          child: Text(l.reviewDaysHelp),
        ),
        if (r.missingYears.isNotEmpty) TripBanner(text: l.updateAppForYear(r.missingYears.join(', ')), error: true),
        if (!r.eligible)
          TripBanner(
            text: [l.notEligibleTitle, ...r.eligibilityReasons.map((e) => '• ${reasonText(l, e)}')].join('\n'),
          ),
        TripSummaryCard(calc: calc),
        for (final day in r.days) _DayTile(calc: calc, day: day, onChanged: onDayChanged),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.calc, required this.day, required this.onChanged});

  final TripCalculation calc;
  final DayResult day;
  final ValueChanged<TripDayRow> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final row = calc.bundle.days.firstWhere((d) => d.date == day.date.toIso());
    final night = calc.result.nights.where((n) => n.evening == day.date).firstOrNull;
    final subtitle = [
      daySubtitle(l, calc, day),
      if (hasOwnChanges(row)) l.dayChanged,
    ].where((s) => s.isNotEmpty).join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        title: Text(formatDayDate(context, day.date)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(context.money(day.amount), style: theme.textTheme.titleMedium),
                if (night != null) Text('+ ${context.money(night.amount)}', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(width: Space.xs),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () async {
          final changed = await showDayEditSheet(
            context,
            row: row,
            hasNight: night != null,
            tripCountry: calc.bundle.trip.country,
            tripMeals: calc.bundle.tripMealsOn(row.date),
            tripLodging: calc.bundle.trip.lodging,
          );
          if (changed != null) onChanged(changed);
        },
      ),
    );
  }
}
