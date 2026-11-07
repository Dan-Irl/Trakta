// Store and website screenshots of the real app with demo data, one per tab,
// in Swedish and English. Not part of `flutter test` (it lives outside
// test/); run it after UI changes:
//
//   cd apps/trakta_app
//   flutter test test_screenshots --update-goldens
//
// The images are written to website/src/assets/screenshots/<lang>/ and, numbered
// in tab order, to fastlane/metadata/android/<locale>/images/phoneScreenshots/
// (read by F-Droid, IzzyOnDroid and Google Play's upload tool).
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakta_app/data/db/database.dart';
import 'package:trakta_app/data/repositories/commute_repository.dart';
import 'package:trakta_app/data/repositories/mileage_repository.dart';
import 'package:trakta_app/data/repositories/trip_repository.dart';
import 'package:trakta_core/trakta_core.dart';

import '../test/widget_helpers.dart';

/// The real fonts, so screenshots show text instead of test blocks. Roboto is
/// also registered as the test default ("FlutterTest") for styles that name
/// no family.
Future<void> loadFonts(WidgetTester tester) => tester.runAsync(() async {
      final dir = _materialFonts();
      const roboto = ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf'];
      for (final (family, files) in [
        ('Roboto', roboto),
        ('FlutterTest', roboto),
        ('Ahem', roboto),
        ('MaterialIcons', ['materialicons-regular.otf']),
      ]) {
        final loader = FontLoader(family);
        for (final f in files) {
          loader.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
        }
        await loader.load();
      }
      // The SDK's Roboto is a subset without arrows ("→" in the driving
      // log); Windows' symbol font, when present, fills the gap.
      final symbols = File('C:/Windows/Fonts/seguisym.ttf');
      if (symbols.existsSync()) {
        await (FontLoader('Segoe UI Symbol')..addFont(Future.value(ByteData.sublistView(symbols.readAsBytesSync()))))
            .load();
      }
    });

/// The Flutter SDK's bundled Material fonts: FLUTTER_ROOT when set, else
/// found by walking up from the test runner, which lives inside the SDK.
String _materialFonts() {
  const sub = 'bin/cache/artifacts/material_fonts';
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && Directory('$root/$sub').existsSync()) return '$root/$sub';
  for (var d = File(Platform.resolvedExecutable).parent; d.parent.path != d.path; d = d.parent) {
    if (Directory('${d.path}/$sub').existsSync()) return '${d.path}/$sub';
  }
  throw StateError('Flutter SDK fonts not found; set FLUTTER_ROOT');
}

typedef Texts = ({
  String fair,
  String customer,
  String conference,
  String route,
  List<String> drivePurposes,
  List<String> tabs,
});

const sv = (
  fair: 'Mässa i Frankfurt',
  customer: 'Kundbesök Göteborg',
  conference: 'Konferens Malmö',
  route: 'Hem – Kontoret',
  drivePurposes: ['Kundmöte Volvo Cars', 'Leverantörsbesök', 'Installation hos kund', 'Workshop Linköping'],
  tabs: ['Översikt', 'Resor', 'Körjournal', 'Reseavdrag'],
);

const en = (
  fair: 'Trade fair Frankfurt',
  customer: 'Customer visit Gothenburg',
  conference: 'Conference Malmö',
  route: 'Home – Office',
  drivePurposes: ['Customer meeting', 'Supplier visit', 'On-site installation', 'Workshop Linköping'],
  tabs: ['Overview', 'Trips', 'Driving log', 'Commuting'],
);

