import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../data/repositories/commute_repository.dart';
import '../../l10n/app_localizations.dart';
import '../common/format.dart';
import 'commute_labels.dart';

/// What a calendar day shows.
enum CalendarDayKind {
  /// Counts as a commuting day (in the past or today).
  commute,

  /// A scheduled commute still ahead.
  planned,

  /// Marked as not commuted: vacation, sick, home office.
  dayOff,
  businessTrip,
  holiday,

  /// Not a scheduled day and nothing marked.
  none,
}

class CalendarDay {
  const CalendarDay(this.kind, {this.commute, this.skipped});
  final CalendarDayKind kind;
  final CommuteDay? commute;
  final SkippedCommuteDay? skipped;
}

/// Each date of a calculated year and how to show it. Days after [today]
/// that the schedule would count are "planned".
Map<CalendarDate, CalendarDay> calendarDays(CommuteResult r, CalendarDate today) => {
      for (final s in r.skipped)
        s.date: CalendarDay(
          switch (s.skip) {
            CommuteSkip.publicHoliday => CalendarDayKind.holiday,
            CommuteSkip.businessTrip => CalendarDayKind.businessTrip,
            CommuteSkip.marked => CalendarDayKind.dayOff,
          },
          skipped: s,
        ),
      for (final d in r.days)
        d.date: CalendarDay(d.date.isAfter(today) ? CalendarDayKind.planned : CalendarDayKind.commute, commute: d),
    };

/// One month as a grid, Monday first. Compact for the commuting tab, or
/// interactive: tap a day, or press, hold and drag to pick several.
class CommuteMonthGrid extends StatefulWidget {
  const CommuteMonthGrid({
    super.key,
    required this.year,
    required this.month,
    required this.days,
    required this.today,
    this.compact = false,
    this.onTapDay,
    this.onSelectDays,
  });

  final int year;
  final int month;
  final Map<CalendarDate, CalendarDay> days;
  final CalendarDate today;
  final bool compact;
  final ValueChanged<CalendarDate>? onTapDay;

  /// Called with the dragged range (in date order) when the finger lifts.
  final ValueChanged<List<CalendarDate>>? onSelectDays;

  @override
  State<CommuteMonthGrid> createState() => _CommuteMonthGridState();
}

class _CommuteMonthGridState extends State<CommuteMonthGrid> {
  CalendarDate? _anchor;
  CalendarDate? _current;

  CalendarDate get _first => CalendarDate(widget.year, widget.month, 1);
  int get _lead => _first.weekday - 1;
  int get _length => DateTime.utc(widget.year, widget.month + 1, 0).day;
  int get _rows => ((_lead + _length) / 7).ceil();
  double get _cellHeight => widget.compact ? 30 : 52;

  /// The date under [local], clamped to the month so a drag past either end
  /// still selects up to the first or last day.
  CalendarDate _dateAt(Offset local, double width) {
    final col = (local.dx / (width / 7)).floor().clamp(0, 6);
    final row = (local.dy / _cellHeight).floor().clamp(0, _rows - 1);
    final day = (row * 7 + col - _lead + 1).clamp(1, _length);
    return CalendarDate(widget.year, widget.month, day);
  }

