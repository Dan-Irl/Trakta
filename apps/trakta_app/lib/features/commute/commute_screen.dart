import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../data/db/database.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/commute_repository.dart';
import '../../data/repositories/mileage_repository.dart';
import '../../l10n/app_localizations.dart';
import '../common/async_view.dart';
import '../common/format.dart';
import '../common/note_card.dart';
import '../common/summary_widgets.dart';
import 'commute_calendar.dart';
import 'commute_labels.dart';

/// Reseavdrag (resor till och från arbetet, box 2.1): the year's commuting
/// days from a schedule, the costs, and how close they are to the limit.
/// Business trips remove days; business driving decides parking.
class CommuteScreen extends ConsumerStatefulWidget {
  const CommuteScreen({super.key});

  @override
  ConsumerState<CommuteScreen> createState() => _CommuteScreenState();
}

class _CommuteScreenState extends ConsumerState<CommuteScreen> {
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(commuteDataProvider);
    final result = ref.watch(commuteResultProvider(_year));
    final now = DateTime.now().year;
    final years = data.hasValue && data.requireValue.routes.isNotEmpty
        ? [
            for (var y = now; y >= data.requireValue.routes.map((r) => CalendarDate.parse(r.startDate).year).reduce((a, b) => a < b ? a : b); y--)
              y,
          ]
        : [now];
    final hasRoutes = data.hasValue && data.requireValue.routes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navCommute),
        actions: [
          if (years.length > 1)
            PopupMenuButton<int>(
              tooltip: l.incomeYear,
              initialValue: _year,
              onSelected: (y) => setState(() => _year = y),
              itemBuilder: (context) => [for (final y in years) PopupMenuItem(value: y, child: Text('$y'))],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Row(children: [Text('$_year'), const Icon(Icons.arrow_drop_down)]),
              ),
            ),
        ],
      ),
      floatingActionButton: !data.hasValue
          ? null
          : hasRoutes
              ? FloatingActionButton.extended(
                  onPressed: () => context.go('/commute/cost/new'),
                  icon: const Icon(Icons.add),
                  label: Text(l.addCost),
                )
              : FloatingActionButton.extended(
                  onPressed: () => context.go('/commute/route/new'),
                  icon: const Icon(Icons.add_road),
                  label: Text(l.setUpCommute),
                ),
      body: AsyncView(
        value: data,
        builder: (context, data) {
          if (data.isEmpty) return const _Intro();
          return AsyncView(
            value: result,
            builder: (context, r) => ListView(
              padding: const EdgeInsets.only(top: Space.sm, bottom: Space.fabClearance),
              children: [
                _CalendarCard(year: r.year),
                if (r.year == DateTime.now().year) const _TodayCard(),
                _Box21Card(result: r, fullYear: r.year == DateTime.now().year ? ref.watch(commuteFullYearProvider(r.year)).value : null),
                if (r.parkingEntered > Ore.zero) _ParkingCard(result: r),
                _CostsCard(result: r, data: data),
                _RoutesCard(data: data),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shown before the first route: what commuting is, what counts, and how it
/// relates to business driving.
class _Intro extends ConsumerWidget {
  const _Intro();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rules = ref.watch(rulesLibraryProvider).value?.forYear(DateTime.now().year)?.commute;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.fabClearance),
      children: [
        NoteCard(title: l.commuteIntroTitle, bullets: [l.commuteIntroWhat]),
        if (rules != null) ...[
          const SizedBox(height: Space.md),
          NoteCard(
            title: l.commuteCountsTitle,
            bullets: [
              l.commuteCountsMileage,
              l.commuteCountsFees,
              l.commuteCountsParking('${rules.parking.minServiceMil}', '${rules.parking.minServiceDaysForServiceDays}'),
            ],
            footer: l.commuteThresholdNote(context.money(Ore.kr(rules.thresholdKr))),
          ),
        ],
      ],
    );
  }
}

class _Box21Card extends StatelessWidget {
  const _Box21Card({required this.result, this.fullYear});
  final CommuteResult result;

  /// The current year on the schedule to 31 December.
  final CommuteResult? fullYear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final r = result;
    final positive = TraktaColors.of(context).positive;
    final progress = r.threshold.isZero ? 0.0 : (r.total.value / r.threshold.value).clamp(0.0, 1.0);
    return SummaryCard(
      children: [
        Text(l.commuteBox21('${r.year}'), style: text.titleSmall),
        const SizedBox(height: Space.xs),
        Text(context.money(r.total), style: text.displaySmall),
        const SizedBox(height: Space.sm),
        if (r.noRules)
          Text(l.commuteNoRules('${r.year}'), style: TextStyle(color: Theme.of(context).colorScheme.error))
        else ...[
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(Radii.base),
            color: r.deductible > Ore.zero ? positive : null,
          ),
          const SizedBox(height: Space.sm),
          r.deductible > Ore.zero
              ? Text(
                  l.commuteAboveThreshold(context.money(r.deductible), context.money(r.threshold)),
                  style: text.bodyMedium?.copyWith(color: positive),
                )
              : Text(l.commuteBelowThreshold(context.money(r.threshold - r.total), context.money(r.threshold))),
          if (fullYear case final f?) ...[
            const SizedBox(height: Space.xs),
            Text(
              l.commuteProjection(context.money(f.total), context.money(f.deductible)),
              style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ],
    );
  }
}

/// The cross-type requirement: commuting parking counts only after enough
/// business driving with the same car.
class _ParkingCard extends ConsumerWidget {
  const _ParkingCard({required this.result});
  final CommuteResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final vehicles = {for (final v in ref.watch(vehiclesProvider).value ?? const <VehicleRow>[]) v.id: v};
    final colors = TraktaColors.of(context);
    return SummaryCard(
      title: l.parkingTitle,
      icon: Icons.local_parking,
      children: [
        for (final p in result.parking.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  p.status == ParkingStatus.notMet ? Icons.error_outline : Icons.check_circle_outline,
                  color: p.status == ParkingStatus.notMet ? colors.warning : colors.positive,
                ),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(_status(l, p, vehicles[p.vehicleId]?.displayName ?? '—'))),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/mileage'),
            icon: const Icon(Icons.directions_car_outlined),
            label: Text(l.openBusinessDriving),
          ),
        ),
      ],
    );
  }

  String _status(AppLocalizations l, ParkingCheck p, String car) {
    final mil = '${p.serviceMetres ~/ 10000}';
    final days = '${p.serviceDays}';
    return switch (p.status) {
      ParkingStatus.notMet => l.parkingStatusNotMet(
          car, mil, '${p.rules.minServiceMil}', days, '${p.rules.minServiceDaysForServiceDays}'),
      ParkingStatus.serviceDaysOnly => l.parkingStatusServiceDays(car, mil, days, '${p.rules.minServiceDaysForAllDays}'),
      ParkingStatus.allDays => l.parkingStatusAllDays(car, mil, days),
    };
  }
}

