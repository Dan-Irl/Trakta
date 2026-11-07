import '../model/calendar_date.dart';
import '../model/trip.dart';

/// One row of Skatteverket's normalbelopp list, with redirects already
/// resolved by the build tool.
final class ForeignRate {
  const ForeignRate({required this.name, required this.code, required this.kr, this.redirectTo});

  factory ForeignRate.fromJson(Map<String, Object?> j) => ForeignRate(
        name: _str(j, 'name'),
        code: j['code'] as String?,
        kr: _int(j, 'kr'),
        redirectTo: j['redirectTo'] as String?,
      );

  /// Swedish name as published ("Tyskland").
  final String name;

  /// ISO 3166-1 alpha-2, or null for redirect rows without a code.
  final String? code;

  /// Normalbelopp in whole kronor per full day.
  final int kr;

  /// Target of a "Se …" row, kept only for display ("Grönland (Se Danmark)").
  final String? redirectTo;

  Map<String, Object?> toJson() => {
        'name': name,
        'code': code,
        'kr': kr,
        if (redirectTo != null) 'redirectTo': redirectTo,
      };
}

final class DomesticAmounts {
  const DomesticAmounts({required this.fullDayKr, required this.halfDayKr, required this.nightKr});
  factory DomesticAmounts.fromJson(Map<String, Object?> j) => DomesticAmounts(
        fullDayKr: _int(j, 'fullDayKr'),
        halfDayKr: _int(j, 'halfDayKr'),
        nightKr: _int(j, 'nightKr'),
      );
  final int fullDayKr;
  final int halfDayKr;
  final int nightKr;
}

/// Minutes after midnight, parsed from "HH:MM".
final class ClockTime {
  const ClockTime(this.hour, this.minute);
  factory ClockTime.parse(String s) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.trim());
    if (m == null) throw FormatException('Expected HH:MM', s);
    return ClockTime(int.parse(m[1]!), int.parse(m[2]!));
  }
  final int hour;
  final int minute;
  int get minutes => hour * 60 + minute;
  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

final class DayTypeRules {
  const DayTypeRules({required this.departureFullIfBefore, required this.returnFullIfAfter});
  factory DayTypeRules.fromJson(Map<String, Object?> j) => DayTypeRules(
        departureFullIfBefore: ClockTime.parse(_str(j, 'departureFullIfBefore')),
        returnFullIfAfter: ClockTime.parse(_str(j, 'returnFullIfAfter')),
      );
  final ClockTime departureFullIfBefore;
  final ClockTime returnFullIfAfter;
}

final class MealPct {
  const MealPct({required this.breakfast, required this.lunch, required this.dinner});
  factory MealPct.fromJson(Map<String, Object?> j) =>
      MealPct(breakfast: _int(j, 'breakfast'), lunch: _int(j, 'lunch'), dinner: _int(j, 'dinner'));
  final int breakfast;
  final int lunch;
  final int dinner;
}

final class CommuteRules {
  const CommuteRules({
    required this.thresholdKr,
    required this.carMinKm,
    required this.publicTransportMinKm,
    required this.minTimeSavedHours,
    required this.orePerMil,
    required this.bicycleKrPerYear,
    required this.parking,
  });
  factory CommuteRules.fromJson(Map<String, Object?> j) => CommuteRules(
        thresholdKr: _int(j, 'thresholdKr'),
        carMinKm: _int(j, 'carMinKm'),
        publicTransportMinKm: _int(j, 'publicTransportMinKm'),
        minTimeSavedHours: _int(j, 'minTimeSavedHours'),
        orePerMil: _intMap(j, 'orePerMil'),
        bicycleKrPerYear: _int(j, 'bicycleKrPerYear'),
        parking: CommuteParkingRules.fromJson(_map(j, 'parking')),
      );
  final int thresholdKr;
  final int carMinKm;
  final int publicTransportMinKm;
  final int minTimeSavedHours;
  final Map<String, int> orePerMil;
  final int bicycleKrPerYear;
  final CommuteParkingRules parking;
}

/// Parking while commuting is normally not deductible. It is after regular
/// use of the same car in the job (business driving) during the year:
/// [minServiceMil] mil over at least [minServiceDaysForServiceDays] days gives
/// parking on those days, over [minServiceDaysForAllDays] days parking on all
/// commuting days (Skatteverket, Avdragslexikon "Parkeringskostnad").
final class CommuteParkingRules {
  const CommuteParkingRules({
    required this.minServiceMil,
    required this.minServiceDaysForServiceDays,
    required this.minServiceDaysForAllDays,
  });
  factory CommuteParkingRules.fromJson(Map<String, Object?> j) => CommuteParkingRules(
        minServiceMil: _int(j, 'minServiceMil'),
        minServiceDaysForServiceDays: _int(j, 'minServiceDaysForServiceDays'),
        minServiceDaysForAllDays: _int(j, 'minServiceDaysForAllDays'),
      );
  final int minServiceMil;
  final int minServiceDaysForServiceDays;
  final int minServiceDaysForAllDays;
}

/// Mileage rate keys used in `mileageOrePerMil`.
abstract final class MileageRateKey {
  static const ownCar = 'own_car';
  static const companyCarNonElectric = 'company_car_non_electric';
  static const companyCarElectric = 'company_car_electric';
}

