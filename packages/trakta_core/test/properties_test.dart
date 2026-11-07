// Property tests : amounts are never negative, a reduction
// never exceeds the day's amount, and adding a meal never increases it.
import 'dart:math';

import 'package:test/test.dart';
import 'package:trakta_core/trakta_core.dart';

import 'helpers.dart';

void main() {
  final lib = library2026();
  final pack = lib.forYear(2026)!;
  final countries = ['Sverige', ...pack.foreignRates.map((r) => r.name)];

  MealStatus randomMeal(Random rnd) => MealStatus.values[rnd.nextInt(MealStatus.values.length)];

  TripInput randomTrip(Random rnd) {
    final start = WallTime.of(2026, 1 + rnd.nextInt(11), 1 + rnd.nextInt(27), rnd.nextInt(24), rnd.nextInt(60));
    final end = start.add(Duration(minutes: 60 + rnd.nextInt(60 * 24 * 12)));
    final country = countries[rnd.nextInt(countries.length)];
    final days = <CalendarDate, DayInput>{};
    for (final d in CalendarDate.range(CalendarDate.of(start), CalendarDate.of(end))) {
      days[d] = DayInput(
        breakfast: randomMeal(rnd),
        lunch: randomMeal(rnd),
        dinner: randomMeal(rnd),
        lodging: LodgingKind.values[rnd.nextInt(LodgingKind.values.length)],
        lodgingCostOre: rnd.nextInt(200000),
      );
    }
    return TripInput(
      departure: start,
      returnTime: end,
      isBusinessTrip: rnd.nextInt(10) > 0,
      outside50km: rnd.nextInt(10) > 0,
      segments: country == 'Sverige' ? const [] : [Segment.stay(country: country, start: start, end: end)],
      days: days,
    );
  }

  test('amounts are never negative and reductions never exceed the day', () {
    final rnd = Random(20260921);
    for (var i = 0; i < 500; i++) {
      final r = TripCalculator.calculate(randomTrip(rnd), lib);
      for (final d in r.days) {
        expect(d.amount.isNegative, isFalse);
        expect(d.mealReduction <= d.beforeMeals, isTrue);
        expect(d.amount <= d.beforeMeals || d.beforeMeals.isZero, isTrue);
      }
      for (final n in r.nights) {
        expect(n.amount.isNegative, isFalse);
      }
    }
  });

  test('adding a free meal never increases the amount', () {
    final rnd = Random(42);
    for (var i = 0; i < 300; i++) {
      final t = randomTrip(rnd);
      final before = TripCalculator.calculate(t, lib);
      final withLunch = TripInput(
        departure: t.departure,
        returnTime: t.returnTime,
        isBusinessTrip: t.isBusinessTrip,
        outside50km: t.outside50km,
        segments: t.segments,
        days: {for (final e in t.days.entries) e.key: e.value.copyWith(lunch: MealStatus.paid)},
      );
      final after = TripCalculator.calculate(withLunch, lib);
      for (var k = 0; k < before.days.length; k++) {
        expect(after.days[k].amount <= before.days[k].amount, isTrue,
            reason: 'day ${before.days[k].date} ${before.days[k].amount} -> ${after.days[k].amount}');
      }
    }
  });
}