  List<CalendarDate> get _selection {
    final a = _anchor, b = _current;
    if (a == null || b == null) return const [];
    return a.isAfter(b) ? CalendarDate.range(b, a).toList() : CalendarDate.range(a, b).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final selected = _selection.toSet();
    return Column(
      children: [
        Row(
          children: [
            for (var d = 1; d <= 7; d++)
              Expanded(
                child: Text(
                  widget.compact ? weekdayShort(l, d).characters.first.toUpperCase() : weekdayShort(l, d),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.xs),
        LayoutBuilder(
          builder: (context, box) {
            final grid = SizedBox(
              height: _rows * _cellHeight,
              child: Column(
                children: [
                  for (var row = 0; row < _rows; row++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var col = 0; col < 7; col++)
                            Expanded(child: _cell(context, row * 7 + col - _lead + 1, selected)),
                        ],
                      ),
                    ),
                ],
              ),
            );
            if (widget.onTapDay == null && widget.onSelectDays == null) return grid;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.onTapDay == null
                  ? null
                  : (e) => widget.onTapDay!(_dateAt(e.localPosition, box.maxWidth)),
              onLongPressStart: widget.onSelectDays == null
                  ? null
                  : (e) {
                      HapticFeedback.selectionClick();
                      final d = _dateAt(e.localPosition, box.maxWidth);
                      setState(() => _anchor = _current = d);
                    },
              onLongPressMoveUpdate: widget.onSelectDays == null
                  ? null
                  : (e) {
                      final d = _dateAt(e.localPosition, box.maxWidth);
                      if (d != _current) {
                        HapticFeedback.selectionClick();
                        setState(() => _current = d);
                      }
                    },
              onLongPressEnd: widget.onSelectDays == null
                  ? null
                  : (_) {
                      final picked = _selection;
                      widget.onSelectDays!(picked);
                      setState(() => _anchor = _current = null);
                    },
              child: grid,
            );
          },
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, int day, Set<CalendarDate> selected) {
    if (day < 1 || day > _length) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = CalendarDate(widget.year, widget.month, day);
    final kind = widget.days[date]?.kind ?? CalendarDayKind.none;
    final isSelected = selected.contains(date);
    final style = calendarStyle(context, kind);
    return Padding(
      padding: EdgeInsets.all(widget.compact ? 2 : 3),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : style.fill,
          borderRadius: BorderRadius.circular(Radii.base),
          border: date == widget.today
              ? Border.all(color: scheme.primary, width: 2)
              : style.border == null
                  ? null
                  : Border.all(color: style.border!),
        ),
        child: Text(
          '$day',
          style: (widget.compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)?.copyWith(
            color: isSelected ? scheme.onPrimary : style.text,
            fontWeight: kind == CalendarDayKind.commute || date == widget.today ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
  }
}

/// Fill, border and text colour per kind, shared by the grid and legend.
/// Tints follow DESIGN.md and are never the only signal: the legend names
/// every kind and the day sheet says it in words.
({Color? fill, Color? border, Color? text}) calendarStyle(BuildContext context, CalendarDayKind kind) {
  final scheme = Theme.of(context).colorScheme;
  final colors = TraktaColors.of(context);
  return switch (kind) {
    CalendarDayKind.commute => (fill: colors.positive.withValues(alpha: 0.20), border: null, text: scheme.onSurface),
    CalendarDayKind.planned => (fill: null, border: colors.positive.withValues(alpha: 0.4), text: scheme.onSurface),
    CalendarDayKind.dayOff => (fill: colors.warning.withValues(alpha: 0.16), border: null, text: scheme.onSurface),
    CalendarDayKind.businessTrip => (fill: scheme.primary.withValues(alpha: 0.14), border: null, text: scheme.onSurface),
    CalendarDayKind.holiday => (fill: scheme.surfaceContainerHighest, border: null, text: scheme.onSurfaceVariant),
    CalendarDayKind.none => (fill: null, border: null, text: scheme.onSurfaceVariant),
  };
}

String calendarKindLabel(AppLocalizations l, CalendarDayKind k) => switch (k) {
      CalendarDayKind.commute => l.calendarCommute,
      CalendarDayKind.planned => l.calendarPlanned,
      CalendarDayKind.dayOff => l.commuteSkippedMarked,
      CalendarDayKind.businessTrip => l.dayBusinessTrip,
      CalendarDayKind.holiday => l.commuteSkippedHolidays,
      CalendarDayKind.none => l.dayNotScheduled,
    };

/// Names every colour used in the grid.
class CommuteLegend extends StatelessWidget {
  const CommuteLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Wrap(
      spacing: Space.md,
      runSpacing: Space.xs,
      children: [
        for (final k in [
          CalendarDayKind.commute,
          CalendarDayKind.planned,
          CalendarDayKind.dayOff,
          CalendarDayKind.businessTrip,
          CalendarDayKind.holiday,
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(builder: (context) {
                final s = calendarStyle(context, k);
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: s.fill,
                    borderRadius: BorderRadius.circular(3),
                    border: s.border == null ? null : Border.all(color: s.border!),
                  ),
                );
              }),
              const SizedBox(width: Space.xs),
              Text(calendarKindLabel(l, k),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
      ],
    );
  }
}

/// What a day (or several) can be set to. Returns once the change is saved,
/// or when the sheet is dismissed.
Future<void> showDayChoiceSheet(BuildContext context, WidgetRef ref, List<CalendarDate> dates) async {
  if (dates.isEmpty) return;
  final l = AppLocalizations.of(context);
  final title = dates.length == 1
      ? formatDayDate(context, dates.single)
      : '${formatDate(context, dates.first)} – ${formatDate(context, dates.last)} · ${l.daysCount(dates.length)}';
  final choice = await showModalBottomSheet<DayChoice>(
    context: context,
    useSafeArea: true,
    // Sized to its options; the default half-screen cap can hide the last ones.
    isScrollControlled: true,
    builder: (context) => ListView(
      shrinkWrap: true,
      children: [
        ListTile(title: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        ListTile(
          leading: const Icon(Icons.directions_car),
          title: Text(l.dayCommutedOption),
          onTap: () => Navigator.pop(context, const Commuted()),
        ),
        for (final reason in NoCommuteReason.values)
          ListTile(
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(noCommuteReasonLabel(l, reason)),
            onTap: () => Navigator.pop(context, DayOff(reason)),
          ),
        ListTile(
          leading: const Icon(Icons.restart_alt),
          title: Text(l.dayFollowSchedule),
          onTap: () => Navigator.pop(context, const FollowSchedule()),
        ),
      ],
    ),
  );
  if (choice != null) await ref.read(commuteRepositoryProvider).setDays(dates, choice);
}
