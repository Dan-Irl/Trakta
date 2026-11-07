import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../common/async_view.dart';
import '../common/date_time_field.dart';
import 'commute_calendar.dart';
import 'commute_labels.dart';

/// The commuting calendar, month by month. Tap a day to change it; press,
/// hold and drag to change several. Everything else follows the schedule.
class CommuteDaysScreen extends ConsumerStatefulWidget {
  const CommuteDaysScreen({super.key, this.initialMonth});

  /// The month to open on; the current month when null.
  final DateTime? initialMonth;

  @override
  ConsumerState<CommuteDaysScreen> createState() => _CommuteDaysScreenState();
}

class _CommuteDaysScreenState extends ConsumerState<CommuteDaysScreen> {
  late DateTime _month = widget.initialMonth ?? DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int months) => setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = CalendarDate.of(DateTime.now());
    // The whole year, so days ahead show what the schedule will count.
    final result = ref.watch(commuteFullYearProvider(_month.year));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.commuteDaysTitle),
        actions: [
          IconButton(
            tooltip: l.markDaysOff,
            icon: const Icon(Icons.date_range_outlined),
            onPressed: () => showMarkDaysOffSheet(context, initial: CalendarDate(_month.year, _month.month, 1)),
          ),
        ],
      ),
      body: AsyncView(
        value: result,
        builder: (context, r) {
          final days = calendarDays(r, today);
          final inMonth = r.days.where((d) => d.date.month == _month.month);
          final counted = inMonth.where((d) => !d.date.isAfter(today));
          return ListView(
            padding: const EdgeInsets.all(Space.md),
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
                  Expanded(
                    child: Text(
                      MaterialLocalizations.of(context).formatMonthYear(_month),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
                ],
              ),
              const SizedBox(height: Space.sm),
              CommuteMonthGrid(
                year: _month.year,
                month: _month.month,
                days: days,
                today: today,
                onTapDay: (d) => showDayChoiceSheet(context, ref, [d]),
                onSelectDays: (ds) => showDayChoiceSheet(context, ref, ds),
              ),
              const SizedBox(height: Space.md),
              Text(
                [
                  '${l.calendarCommute}: ${l.daysCount(counted.length)}',
                  '${kmText(l, counted.fold(0, (n, d) => n + d.metres))} km',
                ].join(' · '),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: Space.md),
              const CommuteLegend(),
              const SizedBox(height: Space.md),
              Text(l.calendarHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          );
        },
      ),
    );
  }
}

/// Marks a range of days as not commuted, e.g. a vacation.
Future<void> showMarkDaysOffSheet(BuildContext context, {CalendarDate? initial}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _MarkDaysOffSheet(initial: initial ?? CalendarDate.of(DateTime.now())),
  );
}

class _MarkDaysOffSheet extends ConsumerStatefulWidget {
  const _MarkDaysOffSheet({required this.initial});
  final CalendarDate initial;

  @override
  ConsumerState<_MarkDaysOffSheet> createState() => _MarkDaysOffSheetState();
}

class _MarkDaysOffSheetState extends ConsumerState<_MarkDaysOffSheet> {
  late DateTime _from = DateTime(widget.initial.year, widget.initial.month, widget.initial.day);
  late DateTime _to = _from;
  NoCommuteReason _reason = NoCommuteReason.vacation;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.md + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.markDaysOff, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.md),
          DateField(
            label: l.fromDate,
            value: _from,
            onChanged: (v) => setState(() {
              _from = v;
              if (_to.isBefore(_from)) _to = _from;
            }),
          ),
          const SizedBox(height: Space.md),
          DateField(
            label: l.toDate,
            value: _to,
            onChanged: (v) => setState(() => _to = v.isBefore(_from) ? _from : v),
          ),
          const SizedBox(height: Space.md),
          DropdownButtonFormField<NoCommuteReason>(
            initialValue: _reason,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.dayOffReason),
            items: [
              for (final r in NoCommuteReason.values)
                DropdownMenuItem(value: r, child: Text(noCommuteReasonLabel(l, r))),
            ],
            onChanged: (v) => setState(() => _reason = v ?? NoCommuteReason.vacation),
          ),
          const SizedBox(height: Space.lg),
          FilledButton(
            onPressed: () async {
              await ref.read(commuteRepositoryProvider).markNotCommuted(
                    CalendarDate(_from.year, _from.month, _from.day),
                    CalendarDate(_to.year, _to.month, _to.day),
                    _reason,
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}
