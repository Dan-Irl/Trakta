// Repository + calculation tests against an in-memory (unencrypted) database.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakta_app/data/calculation/trip_calculations.dart';
import 'package:trakta_app/data/db/database.dart';
import 'package:trakta_app/data/repositories/trip_repository.dart';
import 'package:trakta_app/data/time/zones.dart';
import 'package:trakta_core/trakta_core.dart';

import 'test_rules.dart';

void main() {
  late AppDatabase db;
  late TripRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TripRepository(db);
  });

  tearDown(() => db.close());

  test('wall time round-trips through UTC across DST (Europe/Stockholm)', () {
    final summer = WallTime.parse('2026-07-01T08:00');
    final winter = WallTime.parse('2026-01-15T08:00');
    expect(Zones.fromWall(summer, Zones.stockholm).hour, 6); // UTC+2
    expect(Zones.fromWall(winter, Zones.stockholm).hour, 7); // UTC+1
    expect(Zones.toWall(Zones.fromWall(summer, Zones.stockholm), Zones.stockholm), summer);
  });

  test('saving a trip creates one day row per date and recalculates (golden #1)', () async {
    final id = await repo.save(TripDraft(
      purpose: 'Kundbesök',
      departure: WallTime.parse('2026-03-02T08:00'),
      returnTime: WallTime.parse('2026-03-06T16:00'),
      confirmedBusinessTrip: true,
      confirmed50km: true,
      employerPaysPerDiem: true,
    ));
    var bundles = await repo.loadAll();
    expect(bundles.single.trip.country, swedenName); // domestic by default
    expect(bundles.single.days.map((d) => d.date), [
      '2026-03-02',
      '2026-03-03',
      '2026-03-04',
      '2026-03-05',
      '2026-03-06',
    ]);
    for (final d in bundles.single.days) {
      await repo.updateDay(d.copyWith(lodging: const Value(LodgingKind.employerPaid)));
    }
    bundles = await repo.loadAll();
    final profile = await db.select(db.profiles).getSingle();
    final calc = TripCalculations.computeAll(bundles, testLibrary(), profile)[id]!;
    expect(calc.result.perDiemTotal, const Ore.kr(1350));
    expect(calc.result.nightTotal, Ore.zero);
    expect(calc.perDiem.box22Deduction, const Ore.kr(1350)); // nothing paid yet

    await repo.setPayment(id, EmployerPaymentKind.perDiem, 135000);
    bundles = await repo.loadAll();
    final paid = TripCalculations.computeAll(bundles, testLibrary(), profile)[id]!;
    expect(paid.perDiem.taxFree, const Ore.kr(1350));
    expect(paid.perDiem.box22Deduction, Ore.zero);
  });

  test('shortening a trip removes day rows outside the new range', () async {
    final draft = TripDraft(
      purpose: 'Mässa',
      departure: WallTime.parse('2026-03-02T08:00'),
      returnTime: WallTime.parse('2026-03-06T16:00'),
      confirmedBusinessTrip: true,
      confirmed50km: true,
      employerPaysPerDiem: true,
    );
    final id = await repo.save(draft);
    await repo.save(
      TripDraft(
        purpose: draft.purpose,
        departure: draft.departure,
        returnTime: WallTime.parse('2026-03-03T20:00'),
        confirmedBusinessTrip: true,
        confirmed50km: true,
        employerPaysPerDiem: true,
      ),
      id: id,
    );
    final bundle = (await repo.loadAll()).single;
    expect(bundle.days.map((d) => d.date), ['2026-03-02', '2026-03-03']);
  });

  test('trip country applies to every day unless a day overrides it', () async {
    TripDraft draft(String country) => TripDraft(
          purpose: 'Mässa',
          departure: WallTime.parse('2026-03-02T07:00'),
          returnTime: WallTime.parse('2026-03-04T20:00'),
          country: country,
          confirmedBusinessTrip: true,
          confirmed50km: true,
          employerPaysPerDiem: true,
        );
    final profile = await db.select(db.profiles).getSingle();
    final id = await repo.save(draft('Tyskland'));
    var bundle = (await repo.loadAll()).single;
    expect(bundle.trip.country, 'Tyskland');
    var calc = TripCalculations.compute(bundle, testLibrary(), profile);
    expect(calc.result.days.map((d) => d.amount), everyElement(const Ore.kr(760)));

    await repo.updateDay(bundle.days.last.copyWith(countryOverride: const Value('Sverige')));
    bundle = (await repo.loadAll()).single;
    calc = TripCalculations.compute(bundle, testLibrary(), profile);
    expect(calc.result.days.map((d) => d.amount), [const Ore.kr(760), const Ore.kr(760), const Ore.kr(300)]);

    // Sweden is stored explicitly, whichever key the caller used.
    await repo.save(draft('SE'), id: id);
    expect((await repo.loadAll()).single.trip.country, swedenName);
  });

  test('trip meals apply to every day unless a day changes them', () async {
    TripDraft draft({MealStatus lunch = MealStatus.none}) => TripDraft(
          purpose: 'Kurs',
          departure: WallTime.parse('2026-03-02T07:00'),
          returnTime: WallTime.parse('2026-03-04T20:00'),
          confirmedBusinessTrip: true,
          confirmed50km: true,
          employerPaysPerDiem: true,
          breakfast: MealStatus.hotelIncluded,
          lunch: lunch,
        );
    final profile = await db.select(db.profiles).getSingle();
    Future<List<Ore>> amounts() async {
      final bundle = (await repo.loadAll()).single;
      return TripCalculations.compute(bundle, testLibrary(), profile).result.days.map((d) => d.amount).toList();
    }

    final id = await repo.save(draft());
    // No hotel night before the departure day, so no hotel breakfast then.
    expect(await amounts(), [const Ore.kr(300), const Ore.kr(240), const Ore.kr(240)]);

    final last = (await repo.loadAll()).single.days.last;
    expect(last.breakfast, isNull); // follows the trip
    await repo.updateDay(last.copyWith(breakfast: const Value(MealStatus.none)));
    expect(await amounts(), [const Ore.kr(300), const Ore.kr(240), const Ore.kr(300)]);

    // Changing the trip reaches every day that has not been changed.
    await repo.save(draft(lunch: MealStatus.paid), id: id);
    expect(await amounts(), [const Ore.kr(195), const Ore.kr(135), const Ore.kr(195)]);
  });

  test('a trip is saved together with its reviewed days', () async {
    final draft = TripDraft(
      purpose: 'Kurs',
      departure: WallTime.parse('2026-03-02T07:00'),
      returnTime: WallTime.parse('2026-03-04T20:00'),
      confirmedBusinessTrip: true,
      confirmed50km: true,
      employerPaysPerDiem: true,
    );
    expect(draft.dates, ['2026-03-02', '2026-03-03', '2026-03-04']);
    await repo.save(draft, days: [
      newTripDay(0, '2026-03-03').copyWith(lunch: const Value(MealStatus.paid)),
      newTripDay(0, '2026-03-09'), // outside the trip: ignored
    ]);
    final bundle = (await repo.loadAll()).single;
    expect(bundle.days.map((d) => d.lunch), [null, MealStatus.paid, null]);
  });

  test('hotel paid by employer for the whole trip: per diem stays, no night allowance', () async {
    final profile = await db.select(db.profiles).getSingle();
    await repo.save(TripDraft(
      purpose: 'Mässa',
      departure: WallTime.parse('2026-03-02T07:00'),
      returnTime: WallTime.parse('2026-03-04T20:00'),
      country: 'Tyskland',
      confirmedBusinessTrip: true,
      confirmed50km: true,
      employerPaysPerDiem: false,
      lodging: LodgingKind.employerPaid,
    ));
    var bundle = (await repo.loadAll()).single;
    var calc = TripCalculations.compute(bundle, testLibrary(), profile);
    expect(calc.result.perDiemTotal, const Ore.kr(3 * 760)); // normalbelopp Germany
    expect(calc.result.nightTotal, Ore.zero);
    expect(calc.perDiem.box22Deduction, const Ore.kr(3 * 760));

    // One night paid by the user, with a receipt.
    await repo.updateDay(bundle.days.first.copyWith(
      lodging: const Value(LodgingKind.receipt),
      lodgingCostOre: const Value(120000),
    ));
    bundle = (await repo.loadAll()).single;
    calc = TripCalculations.compute(bundle, testLibrary(), profile);
    expect(calc.result.nights.map((n) => n.amount), [const Ore.kr(1200), Ore.zero]);
  });

  test('profile row exists after creation', () async {
    final profile = await db.select(db.profiles).getSingle();
    expect(profile.userType, UserType.employee);
  });
}