/// A believable year: three business trips, a car with business drives, and
/// a daily commute with congestion tax and parking.
Future<void> seed(AppDatabase db, Texts t) async {
  final year = DateTime.now().year;
  final trips = TripRepository(db);
  TripDraft trip(String purpose, String from, String to, {String country = swedenName, String note = ''}) => TripDraft(
        purpose: purpose,
        departure: WallTime.parse('$year-$from'),
        returnTime: WallTime.parse('$year-$to'),
        country: country,
        confirmedBusinessTrip: true,
        confirmed50km: true,
        employerPaysPerDiem: false,
        lodging: LodgingKind.employerPaid,
        breakfast: MealStatus.hotelIncluded,
        note: note,
      );
  await trips.save(trip(t.conference, '05-05T07:10', '05-07T18:40'));
  await trips.save(trip(t.customer, '09-15T06:30', '09-16T19:30'));
  await trips.save(trip(t.fair, '03-10T06:45', '03-13T20:15', country: 'Tyskland', note: 'Booking ABC123'));

  final mileage = MileageRepository(db);
  final car = await mileage.saveVehicle(VehiclesCompanion.insert(
    label: 'Volvo V60',
    registration: const Value('ABC123'),
    ownership: Ownership.own,
    powertrain: Powertrain.pluginHybrid,
  ));
  for (final (i, (date, km)) in [
    ('01-21', 186),
    ('02-11', 242),
    ('03-04', 96),
    ('04-15', 318),
    ('06-02', 154),
    ('08-26', 412),
    ('09-23', 128),
  ].indexed) {
    await mileage.saveEntry(MileageEntriesCompanion.insert(
      date: '$year-$date',
      vehicleId: car,
      distanceM: km * 1000,
      fromText: const Value('Stockholm'),
      toText: Value(['Uppsala', 'Västerås', 'Södertälje', 'Linköping'][i % 4]),
      purpose: Value(t.drivePurposes[i % 4]),
      createdUtc: DateTime.now().toUtc(),
    ));
  }

  final commute = CommuteRepository(db);
  await commute.saveRoute(CommuteRoutesCompanion.insert(
    label: Value(t.route),
    vehicleId: car,
    oneWayM: 38000,
    startDate: '$year-01-01',
    createdUtc: DateTime.now().toUtc(),
  ));
  await commute.markNotCommuted(
      CalendarDate(year, 7, 6), CalendarDate(year, 7, 31), NoCommuteReason.vacation);
  for (var m = 1; m <= DateTime.now().month - 1; m++) {
    await commute.saveExpense(CommuteExpensesCompanion.insert(
      kind: CommuteExpenseKind.congestionTax,
      recurrence: ExpenseRecurrence.once,
      amountOre: (410 + 35 * (m % 3)) * 100,
      fromDate: CalendarDate(year, m, 28).toIso(),
      createdUtc: DateTime.now().toUtc(),
    ));
  }
}

void main() {
  for (final (lang, texts) in [('sv', sv), ('en', en)]) {
    testWidgets('screenshots $lang', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await loadFonts(tester);
      final db = await pumpApp(tester, locale: Locale(lang, 'SE'), seed: (db) => seed(db, texts));
      final out = '../../../website/src/assets/screenshots/$lang';
      final store = '../../../fastlane/metadata/android/${lang == 'sv' ? 'sv-SE' : 'en-US'}/images/phoneScreenshots';
      var shots = 0;

      Future<void> shot(String name) async {
        await tester.pump(const Duration(seconds: 1));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('$out/$name.png'));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('$store/${++shots}_$name.png'));
      }

      // Overview: the year's expected deduction and what goes in which box.
      await pumpUntilFound(tester, find.textContaining('2.2'));
      await shot('overview');

      // Trips: a trip, its days and what each day gives. (The domestic one:
      // the test runner cannot draw flag emoji.)
      await openTab(tester, texts.tabs[1]);
      await pumpUntilFound(tester, find.text(texts.customer));
      await tester.tap(find.text(texts.customer));
      await pumpUntilFound(tester, find.byIcon(Icons.edit_outlined));
      await shot('trips');

      // Business driving: the driving log with the year's total.
      await openTab(tester, texts.tabs[2]);
      await pumpUntilFound(tester, find.textContaining('Volvo V60'));
      await shot('driving');

      // Commuting: the month calendar and today in one tap.
      await openTab(tester, texts.tabs[3]);
      await pumpUntilFound(tester, find.textContaining(lang == 'sv' ? 'Idag' : 'Today'));
      await shot('commuting');

      await tearDownApp(tester, db);
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
