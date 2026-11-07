import 'rules_pack.dart';

/// Semantic checks every bundled pack must pass.
/// Returns a list of human-readable problems; empty means valid.
List<String> validateRulesPack(RulesPack p, {int minForeignRows = 100}) {
  final errors = <String>[];

  void check(bool ok, String msg) {
    if (!ok) errors.add('${p.packVersion}: $msg');
  }

  check(p.incomeYear >= 2000 && p.incomeYear <= 2100, 'implausible incomeYear ${p.incomeYear}');
  check(p.packVersion.startsWith('${p.incomeYear}.'),
      'packVersion "${p.packVersion}" must start with "${p.incomeYear}."');

  final d = p.domestic;
  check(d.fullDayKr > 0 && d.halfDayKr > 0 && d.nightKr > 0, 'domestic amounts must be positive');
  check(d.halfDayKr * 2 == d.fullDayKr, 'domestic half day must be half the full day');

  for (final (label, m) in [('domestic', p.mealDomestic), ('foreign', p.mealForeign)]) {
    final total = m.breakfast + m.lunch + m.dinner;
    check(m.breakfast > 0 && m.lunch > 0 && m.dinner > 0, '$label meal percentages must be positive');
    check(total < 100, '$label meal percentages sum to $total, must leave room for småutgifter');
  }

  check(p.internationalTransitFullDay == 'domestic_full_day',
      'unknown internationalTransitFullDay "${p.internationalTransitFullDay}"');

  // Foreign rates.
  check(p.foreignRates.length > minForeignRows,
      'only ${p.foreignRates.length} foreign rows, expected more than $minForeignRows');
  final names = <String>{};
  final codes = <String>{};
  for (final r in p.foreignRates) {
    check(r.name.trim().isNotEmpty, 'foreign row with empty name');
    check(r.name == r.name.trim(), 'foreign row "${r.name}" has surrounding whitespace');
    check(names.add(r.name.toLowerCase()), 'duplicate foreign row "${r.name}"');
    if (r.code != null) {
      check(RegExp(r'^[A-Z]{2}$').hasMatch(r.code!), 'bad country code "${r.code}" for ${r.name}');
      check(codes.add(r.code!), 'duplicate country code "${r.code}" (${r.name})');
    }
    check(r.kr > 0, '${r.name} has non-positive amount ${r.kr}');
    check(!p.isSweden(r.name) && r.code != 'SE', 'Sweden must not be in foreignRates');
  }
  final fallback = p.lookup(p.foreignFallback);
  check(fallback != null, 'fallback row "${p.foreignFallback}" missing');
  for (final r in p.foreignRates.where((r) => r.redirectTo != null)) {
    final target = p.lookup(r.redirectTo!);
    check(target != null, '${r.name} redirects to missing "${r.redirectTo}"');
    if (target != null) {
      check(target.redirectTo == null, '${r.name} redirects to another redirect (${target.name})');
      check(target.kr == r.kr, '${r.name} (${r.kr} kr) differs from its target ${target.name} (${target.kr} kr)');
    }
  }

  // Mileage.
  for (final key in [
    MileageRateKey.ownCar,
    MileageRateKey.companyCarNonElectric,
    MileageRateKey.companyCarElectric,
  ]) {
    final v = p.mileageOrePerMil[key];
    check(v != null && v > 0, 'mileage rate "$key" missing or not positive');
  }

  check(p.commute.thresholdKr > 0, 'commute threshold must be positive');
  for (final key in [MileageRateKey.ownCar, MileageRateKey.companyCarNonElectric, MileageRateKey.companyCarElectric]) {
    final v = p.commute.orePerMil[key];
    check(v != null && v > 0, 'commute rate "$key" missing or not positive');
  }
  final parking = p.commute.parking;
  check(parking.minServiceDaysForServiceDays <= parking.minServiceDaysForAllDays,
      'commute parking: the service-days limit must not exceed the all-days limit');
  check(p.sources.isNotEmpty, 'sources must not be empty');
  check(p.foreignRatesSource.startsWith('https://'), 'foreignRatesSource must be an https URL');

  return errors;
}
