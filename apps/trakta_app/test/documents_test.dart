// Trip notes and documents: files are copied into the app once, linked to
// trips, and deleted when nothing uses them any more.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakta_app/data/db/database.dart';
import 'package:trakta_app/data/repositories/attachment_repository.dart';
import 'package:trakta_app/data/repositories/commute_repository.dart';
import 'package:trakta_app/data/repositories/mileage_repository.dart';
import 'package:trakta_app/features/commute/commute_calendar.dart';
import 'package:trakta_core/trakta_core.dart';
import 'package:trakta_app/data/repositories/trip_repository.dart';

import 'widget_helpers.dart';

Stream<List<int>> bytes(String s) => Stream.value(utf8.encode(s));

void main() {
  test('a file is stored once, kept while used, deleted with its last use', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final root = Directory.systemTemp.createTempSync('trakta_docs');
    addTearDown(() => root.deleteSync(recursive: true));
    final repo = AttachmentRepository(db, root);

    final ticket = await repo.import('Flight SK123.pdf', bytes('boarding pass'));
    final again = await repo.import('copy of ticket.PDF', bytes('boarding pass'));
    expect(again.sha256, ticket.sha256); // same content, same file
    expect(ticket.sizeBytes, 13);
    expect(root.listSync().whereType<File>(), hasLength(1));
    expect(repo.fileFor(ticket.sha256, ticket.fileName).readAsStringSync(), 'boarding pass');

    await repo.add(AttachmentOwner.trip, 1, [ticket]);
    await repo.add(AttachmentOwner.trip, 2, [ticket]);
    final trip1 = await repo.watch(AttachmentOwner.trip, 1).first;
    expect(trip1.single.fileName, 'Flight SK123.pdf');

    await repo.removeAll(AttachmentOwner.trip, 1);
    expect(repo.fileFor(ticket.sha256, ticket.fileName).existsSync(), isTrue); // trip 2 still has it
    await repo.removeAll(AttachmentOwner.trip, 2);
    expect(repo.fileFor(ticket.sha256, ticket.fileName).existsSync(), isFalse);

    // A picked file that was never linked is discarded.
    final stray = await repo.import('receipt.jpg', bytes('pixels'));
    await repo.discard([stray]);
    expect(root.listSync().whereType<File>(), isEmpty);
  });

  testWidgets('a new trip with notes and a document', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final opened = <File>[];
    final db = await pumpApp(
      tester,
      locale: const Locale('en', 'SE'),
      pick: () => [(name: 'Booking ABC123.pdf', read: () => bytes('hotel booking'))],
      opened: opened,
    );
    await openTab(tester, 'Trips');
    await pumpUntilFound(tester, find.text('New trip'));
    await tester.tap(find.text('New trip'));
    await pumpUntilFound(tester, find.text('Step 1 of 2'));
    await tester.enterText(find.byType(TextFormField).first, 'Kurs');

    final form = find.descendant(of: find.byType(Form), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Add document'), 300, scrollable: form);
    await tester.enterText(find.widgetWithText(TextFormField, 'Notes'), 'Booking ref ABC123, Scandic City');
    // Typing scrolls the field into view; bring the button back above the
    // tab bar before tapping it.
    await tester.ensureVisible(find.text('Add document'));
    await tester.drag(form, const Offset(0, -150));
    await tester.pump(const Duration(milliseconds: 300));
    // Copying the file is real disk I/O, so let it run outside fake time.
    await tester.runAsync(() async {
      await tester.tap(find.text('Add document'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await pumpUntilFound(tester, find.text('Booking ABC123.pdf'));

    await tester.tap(find.text('Next'));
    await pumpUntilFound(tester, find.text('Review days'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Create trip'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await pumpUntilFound(tester, find.text('Summary'));

    final trip = (await tester.runAsync(() => TripRepository(db).loadAll()))!.single.trip;
    expect(trip.note, 'Booking ref ABC123, Scandic City');
    final rows = (await tester.runAsync(() => db.select(db.attachments).get()))!;
    expect(rows.map((r) => (r.ownerId, r.fileName)), [(trip.id, 'Booking ABC123.pdf')]);

    // The trip page shows both, and a document opens in the phone's viewer.
    await pumpUntilFound(tester, find.text('Kurs')); // the page content has loaded
    await tester.dragUntilVisible(find.text('Booking ABC123.pdf'), find.byType(ListView).last, const Offset(0, -300));
    await tester.ensureVisible(find.text('Booking ABC123.pdf'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Booking ref ABC123, Scandic City'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Booking ABC123.pdf'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    expect(opened.single.readAsStringSync(), 'hotel booking');

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));

  Future<int> addCar(WidgetTester tester, AppDatabase db) async => (await tester.runAsync(
        () => MileageRepository(db).saveVehicle(
          VehiclesCompanion.insert(label: 'Volvo', ownership: Ownership.own, powertrain: Powertrain.fossil),
        ),
      ))!;

  /// Taps [finder] with real time, so the file copy behind it can finish.
  Future<void> tapAndWait(WidgetTester tester, Finder finder) => tester.runAsync(() async {
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });

  /// Lets work that mixes fake time (dialogs, navigation) and real disk I/O
  /// (copying, deleting files) run to the end.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
  }

  Future<void> bringIntoView(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a commuting cost with its invoice; deleting the cost deletes the document', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(
      tester,
      locale: const Locale('en', 'SE'),
      pick: () => [(name: 'Trängselskatt mars.pdf', read: () => bytes('invoice'))],
    );
    final car = await addCar(tester, db);
    await tester.runAsync(() => CommuteRepository(db).saveRoute(CommuteRoutesCompanion.insert(
          label: const Value('Home – Office'),
          vehicleId: car,
          oneWayM: 30000,
          startDate: '${DateTime.now().year}-01-01',
          createdUtc: DateTime.now().toUtc(),
        )));
    await openTab(tester, 'Commuting');
    await pumpUntilFound(tester, find.text('Add cost'));
    await tester.tap(find.text('Add cost'));
    await pumpUntilFound(tester, find.text('New cost'));
    expect(find.textContaining('Invoices and receipts that show you paid'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount (SEK)'), '1105');
    await bringIntoView(tester, find.text('Add document'));
    await tapAndWait(tester, find.text('Add document'));
    await pumpUntilFound(tester, find.text('Trängselskatt mars.pdf'));
    await tapAndWait(tester, find.text('Save'));
    await pumpUntilFound(tester, find.text('Add cost'));

    final expense = (await tester.runAsync(() => db.select(db.commuteExpenses).getSingle()))!;
    var docs = (await tester.runAsync(() => db.select(db.attachments).get()))!;
    expect(docs.map((d) => (d.ownerType, d.ownerId)), [(AttachmentOwner.commuteExpense, expense.id)]);
    await pumpUntilFound(tester, find.byType(CommuteMonthGrid)); // the tab has reloaded
    await tester.scrollUntilVisible(find.textContaining('1 document'), 300, scrollable: find.byType(Scrollable).first);

    // Deleting the cost takes its document with it.
    await bringIntoView(tester, find.textContaining('1 document'));
    await tester.tap(find.textContaining('1 document'));
    await pumpUntilFound(tester, find.text('Edit cost'));
    await tester.tap(find.byTooltip('Delete'));
    await pumpUntilFound(tester, find.text('Delete this cost?'));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    await pumpUntilFound(tester, find.text('Add cost'));
    docs = (await tester.runAsync(() => db.select(db.attachments).get()))!;
    expect(docs, isEmpty);

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a business drive with a toll receipt', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(
      tester,
      locale: const Locale('en', 'SE'),
      pick: () => [(name: 'Öresundsbron.jpg', read: () => bytes('receipt'))],
    );
    await addCar(tester, db);
    await openTab(tester, 'Driving log');
    await pumpUntilFound(tester, find.text('New drive'));
    await tester.tap(find.text('New drive'));
    await pumpUntilFound(tester, find.text('Distance (km)'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Distance (km)'), '120');
    final form = find.descendant(of: find.byType(Form), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Add document'), 300, scrollable: form);
    await bringIntoView(tester, find.text('Add document'));
    expect(find.textContaining('Receipts for tolls or congestion tax'), findsOneWidget);
    await tapAndWait(tester, find.text('Add document'));
    await pumpUntilFound(tester, find.text('Öresundsbron.jpg'));
    await tapAndWait(tester, find.text('Save'));
    await pumpUntilFound(tester, find.textContaining('1 document'));

    final entry = (await tester.runAsync(() => db.select(db.mileageEntries).getSingle()))!;
    final docs = (await tester.runAsync(() => db.select(db.attachments).get()))!;
    expect(docs.map((d) => (d.ownerType, d.ownerId, d.fileName)),
        [(AttachmentOwner.mileageEntry, entry.id, 'Öresundsbron.jpg')]);

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