/// This month at a glance; tapping opens the full calendar.
class _CalendarCard extends ConsumerWidget {
  const _CalendarCard({required this.year});
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = CalendarDate.of(now);
    // The current month, or December when looking at an earlier year.
    final month = year == now.year ? now.month : 12;
    final full = ref.watch(commuteFullYearProvider(year)).value;
    final soFar = ref.watch(commuteResultProvider(year)).value;
    final monthLabel = MaterialLocalizations.of(context).formatMonthYear(DateTime(year, month));
    final route = '/commute/days?month=$year-${month.toString().padLeft(2, '0')}';
    final inMonth = soFar?.days.where((d) => d.date.month == month).length ?? 0;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: Space.sm),
                  Expanded(child: Text(monthLabel, style: theme.textTheme.titleMedium)),
                  Text('${l.calendarCommute}: ${l.daysCount(inMonth)}', style: theme.textTheme.bodyMedium),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: Space.sm),
              if (full == null)
                const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              else
                CommuteMonthGrid(
                  year: year,
                  month: month,
                  days: calendarDays(full, today),
                  today: today,
                  compact: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today in one tap: commuted, or why not. The current answer is
/// highlighted; the menu button opens every option.
class _TodayCard extends ConsumerWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = CalendarDate.of(DateTime.now());
    final r = ref.watch(commuteResultProvider(today.year)).value;
    // What the user chose wins, also on a day the schedule does not count
    // (a weekend marked as home office changes nothing, but should show).
    final mine = ref.watch(commuteDataProvider).value?.days.where((d) => d.date == today.toIso()).firstOrNull;
    final skipped = r?.skipped.where((s) => s.date == today).firstOrNull;
    final commuted = mine != null ? mine.commuted : r?.days.any((d) => d.date == today) ?? false;
    final reason = mine != null ? (mine.commuted ? null : mine.reason ?? NoCommuteReason.other) : null;
    final status = commuted
        ? l.calendarCommute
        : reason != null
            ? noCommuteReasonLabel(l, reason)
            : switch (skipped?.skip) {
            CommuteSkip.publicHoliday => holidayName(l, skipped!.holiday!),
            CommuteSkip.businessTrip => l.dayBusinessTrip,
            CommuteSkip.marked => noCommuteReasonLabel(l, reason ?? NoCommuteReason.other),
            null => l.dayNotScheduled,
          };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.xs, Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: l.todayTitle(formatDayDate(context, today)), style: theme.textTheme.titleMedium),
                      TextSpan(
                        text: '  ·  $status',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ]),
                  ),
                ),
                IconButton(
                  tooltip: l.chipMore,
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () => showDayChoiceSheet(context, ref, [today]),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: Row(
                children: [
                  for (final (label, icon, choice, selected) in [
                    (l.todayCommuted, Icons.directions_car_outlined, const Commuted(), commuted),
                    (l.chipHome, Icons.home_outlined, const DayOff(NoCommuteReason.homeOffice),
                        reason == NoCommuteReason.homeOffice),
                    (l.reasonSick, Icons.sick_outlined, const DayOff(NoCommuteReason.sick),
                        reason == NoCommuteReason.sick),
                    (l.reasonVacation, Icons.beach_access_outlined, const DayOff(NoCommuteReason.vacation),
                        reason == NoCommuteReason.vacation),
                  ])
                    Expanded(
                      child: _TodayButton(
                        label: label,
                        icon: icon,
                        selected: selected,
                        onTap: () => ref.read(commuteRepositoryProvider).setDays([today], choice),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onPrimary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.base),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.base),
          onTap: selected ? null : onTap,
          child: Semantics(
            selected: selected,
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Column(
                children: [
                  Icon(selected ? Icons.check : icon, color: color, size: 22),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CostsCard extends StatelessWidget {
  const _CostsCard({required this.result, required this.data});
  final CommuteResult result;
  final CommuteData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = result;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final byKind = <CommuteExpenseKind, ({Ore entered, Ore counted})>{};
    for (final e in r.expenses) {
      final prev = byKind[e.kind] ?? (entered: Ore.zero, counted: Ore.zero);
      byKind[e.kind] = (entered: prev.entered + e.entered, counted: prev.counted + e.counted);
    }
    return SummaryCard(
      title: l.costsTitle,
      icon: Icons.receipt_long_outlined,
      children: [
        AmountRow(label: l.commuteMileage(kmText(l, r.metres)), amount: r.mileage),
        for (final kind in CommuteExpenseKind.values)
          if (byKind[kind] case final k?) ...[
            AmountRow(label: expenseKindLabel(l, kind), amount: k.counted),
            if (k.counted != k.entered)
              Text(
                l.expParkingNotCounted(context.money(k.entered), context.money(k.counted)),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
              ),
          ],
        const Divider(),
        AmountRow(label: l.total, amount: r.total, total: true),
        const SizedBox(height: Space.sm),
        if (data.expenses.isEmpty)
          Text(l.noCostsYet, style: TextStyle(color: muted))
        else
          for (final e in data.expenses) _ExpenseTile(row: e),
      ],
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({required this.row});
  final CommuteExpenseRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final docs = ref.watch(attachmentCountsProvider(AttachmentOwner.commuteExpense)).value?[row.id] ?? 0;
    final amount = context.money(Ore(row.amountOre));
    final from = CalendarDate.parse(row.fromDate);
    final when = switch (row.recurrence) {
      ExpenseRecurrence.once => l.costOnce(amount, formatDate(context, from)),
      ExpenseRecurrence.monthly => l.costPerMonth(amount),
      ExpenseRecurrence.perCommuteDay => l.costPerDay(amount),
    };
    final period = row.recurrence == ExpenseRecurrence.once
        ? null
        : '${formatDate(context, from)} – ${row.toDate == null ? '' : formatDate(context, CalendarDate.parse(row.toDate!))}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(expenseKindLabel(l, row.kind)),
      subtitle: Text(
        [when, ?period, if (row.note.isNotEmpty) row.note, if (docs > 0) l.documentsCount(docs)].join('\n'),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('/commute/cost/${row.id}'),
    );
  }
}

class _RoutesCard extends ConsumerWidget {
  const _RoutesCard({required this.data});
  final CommuteData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final vehicles = {for (final v in ref.watch(vehiclesProvider).value ?? const <VehicleRow>[]) v.id: v};
    final minKm = ref.watch(rulesLibraryProvider).value?.forYear(DateTime.now().year)?.commute.carMinKm ?? 5;
    return SummaryCard(
      title: l.routesTitle,
      icon: Icons.route_outlined,
      children: [
        for (final r in data.routes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(r.label.isEmpty ? '—' : r.label),
            subtitle: Text([
              l.routeSummary(kmText(l, r.oneWayM), weekdaysLabel(l, parseWorkDays(r.workDays))),
              ?vehicles[r.vehicleId]?.displayName,
              if (r.oneWayM < minKm * 1000) l.routeTooShort('$minKm'),
            ].join('\n')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/commute/route/${r.id}'),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/commute/route/new'),
            icon: const Icon(Icons.add),
            label: Text(l.addRoute),
          ),
        ),
      ],
    );
  }
}
