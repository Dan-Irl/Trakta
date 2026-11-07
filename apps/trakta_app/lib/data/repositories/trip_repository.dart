import 'package:drift/drift.dart';
import 'package:trakta_core/trakta_core.dart';

import '../db/database.dart';
import '../time/zones.dart';

/// Breakfast, lunch and dinner for one day.
typedef DayMeals = ({MealStatus breakfast, MealStatus lunch, MealStatus dinner});

/// A trip with everything that belongs to it.
class TripBundle {
  const TripBundle({required this.trip, required this.days, required this.segments, required this.payments});

  final TripRow trip;
  final List<TripDayRow> days;
  final List<TripSegmentRow> segments;
  final List<EmployerPaymentRow> payments;

  DateTime get departureWall => Zones.toWall(trip.startUtc, trip.startTz);
  DateTime get returnWall => Zones.toWall(trip.endUtc, trip.endTz);

  /// The trip's meals as they apply on [date] (ISO), before any change made
  /// on the day itself. A hotel breakfast needs a hotel night before it, so
  /// it does not apply to the departure day.
  DayMeals tripMealsOn(String date) => (
        breakfast: trip.breakfast == MealStatus.hotelIncluded && date == CalendarDate.of(departureWall).toIso()
            ? MealStatus.none
            : trip.breakfast,
        lunch: trip.lunch,
        dinner: trip.dinner,
      );

  /// Lodging the night after [day]: the day's own choice, else the trip's.
  LodgingKind lodgingFor(TripDayRow day) => day.lodging ?? trip.lodging;

  /// The meals that count for [day]: the day's own choice, else the trip's.
  DayMeals mealsFor(TripDayRow day) {
    final t = tripMealsOn(day.date);
    return (
      breakfast: day.breakfast ?? t.breakfast,
      lunch: day.lunch ?? t.lunch,
      dinner: day.dinner ?? t.dinner,
    );
  }

  int paidOre(EmployerPaymentKind kind) =>
      payments.where((p) => p.kind == kind).fold(0, (sum, p) => sum + p.amountOre);
}

/// Input for creating or editing a trip. Times are local wall-clock times.
class TripDraft {
  const TripDraft({
    required this.purpose,
    required this.departure,
    required this.returnTime,
    this.country = swedenName,
    required this.confirmedBusinessTrip,
    required this.confirmed50km,
    required this.employerPaysPerDiem,
    this.nightWorker = false,
    this.breakfast = MealStatus.none,
    this.lunch = MealStatus.none,
    this.dinner = MealStatus.none,
    this.lodging = LodgingKind.standard,
    this.zone = Zones.stockholm,
    this.note = '',
  });

  final String purpose;
  final DateTime departure;
  final DateTime returnTime;

  /// Swedish country name from the rules pack, "Sverige" for Sweden.
  final String country;
  final bool confirmedBusinessTrip;
  final bool confirmed50km;
  final bool employerPaysPerDiem;
  final bool nightWorker;

  /// Meals for every day of the trip unless a day says otherwise.
  final MealStatus breakfast;
  final MealStatus lunch;
  final MealStatus dinner;

  /// Lodging for every night unless a night says otherwise. Not a receipt.
  final LodgingKind lodging;
  final String zone;
  final String note;

  /// Local calendar dates of the trip, ISO `YYYY-MM-DD`.
  List<String> get dates =>
      [for (final d in CalendarDate.range(CalendarDate.of(departure), CalendarDate.of(returnTime))) d.toIso()];

  /// The trip as it will be stored. Also used to preview an unsaved trip.
  TripRow toRow({int id = 0}) => TripRow(
        id: id,
        purpose: purpose.trim(),
        startUtc: Zones.fromWall(departure, zone),
        endUtc: Zones.fromWall(returnTime, zone),
        startTz: zone,
        endTz: zone,
        country: isSwedenKey(country) ? swedenName : country.trim(),
        confirmedBusinessTrip: confirmedBusinessTrip,
        confirmed50km: confirmed50km,
        nightWorker: nightWorker,
        employerPaysPerDiem: employerPaysPerDiem,
        breakfast: breakfast,
        lunch: lunch,
        dinner: dinner,
        lodging: lodging,
        note: note,
        createdUtc: DateTime.now().toUtc(),
      );
}

