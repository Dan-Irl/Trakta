import '../explain/reason.dart';
import '../model/calendar_date.dart';
import '../model/enums.dart';
import '../model/trip.dart';
import '../rules/rules_pack.dart';

/// Which amount basis applies to a day.
sealed class DayCountry {
  const DayCountry();
}

final class DomesticCountry extends DayCountry {
  const DomesticCountry();
  @override
  String toString() => swedenName;
}

final class ForeignCountry extends DayCountry {
  const ForeignCountry(this.rate, {required this.isFallback, required this.requested});

  /// The pack row used (the fallback row when [isFallback]).
  final ForeignRate rate;
  final bool isFallback;

  /// The name or code the user's segment used.
  final String requested;

  @override
  String toString() => isFallback ? '$requested (${rate.name})' : rate.name;
}

/// The whole 06:00–24:00 window was spent in international traffic.
final class InternationalTransitDay extends DayCountry {
  const InternationalTransitDay();
  @override
  String toString() => 'International transit';
}

/// Two or more countries tie for the longest time; the user must choose.
final class AmbiguousCountry extends DayCountry {
  const AmbiguousCountry(this.candidates);
  final List<String> candidates;
  @override
  String toString() => 'Ambiguous(${candidates.join(', ')})';
}

extension DayCountryX on DayCountry {
  /// Domestic amounts and domestic meal percentages apply.
  bool get usesDomesticAmounts => this is DomesticCountry || this is InternationalTransitDay;
}

abstract final class CountryResolver {
  static const _dayWindowStartHour = 6;
  static const _fullWindowMinutes = 18 * 60;

  /// Minutes per country (canonical key) of stay segments within [from, to).
  static Map<String, int> _stayMinutes(
      List<Segment> segments, DateTime from, DateTime to, RulesPack pack, Map<String, String> display) {
    final minutes = <String, int>{};
    for (final s in segments) {
      if (s.kind != SegmentKind.stay || s.country == null) continue;
      final m = WallTime.overlapMinutes(s.start, s.end, from, to);
      if (m <= 0) continue;
      final key = _canonicalKey(s.country!, pack);
      display.putIfAbsent(key, () => _displayName(s.country!, pack));
      minutes[key] = (minutes[key] ?? 0) + m;
    }
    return minutes;
  }

  static String _canonicalKey(String country, RulesPack pack) {
    if (isSwedenKey(country)) return swedenName.toLowerCase();
    final row = pack.lookup(country);
    return (row?.name ?? country).trim().toLowerCase();
  }

  static String _displayName(String country, RulesPack pack) {
    if (isSwedenKey(country)) return swedenName;
    return pack.lookup(country)?.name ?? country.trim();
  }

  /// Resolves the country for calendar date [d].
  static ({DayCountry country, List<Reason> reasons}) resolve(
      CalendarDate d, TripInput t, RulesPack pack) {
    final override = t.dayInput(d).countryOverride;
    if (override != null && override.trim().isNotEmpty) {
      final c = _toCountry(override, pack);
      return (
        country: c.country,
        reasons: [Reason(ReasonCode.countryChosenByUser, {'country': c.country.toString()}), ...c.reasons],
      );
    }

    if (t.segments.isEmpty) {
      return (country: const DomesticCountry(), reasons: const [Reason(ReasonCode.countrySweden)]);
    }

    final from = d.at(_dayWindowStartHour);
    final to = d.next.start;
    final display = <String, String>{};
    final minutes = _stayMinutes(t.segments, from, to, pack, display);

    if (minutes.isEmpty) {
      var transit = 0;
      for (final s in t.segments.where((s) => s.kind == SegmentKind.internationalTransit)) {
        transit += WallTime.overlapMinutes(s.start, s.end, from, to);
      }
      if (transit >= _fullWindowMinutes) {
        return (
          country: const InternationalTransitDay(),
          reasons: const [Reason(ReasonCode.countryInternationalTransit, {}, Sources.specifikationReserakning)],
        );
      }
      return (country: const DomesticCountry(), reasons: const [Reason(ReasonCode.countryNoTimeRecorded)]);
    }

    final best = minutes.values.reduce((a, b) => a > b ? a : b);
    final winners = minutes.entries.where((e) => e.value == best).map((e) => e.key).toList();
    if (winners.length > 1) {
      final names = winners.map((k) => display[k]!).toList()..sort();
      return (
        country: AmbiguousCountry(names),
        reasons: [Reason(ReasonCode.countryAmbiguous, {'countries': names.join(', '), 'minutes': best})],
      );
    }
    final c = _toCountry(display[winners.single]!, pack);
    return (
      country: c.country,
      reasons: [
        ...c.reasons.map((r) => r.code == ReasonCode.countrySweden || r.code == ReasonCode.countryForeign
            ? Reason(r.code, {...r.params, 'minutes': best}, r.source)
            : r),
      ],
    );
  }

  static ({DayCountry country, List<Reason> reasons}) _toCountry(String name, RulesPack pack) {
    if (isSwedenKey(name)) {
      return (country: const DomesticCountry(), reasons: const [Reason(ReasonCode.countrySweden)]);
    }
    final r = pack.rateFor(name);
    final country = ForeignCountry(r.rate, isFallback: r.isFallback, requested: name.trim());
    final reasons = <Reason>[
      Reason(ReasonCode.countryForeign, {'country': r.rate.name, 'kr': r.rate.kr}, Sources.utlandstraktamente),
    ];
    if (r.isFallback) {
      reasons.add(Reason(ReasonCode.countryFallback, {'country': name.trim(), 'fallback': r.rate.name}));
    } else if (r.rate.redirectTo != null) {
      reasons.add(Reason(ReasonCode.countryRedirect, {'country': r.rate.name, 'target': r.rate.redirectTo!}));
    }
    return (country: country, reasons: reasons);
  }

  /// Country of the night starting on the evening of [evening]: the stay with
  /// the most time between 00:00 and 06:00 the next morning, else [dayCountry].
  /// A country the user chose for the day also applies to the night after it.
  static DayCountry nightCountry(CalendarDate evening, TripInput t, RulesPack pack, DayCountry dayCountry) {
    final override = t.dayInput(evening).countryOverride;
    if (override != null && override.trim().isNotEmpty) return dayCountry;
    if (t.segments.isEmpty) return const DomesticCountry();
    final display = <String, String>{};
    final minutes = _stayMinutes(t.segments, evening.next.start, evening.next.at(6), pack, display);
    if (minutes.isEmpty) return dayCountry;
    final best = minutes.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return _toCountry(display[best.key]!, pack).country;
  }
}
