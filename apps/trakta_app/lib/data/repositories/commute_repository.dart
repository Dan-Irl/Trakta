import 'package:drift/drift.dart';
import 'package:trakta_core/trakta_core.dart';

import '../db/database.dart';

/// What the user says about one or more days.
sealed class DayChoice {
  const DayChoice();
}

/// Back to the schedule: no change stored for the day.
final class FollowSchedule extends DayChoice {
  const FollowSchedule();
}

/// Commuted that day, scheduled or not.
final class Commuted extends DayChoice {
  const Commuted();
}

/// Did not commute that day, and why.
final class DayOff extends DayChoice {
  const DayOff(this.reason);
  final NoCommuteReason reason;
}

/// Everything the commuting deduction is calculated from.
class CommuteData {
  const CommuteData({required this.routes, required this.days, required this.expenses});

  final List<CommuteRouteRow> routes;
  final List<CommuteDayRow> days;
  final List<CommuteExpenseRow> expenses;

  bool get isEmpty => routes.isEmpty;
}

class CommuteRepository {
  CommuteRepository(this._db);

  final AppDatabase _db;

  Stream<CommuteData> watch() async* {
    yield await load();
    await for (final _ in _db.tableUpdates(
        TableUpdateQuery.onAllTables([_db.commuteRoutes, _db.commuteDays, _db.commuteExpenses]))) {
      yield await load();
    }
  }

  Future<CommuteData> load() async => CommuteData(
        routes: await (_db.select(_db.commuteRoutes)..orderBy([(r) => OrderingTerm.asc(r.id)])).get(),
        days: await (_db.select(_db.commuteDays)..orderBy([(d) => OrderingTerm.asc(d.date)])).get(),
        expenses: await (_db.select(_db.commuteExpenses)
              ..orderBy([(e) => OrderingTerm.desc(e.fromDate), (e) => OrderingTerm.desc(e.id)]))
            .get(),
      );

  Future<int> saveRoute(CommuteRoutesCompanion r) async {
    if (r.id.present) {
      await (_db.update(_db.commuteRoutes)..where((t) => t.id.equals(r.id.value))).write(r);
      return r.id.value;
    }
    return _db.into(_db.commuteRoutes).insert(r.copyWith(createdUtc: Value(DateTime.now().toUtc())));
  }

  Future<void> deleteRoute(int id) => (_db.delete(_db.commuteRoutes)..where((t) => t.id.equals(id))).go();

  /// Marks every date from [from] to [to] (inclusive) as not commuted for
  /// [reason], or clears them back to the schedule when [reason] is null.
  Future<void> markNotCommuted(CalendarDate from, CalendarDate to, NoCommuteReason? reason) {
    return _db.transaction(() async {
      for (final d in CalendarDate.range(from, to)) {
        await _clear(d);
        if (reason != null) {
          await _db.into(_db.commuteDays).insert(
                CommuteDaysCompanion.insert(date: d.toIso(), commuted: false, reason: Value(reason)),
              );
        }
      }
    });
  }

  /// A commute on [date] that the schedule does not have, or with another
  /// distance.
  Future<void> markCommuted(CalendarDate date, {int? routeId, int? oneWayM}) {
    return _db.transaction(() async {
      await _clear(date);
      await _db.into(_db.commuteDays).insert(CommuteDaysCompanion.insert(
            date: date.toIso(),
            commuted: true,
            routeId: Value(routeId),
            oneWayM: Value(oneWayM),
          ));
    });
  }

  /// Applies [choice] to every date in [dates] in one transaction, e.g. the
  /// days dragged over in the calendar.
  Future<void> setDays(Iterable<CalendarDate> dates, DayChoice choice) {
    return _db.transaction(() async {
      for (final d in dates) {
        await _clear(d);
        switch (choice) {
          case FollowSchedule():
            break;
          case Commuted():
            await _db.into(_db.commuteDays).insert(CommuteDaysCompanion.insert(date: d.toIso(), commuted: true));
          case DayOff(:final reason):
            await _db.into(_db.commuteDays).insert(
                  CommuteDaysCompanion.insert(date: d.toIso(), commuted: false, reason: Value(reason)),
                );
        }
      }
    });
  }

  /// Back to the schedule on [date].
  Future<void> clearDay(CalendarDate date) => _clear(date);

  Future<void> _clear(CalendarDate d) => (_db.delete(_db.commuteDays)..where((t) => t.date.equals(d.toIso()))).go();

  Future<int> saveExpense(CommuteExpensesCompanion e) async {
    if (e.id.present) {
      await (_db.update(_db.commuteExpenses)..where((t) => t.id.equals(e.id.value))).write(e);
      return e.id.value;
    }
    return _db.into(_db.commuteExpenses).insert(e.copyWith(createdUtc: Value(DateTime.now().toUtc())));
  }

  Future<void> deleteExpense(int id) => (_db.delete(_db.commuteExpenses)..where((t) => t.id.equals(id))).go();
}

Set<int> parseWorkDays(String s) =>
    {for (final p in s.split(',')) ?int.tryParse(p.trim())};

String formatWorkDays(Set<int> days) => (days.toList()..sort()).join(',');