/// A day with nothing of its own: everything follows the trip.
TripDayRow newTripDay(int tripId, String date) => TripDayRow(
      id: 0,
      tripId: tripId,
      date: date,
    );

class TripRepository {
  TripRepository(this._db);

  final AppDatabase _db;

  Stream<List<TripBundle>> watchAll() async* {
    yield await loadAll();
    await for (final _ in _db.tableUpdates(TableUpdateQuery.onAllTables(
        [_db.trips, _db.tripDays, _db.tripSegments, _db.employerPayments]))) {
      yield await loadAll();
    }
  }

  Future<List<TripBundle>> loadAll() async {
    final trips = await (_db.select(_db.trips)..orderBy([(t) => OrderingTerm.desc(t.startUtc)])).get();
    final days = await _db.select(_db.tripDays).get();
    final segments = await (_db.select(_db.tripSegments)..orderBy([(s) => OrderingTerm.asc(s.startUtc)])).get();
    final payments = await _db.select(_db.employerPayments).get();
    return [
      for (final t in trips)
        TripBundle(
          trip: t,
          days: days.where((d) => d.tripId == t.id).toList()..sort((a, b) => a.date.compareTo(b.date)),
          segments: segments.where((s) => s.tripId == t.id).toList(),
          payments: payments.where((p) => p.tripId == t.id).toList(),
        ),
    ];
  }

  /// Creates or updates a trip and makes sure there is exactly one day row
  /// per local calendar date. [days] (matched by date) are stored with it in
  /// the same transaction, so a trip reviewed day by day is saved in one go.
  /// Returns the trip id.
  Future<int> save(TripDraft draft, {int? id, List<TripDayRow> days = const []}) {
    return _db.transaction(() async {
      final row = draft.toRow().toCompanion(false);
      final int tripId;
      if (id == null) {
        tripId = await _db.into(_db.trips).insert(row.copyWith(id: const Value.absent()));
      } else {
        await (_db.update(_db.trips)..where((t) => t.id.equals(id))).write(row.copyWith(
          id: const Value.absent(),
          createdUtc: const Value.absent(),
          continuesTripId: const Value.absent(),
        ));
        tripId = id;
      }
      await _syncDays(tripId, draft.dates);
      for (final day in days) {
        await (_db.update(_db.tripDays)..where((d) => d.tripId.equals(tripId) & d.date.equals(day.date))).write(
          day.toCompanion(false).copyWith(id: const Value.absent(), tripId: const Value.absent()),
        );
      }
      return tripId;
    });
  }

  Future<void> _syncDays(int tripId, List<String> dates) async {
    final wanted = dates.toSet();
    final existing = await (_db.select(_db.tripDays)..where((d) => d.tripId.equals(tripId))).get();
    final have = {for (final d in existing) d.date};
    await (_db.delete(_db.tripDays)..where((d) => d.tripId.equals(tripId) & d.date.isNotIn(wanted))).go();
    for (final date in wanted.difference(have)) {
      await _db.into(_db.tripDays).insert(TripDaysCompanion.insert(tripId: tripId, date: date));
    }
  }

  Future<void> updateDay(TripDayRow day) => _db.update(_db.tripDays).replace(day);

  Future<void> setPayment(int tripId, EmployerPaymentKind kind, int amountOre) async {
    await _db.transaction(() async {
      await (_db.delete(_db.employerPayments)..where((p) => p.tripId.equals(tripId) & p.kind.equalsValue(kind))).go();
      if (amountOre > 0) {
        await _db.into(_db.employerPayments).insert(
              EmployerPaymentsCompanion.insert(tripId: tripId, kind: kind, amountOre: amountOre),
            );
      }
    });
  }

  Future<void> delete(int tripId) => (_db.delete(_db.trips)..where((t) => t.id.equals(tripId))).go();
}
