// Golden cases for income year 2026 (docs/architecture.md, "Tests").
//
// Each test is named after its source so a reviewer can check it by hand.
// Keep this file unchanged when later years are added; add golden_<year>_test.dart.
//
// Sources:
//   Traktamente: https://www.skatteverket.se/privat/skatter/arbeteochinkomst/traktamente.4.dfe345a107ebcc9baf80006547.html
//   Utlandstraktamente: https://www.skatteverket.se/utlandstraktamente
//   Specifikation Ersättningar för reseräkning v1.4: https://skatteverket.entryscape.net/store/9/resource/2430
import 'package:test/test.dart';
import 'package:trakta_core/trakta_core.dart';

import 'helpers.dart';

void main() {
  late RulesLibrary lib;
  late RulesPack pack;

  setUpAll(() {
    pack = loadPack(2026);
    lib = RulesLibrary([pack]);
  });

  const lunch = DayInput(lunch: MealStatus.paid);

  group('domestic', () {
    test('#1 skv354_eva_mon_0800_fri_1600_hotel_paid', () {
      // Mon 2026-03-02 08:00 → Fri 2026-03-06 16:00, employer pays the hotel.
      final days = {
        for (final x in CalendarDate.range(d('2026-03-02'), d('2026-03-06')))
          x: const DayInput(lodging: LodgingKind.employerPaid),
      };
      final r = TripCalculator.calculate(domesticTrip('2026-03-02T08:00', '2026-03-06T16:00', days: days), lib);
      expect(r.eligible, isTrue);
      expect(r.days.map((x) => x.dayType), [DayType.full, DayType.full, DayType.full, DayType.full, DayType.half]);
      expect(r.perDiemTotal, const Ore.kr(1350));
      expect(r.nights, hasLength(4));
      expect(r.nightTotal, Ore.zero);
    });

    test('#2 skv_traktamente_2026_full_day_lunch', () {
      final r = TripCalculator.calculate(
          domesticTrip('2026-03-02T08:00', '2026-03-04T20:00', days: {d('2026-03-03'): lunch}), lib);
      expect(dayOf(r, '2026-03-03').amount, const Ore.kr(195));
      expect(dayOf(r, '2026-03-03').mealReduction, const Ore.kr(105));
    });

    test('#3 skv_traktamente_2026_full_day_all_meals', () {
      const all = DayInput(breakfast: MealStatus.hotelIncluded, lunch: MealStatus.paid, dinner: MealStatus.paid);
      final r = TripCalculator.calculate(
          domesticTrip('2026-03-02T08:00', '2026-03-04T20:00', days: {d('2026-03-03'): all}), lib);
      expect(dayOf(r, '2026-03-03').amount, const Ore.kr(30));
    });

    test('#4 half_day_breakfast_only_20pct_of_150', () {
      final r = TripCalculator.calculate(
          domesticTrip('2026-03-02T08:00', '2026-03-04T15:00',
              days: {d('2026-03-04'): const DayInput(breakfast: MealStatus.hotelIncluded)}),
          lib);
      final day = dayOf(r, '2026-03-04');
      expect(day.dayType, DayType.half);
      expect(day.amount, const Ore.kr(120));
    });

    test('#7 day_type_departure_exactly_1200_return_exactly_1900_are_half_days', () {
      final r = TripCalculator.calculate(domesticTrip('2026-03-02T12:00', '2026-03-04T19:00'), lib);
      expect(r.days.map((x) => x.dayType), [DayType.half, DayType.full, DayType.half]);
      expect(r.perDiemTotal, const Ore.kr(150 + 300 + 150));
    });

    test('#7b departure_1159_return_1901_are_full_days', () {
      final r = TripCalculator.calculate(domesticTrip('2026-03-02T11:59', '2026-03-04T19:01'), lib);
      expect(r.days.map((x) => x.dayType), [DayType.full, DayType.full, DayType.full]);
    });

    test('#8 day_trip_without_night_is_not_eligible', () {
      final r = TripCalculator.calculate(domesticTrip('2026-03-02T06:00', '2026-03-02T23:00'), lib);
      expect(r.eligible, isFalse);
      expect(r.eligibilityReasons.map((x) => x.code), contains(ReasonCode.notEligibleNoOvernight));
      expect(r.days.every((x) => x.amount == Ore.zero), isTrue);
      expect(r.total, Ore.zero);
    });

    test('#8b trip_ending_0559_does_not_cover_the_night', () {
      final r = TripCalculator.calculate(domesticTrip('2026-03-02T18:00', '2026-03-03T05:59'), lib);
      expect(r.eligible, isFalse);
    });

    test('#8c not_business_trip_or_within_50km_is_not_eligible', () {
      final base = domesticTrip('2026-03-02T08:00', '2026-03-04T20:00');
      final t = TripInput(
          departure: base.departure, returnTime: base.returnTime, isBusinessTrip: true, outside50km: false);
      final r = TripCalculator.calculate(t, lib);
      expect(r.eligible, isFalse);
      expect(r.total, Ore.zero);
    });
  });

  group('foreign', () {
    test('#11 skv_utlandstraktamente_2026_france_lunch_297_50_rounds_to_298', () {
      final t = TripInput(
        departure: w('2026-03-02T07:00'),
        returnTime: w('2026-03-05T20:00'),
        isBusinessTrip: true,
        outside50km: true,
        segments: [
          Segment.sweden(start: w('2026-03-02T07:00'), end: w('2026-03-02T09:00')),
          Segment.transit(start: w('2026-03-02T09:00'), end: w('2026-03-02T11:30')),
          Segment.stay(country: 'Frankrike', start: w('2026-03-02T11:30'), end: w('2026-03-05T16:00')),
          Segment.transit(start: w('2026-03-05T16:00'), end: w('2026-03-05T18:30')),
          Segment.sweden(start: w('2026-03-05T18:30'), end: w('2026-03-05T20:00')),
        ],
        days: {d('2026-03-03'): lunch},
      );
      final day = dayOf(TripCalculator.calculate(t, lib), '2026-03-03');
      expect(day.country, isA<ForeignCountry>());
      expect(day.mealReduction, const Ore.kr(298));
      expect(day.amount, const Ore.kr(552));
    });

    test('#12 country_rule_copenhagen_flight_time_excluded', () {
      final t = TripInput(
        departure: w('2026-03-02T07:00'),
        returnTime: w('2026-03-04T20:00'),
        isBusinessTrip: true,
        outside50km: true,
        segments: [
          Segment.sweden(start: w('2026-03-02T07:00'), end: w('2026-03-02T09:00')),
          Segment.transit(start: w('2026-03-02T09:00'), end: w('2026-03-02T10:10')),
          Segment.stay(country: 'Danmark', start: w('2026-03-02T10:10'), end: w('2026-03-04T18:00')),
          Segment.transit(start: w('2026-03-04T18:00'), end: w('2026-03-04T19:10')),
          Segment.sweden(start: w('2026-03-04T19:10'), end: w('2026-03-04T20:00')),
        ],
      );
      final r = TripCalculator.calculate(t, lib);
      final day = dayOf(r, '2026-03-02');
      expect(day.dayType, DayType.full);
      expect((day.country! as ForeignCountry).rate.name, 'Danmark');
      expect(day.amount, const Ore.kr(1226));
      // Return day: 06:00–18:00 in Denmark beats 50 min in Sweden.
      expect((dayOf(r, '2026-03-04').country! as ForeignCountry).rate.name, 'Danmark');
    });

    test('#13 international_transit_whole_day_gets_domestic_full_day', () {
      final t = TripInput(
        departure: w('2026-03-01T20:00'),
        returnTime: w('2026-03-06T20:00'),
        isBusinessTrip: true,
        outside50km: true,
        segments: [
          Segment.sweden(start: w('2026-03-01T20:00'), end: w('2026-03-01T22:00')),
          Segment.transit(start: w('2026-03-01T22:00'), end: w('2026-03-03T02:00')),
          Segment.stay(country: 'USA', start: w('2026-03-03T02:00'), end: w('2026-03-06T12:00')),
          Segment.transit(start: w('2026-03-06T12:00'), end: w('2026-03-06T19:00')),
          Segment.sweden(start: w('2026-03-06T19:00'), end: w('2026-03-06T20:00')),
        ],
      );
      final day = dayOf(TripCalculator.calculate(t, lib), '2026-03-02');
      expect(day.country, isA<InternationalTransitDay>());
      expect(day.amount, const Ore.kr(300));
    });

    test('#14 night_in_germany_standard_is_half_normalbelopp', () {
      final t = TripInput(
        departure: w('2026-03-02T07:00'),
        returnTime: w('2026-03-03T20:00'),
        isBusinessTrip: true,
        outside50km: true,
        segments: [
          Segment.sweden(start: w('2026-03-02T07:00'), end: w('2026-03-02T09:00')),
          Segment.transit(start: w('2026-03-02T09:00'), end: w('2026-03-02T11:00')),
          Segment.stay(country: 'Tyskland', start: w('2026-03-02T11:00'), end: w('2026-03-03T17:00')),
          Segment.transit(start: w('2026-03-03T17:00'), end: w('2026-03-03T19:00')),
          Segment.sweden(start: w('2026-03-03T19:00'), end: w('2026-03-03T20:00')),
        ],
      );
      final r = TripCalculator.calculate(t, lib);
      expect(r.nights, hasLength(1));
      expect(r.nights.single.amount, const Ore.kr(380));
    });

    test('#15 domestic_night_receipt_120_wins_even_if_lower', () {
      final r = TripCalculator.calculate(
        domesticTrip('2026-03-02T08:00', '2026-03-03T20:00',
            days: {d('2026-03-02'): const DayInput(lodging: LodgingKind.receipt, lodgingCostOre: 12000)}),
        lib,
      );
      expect(r.nights.single.amount, const Ore.kr(120));
    });

    test('#15b domestic_night_standard_is_150', () {
      final r = TripCalculator.calculate(domesticTrip('2026-03-02T08:00', '2026-03-03T20:00'), lib);
      expect(r.nights.single.amount, const Ore.kr(150));
    });

    test('#16 skv_2026_list_redirects_gronland_iran_nigeria', () {
      expect(pack.rateFor('Grönland').rate.kr, 1226);
      expect(pack.rateFor('grönland ').rate.kr, 1226);
      expect(pack.rateFor('GL').rate.kr, 1226);
      expect(pack.rateFor('Iran').rate.kr, 470);
      expect(pack.rateFor('Nigeria').rate.kr, 470);
      expect(pack.rateFor('Nigeria').isFallback, isFalse);
      expect(pack.rateFor('Atlantis').isFallback, isTrue);
      expect(pack.rateFor('Atlantis').rate.kr, 470);
    });

    test('#16b sample_2026_values_from_readme', () {
      const expected = {
        'Danmark': 1226,
        'Finland': 968,
        'Frankrike': 850,
        'Tyskland': 760,
        'Norge': 1054,
        'Schweiz': 1332,
        'Storbritannien och Nordirland': 901,
        'USA': 1049,
      };
      for (final e in expected.entries) {
        expect(pack.rateFor(e.key).rate.kr, e.value, reason: e.key);
      }
    });

    test('tie_between_countries_asks_the_user', () {
      final t = TripInput(
        departure: w('2026-03-02T06:00'),
        returnTime: w('2026-03-04T20:00'),
        isBusinessTrip: true,
        outside50km: true,
        segments: [
          Segment.stay(country: 'Norge', start: w('2026-03-02T06:00'), end: w('2026-03-02T15:00')),
          Segment.stay(country: 'Finland', start: w('2026-03-02T15:00'), end: w('2026-03-04T20:00')),
        ],
      );
      final r = TripCalculator.calculate(t, lib);
      final day = dayOf(r, '2026-03-02');
      expect(day.status, ResultStatus.needsCountryChoice);
      expect((day.country! as AmbiguousCountry).candidates, ['Finland', 'Norge']);
      expect(r.isComplete, isFalse);

      final chosen = TripInput(
        departure: t.departure,
        returnTime: t.returnTime,
        isBusinessTrip: true,
        outside50km: true,
        segments: t.segments,
        days: {d('2026-03-02'): const DayInput(countryOverride: 'Norge')},
      );
      expect(dayOf(TripCalculator.calculate(chosen, lib), '2026-03-02').amount, const Ore.kr(1054));
    });

    test('whole_trip_country_with_day_overrides_including_the_night_after', () {
      final t = TripInput(
        departure: w('2026-03-02T07:00'),
        returnTime: w('2026-03-04T20:00'),
        isBusinessTrip: true,
        outside50km: true,
        segments: [Segment.stay(country: 'Tyskland', start: w('2026-03-02T07:00'), end: w('2026-03-04T20:00'))],
        days: {
          d('2026-03-03'): const DayInput(countryOverride: 'Danmark'),
          d('2026-03-04'): const DayInput(countryOverride: 'Sverige'),
        },
      );
      final r = TripCalculator.calculate(t, lib);
      expect((dayOf(r, '2026-03-02').country! as ForeignCountry).rate.name, 'Tyskland');
      expect(dayOf(r, '2026-03-02').amount, const Ore.kr(760));
      expect(dayOf(r, '2026-03-03').amount, const Ore.kr(1226));
      expect(dayOf(r, '2026-03-04').country, isA<DomesticCountry>());
      expect(dayOf(r, '2026-03-04').amount, const Ore.kr(300));
      // Night after 2 March follows the trip (Germany), after 3 March the override (Denmark).
      expect(r.nights.map((n) => n.amount), [const Ore.kr(380), const Ore.kr(613)]);
    });
  });

  group('mileage', () {
    const own = VehicleInput(ownership: Ownership.own, powertrain: Powertrain.fossil);
    MileageInput trip(String date, int km) =>
        MileageInput(date: d(date), distanceMetres: km * 1000, isBusiness: true);

    test('#17 own_car_486km_is_1215kr', () {
      expect(MileageCalculator.calculate(trip('2026-03-02', 486), own, lib).amount, const Ore.kr(1215));
    });

    test('#18 electric_company_car_486km_is_461_70kr', () {
      const v = VehicleInput(ownership: Ownership.company, powertrain: Powertrain.electric);
      expect(MileageCalculator.calculate(trip('2026-03-02', 486), v, lib).amount, const Ore(46170));
    });

    test('#19 petrol_company_car_employer_pays_fuel_is_0', () {
      const v = VehicleInput(ownership: Ownership.company, powertrain: Powertrain.fossil, employerPaysFuel: true);
      expect(MileageCalculator.calculate(trip('2026-03-02', 486), v, lib).amount, Ore.zero);
    });

    test('#20 plugin_hybrid_workplace_charging_rule_from_2026_07_01', () {
      const v = VehicleInput(
        ownership: Ownership.company,
        powertrain: Powertrain.pluginHybrid,
        employerPaysFuel: true,
        onlyWorkplaceChargingFromEmployer: true,
      );
      expect(MileageCalculator.calculate(trip('2026-06-30', 100), v, lib).amount, Ore.zero);
      expect(MileageCalculator.calculate(trip('2026-07-01', 100), v, lib).amount, const Ore.kr(120));
    });

    test('private_trip_is_logged_but_not_reimbursed', () {
      final e = MileageInput(date: d('2026-03-02'), distanceMetres: 10000, isBusiness: false);
      expect(MileageCalculator.calculate(e, own, lib).amount, Ore.zero);
    });

    test('no_pack_for_year_asks_for_update', () {
      final r = MileageCalculator.calculate(trip('2031-03-02', 10), own, lib);
      expect(r.noRulesForYear, isTrue);
    });
  });

  group('employer payment', () {
    test('#21 avdragslexikon_paid_250_for_300_full_day', () {
      final s = EmployerSettlement.settle(
          standard: const Ore.kr(300), paid: const Ore.kr(250), kind: EmployerPaymentKind.perDiem);
      expect(s.taxFree, const Ore.kr(250));
      expect(s.box12Income, const Ore.kr(250));
      expect(s.box22Deduction, const Ore.kr(300));
      expect(s.netDeduction, const Ore.kr(50));
      expect(s.taxableExcess, Ore.zero);
    });

    test('paid_above_standard_excess_is_taxable', () {
      final s = EmployerSettlement.settle(
          standard: const Ore.kr(300), paid: const Ore.kr(400), kind: EmployerPaymentKind.perDiem);
      expect(s.taxFree, const Ore.kr(300));
      expect(s.taxableExcess, const Ore.kr(100));
      expect(s.box22Deduction, Ore.zero);
    });

    test('car_allowance_below_standard_no_deduction_avdragslexikon_t', () {
      // 100 km in an own car: standard 250 kr; the employer paid 18 kr/mil = 180 kr.
      final r = EmployerSettlement.settle(
        standard: const Ore.kr(250),
        paid: const Ore.kr(180),
        kind: EmployerPaymentKind.mileage,
        userType: UserType.employee,
      );
      expect(r.taxFree, const Ore.kr(180));
      expect((r.box12Income, r.box22Deduction, r.taxableExcess), (Ore.zero, Ore.zero, Ore.zero));
      expect(r.reasons.single.code, ReasonCode.carAllowanceNoDeduction);
      expect(r.reasons.single.source, Sources.avdragslexikonT);
    });

    test('nothing_paid_deduct_standard', () {
      final s = EmployerSettlement.settle(standard: const Ore.kr(300), paid: Ore.zero, kind: EmployerPaymentKind.perDiem);
      expect(s.box22Deduction, const Ore.kr(300));
    });

    test('sole_trader_gets_deduction_basis', () {
      final s = EmployerSettlement.settle(
          standard: const Ore.kr(300), paid: Ore.zero, kind: EmployerPaymentKind.perDiem, userType: UserType.soleTrader);
      expect(s.businessDeduction, const Ore.kr(300));
      expect(s.box22Deduction, Ore.zero);
    });
  });

  group('rules packs', () {
    test('no_pack_for_year_shows_update_prompt', () {
      final r = TripCalculator.calculate(domesticTrip('2031-03-02T08:00', '2031-03-04T20:00'), lib);
      expect(r.missingYears, {2031});
      expect(r.isComplete, isFalse);
    });
  });
}
