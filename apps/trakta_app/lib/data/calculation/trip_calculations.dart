import 'package:trakta_core/trakta_core.dart';

import '../db/database.dart';
import '../repositories/trip_repository.dart';
import '../time/zones.dart';

/// Result of running the pure engine for one stored trip, plus the comparison
/// with what the employer paid. Nothing here is stored; it is recomputed on
/// every change.
class TripCalculation {
  const TripCalculation({
    required this.bundle,
    required this.input,
    required this.result,
    required this.perDiem,
    required this.nights,
  });

  final TripBundle bundle;
  final TripInput input;
  final TripResult result;
  final Settlement perDiem;
  final Settlement nights;
}

abstract final class TripCalculations {
  static Map<int, TripCalculation> computeAll(List<TripBundle> bundles, RulesLibrary library, ProfileRow profile) =>
      {for (final b in bundles) b.trip.id: compute(b, library, profile)};

  static TripInput toInput(TripBundle b, ProfileRow profile) {
    final t = b.trip;
    final departure = b.departureWall;
    return TripInput(
      departure: departure,
      returnTime: b.returnWall,
      isBusinessTrip: t.confirmedBusinessTrip,
      outside50km: t.confirmed50km,
      nightWorker: t.nightWorker,
      userType: profile.userType,
      segments: [
        // Without a detailed timeline, a trip abroad is in its country for
        // the whole trip. No segments already means Sweden.
        if (b.segments.isEmpty && !isSwedenKey(t.country))
          Segment.stay(country: t.country, start: departure, end: b.returnWall),
        for (final s in b.segments)
          Segment(
            kind: s.kind,
            country: s.countryName ?? s.countryCode,
            start: Zones.toWall(s.startUtc, s.tz),
            end: Zones.toWall(s.endUtc, s.tz),
          ),
      ],
      days: {
        for (final d in b.days)
          CalendarDate.parse(d.date): DayInput(
            // A day without its own meals uses the trip's.
            breakfast: b.mealsFor(d).breakfast,
            lunch: b.mealsFor(d).lunch,
            dinner: b.mealsFor(d).dinner,
            lodging: b.lodgingFor(d),
            lodgingCostOre: d.lodgingCostOre,
            countryOverride: d.countryOverride,
          ),
      },
    );
  }

  /// Calculates one trip; also used for a trip that is not saved yet.
  static TripCalculation compute(TripBundle b, RulesLibrary library, ProfileRow profile) {
    final input = toInput(b, profile);
    final result = TripCalculator.calculate(input, library);
    return TripCalculation(
      bundle: b,
      input: input,
      result: result,
      perDiem: EmployerSettlement.settle(
        standard: result.perDiemTotal,
        paid: Ore(b.paidOre(EmployerPaymentKind.perDiem)),
        kind: EmployerPaymentKind.perDiem,
        userType: profile.userType,
      ),
      nights: EmployerSettlement.settle(
        standard: result.nightTotal,
        paid: Ore(b.paidOre(EmployerPaymentKind.night)),
        kind: EmployerPaymentKind.night,
        userType: profile.userType,
      ),
    );
  }
}