/// The per-income-year rules pack (docs/rules-packs.md). The only source
/// of tax numbers in the app.
final class RulesPack {
  RulesPack({
    required this.incomeYear,
    required this.packVersion,
    required this.domestic,
    required this.dayType,
    required this.mealDomestic,
    required this.mealForeign,
    required this.internationalTransitFullDay,
    required this.foreignRatesSource,
    required this.foreignRatesTakenOn,
    required this.foreignFallback,
    required this.foreignRates,
    required this.mileageOrePerMil,
    required this.pluginHybridWorkplaceChargingOkFrom,
    required this.commute,
    required this.sources,
  }) {
    for (final r in foreignRates) {
      _byKey[_key(r.name)] = r;
      if (r.code != null && r.code!.isNotEmpty) _byKey.putIfAbsent(_key(r.code!), () => r);
    }
  }

  factory RulesPack.fromJson(Map<String, Object?> j) {
    final meal = _map(j, 'mealReductionPct');
    return RulesPack(
      incomeYear: _int(j, 'incomeYear'),
      packVersion: _str(j, 'packVersion'),
      domestic: DomesticAmounts.fromJson(_map(j, 'domestic')),
      dayType: DayTypeRules.fromJson(_map(j, 'dayType')),
      mealDomestic: MealPct.fromJson(_map(meal, 'domestic')),
      mealForeign: MealPct.fromJson(_map(meal, 'foreign')),
      internationalTransitFullDay: _str(j, 'internationalTransitFullDay'),
      foreignRatesSource: _str(j, 'foreignRatesSource'),
      foreignRatesTakenOn: CalendarDate.parse(_str(j, 'foreignRatesTakenOn')),
      foreignFallback: _str(j, 'foreignFallback'),
      foreignRates: [
        for (final r in _list(j, 'foreignRates')) ForeignRate.fromJson(_asMap(r, 'foreignRates[]')),
      ],
      mileageOrePerMil: _intMap(j, 'mileageOrePerMil'),
      pluginHybridWorkplaceChargingOkFrom:
          CalendarDate.parse(_str(j, 'pluginHybridWorkplaceChargingOkFrom')),
      commute: CommuteRules.fromJson(_map(j, 'commute')),
      sources: [for (final s in _list(j, 'sources')) s as String],
    );
  }

  final int incomeYear;
  final String packVersion;
  final DomesticAmounts domestic;
  final DayTypeRules dayType;
  final MealPct mealDomestic;
  final MealPct mealForeign;

  /// How a day spent entirely in international transit is paid. Currently
  /// only `domestic_full_day` is defined.
  final String internationalTransitFullDay;
  final String foreignRatesSource;
  final CalendarDate foreignRatesTakenOn;
  final String foreignFallback;
  final List<ForeignRate> foreignRates;
  final Map<String, int> mileageOrePerMil;
  final CalendarDate pluginHybridWorkplaceChargingOkFrom;
  final CommuteRules commute;
  final List<String> sources;

  final Map<String, ForeignRate> _byKey = {};

  static String _key(String s) => s.trim().toLowerCase();

  /// Case-insensitive lookup by Swedish name or ISO code. Returns null when
  /// the country is not listed (callers then use [fallbackRate]).
  ForeignRate? lookup(String nameOrCode) => _byKey[_key(nameOrCode)];

  ForeignRate get fallbackRate {
    final r = lookup(foreignFallback);
    if (r == null) throw StateError('Pack $packVersion has no fallback row "$foreignFallback"');
    return r;
  }

  /// The rate for a country, falling back to "Övriga länder och områden".
  ({ForeignRate rate, bool isFallback}) rateFor(String nameOrCode) {
    final r = lookup(nameOrCode);
    return r == null ? (rate: fallbackRate, isFallback: true) : (rate: r, isFallback: false);
  }

  /// Countries the user can pick for a trip in this year (sorted by name,
  /// fallback last). Sweden is not in the list.
  List<ForeignRate> get pickableCountries {
    final list = foreignRates.where((r) => r.name != foreignFallback).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  bool isSweden(String nameOrCode) => isSwedenKey(nameOrCode);
}

/// All bundled packs, keyed by income year.
final class RulesLibrary {
  RulesLibrary(Iterable<RulesPack> packs) : _packs = {for (final p in packs) p.incomeYear: p};

  final Map<int, RulesPack> _packs;

  RulesPack? forYear(int year) => _packs[year];
  Iterable<int> get years => _packs.keys.toList()..sort();
  Iterable<RulesPack> get packs => years.map((y) => _packs[y]!);
}

// --- JSON helpers -----------------------------------------------------------

Map<String, Object?> _asMap(Object? v, String key) {
  if (v is Map<String, Object?>) return v;
  if (v is Map) return v.cast<String, Object?>();
  throw FormatException('Expected an object at "$key"');
}

Map<String, Object?> _map(Map<String, Object?> j, String key) => _asMap(j[key], key);

List<Object?> _list(Map<String, Object?> j, String key) {
  final v = j[key];
  if (v is List) return v.cast<Object?>();
  throw FormatException('Expected a list at "$key"');
}

String _str(Map<String, Object?> j, String key) {
  final v = j[key];
  if (v is String) return v;
  throw FormatException('Expected a string at "$key"');
}

int _int(Map<String, Object?> j, String key) {
  final v = j[key];
  if (v is int) return v;
  if (v is num && v == v.roundToDouble()) return v.toInt();
  throw FormatException('Expected an integer at "$key"');
}

Map<String, int> _intMap(Map<String, Object?> j, String key) {
  final m = _map(j, key);
  return {for (final e in m.entries) e.key: _int(m, e.key)};
}
