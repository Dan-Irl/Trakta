// Settings → open source, licences and version. The licences screen gives the
// attribution the packages' Apache, MIT and BSD licences require. The version
// row says where updates come from: the app has no internet access, so a
// GitHub build points to the download page instead of checking by itself.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakta_app/app/build_info.dart';

import 'widget_helpers.dart';

final _version = 'Version $appVersionName ($appBuildNumber)';

Future<void> _openSettings(WidgetTester tester, String settings, String language) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await pumpUntilFound(tester, find.byTooltip(settings));
  await tester.tap(find.byTooltip(settings));
  await pumpUntilFound(tester, find.text(language));
  await tester.scrollUntilVisible(find.text(_version), 300, scrollable: find.byType(Scrollable).first);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('a build from source links to the code and shows the licences', (tester) async {
    final links = <Uri>[];
    final db = await pumpApp(tester, locale: const Locale('en', 'SE'), links: links);
    await _openSettings(tester, 'Settings', 'Language');

    expect(find.text('Built from source, not an official version.'), findsOneWidget);
    await tester.tap(find.text(_version));
    await tester.pump();
    expect(links, isEmpty, reason: 'no download page for a build from source');

    await tester.tap(find.text('Open source'));
    await tester.pump();
    expect(links, [Uri.parse('https://trakta.app/source')]);

    await tester.tap(find.text('Licences'));
    await pumpUntilFound(tester, find.byType(LicensePage));

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a GitHub build sends the user to the download page for updates', (tester) async {
    final links = <Uri>[];
    final db = await pumpApp(tester, locale: const Locale('sv', 'SE'), links: links, channel: DistributionChannel.github);
    await _openSettings(tester, 'Inställningar', 'Språk');

    expect(find.textContaining('Hämtad från GitHub.'), findsOneWidget);
    await tester.tap(find.text(_version));
    await tester.pump();
    expect(links, [Uri.parse('https://trakta.app/ladda-ner/')]);

    await tester.tap(find.text('Öppen källkod'));
    await tester.pump();
    expect(links.last, Uri.parse('https://trakta.app/kallkod'));

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a Google Play build leaves updates to Play', (tester) async {
    final links = <Uri>[];
    final db = await pumpApp(tester, locale: const Locale('en', 'SE'), links: links, channel: DistributionChannel.googlePlay);
    await _openSettings(tester, 'Settings', 'Language');

    expect(find.text('Installed from Google Play, which keeps it up to date.'), findsOneWidget);
    await tester.tap(find.text(_version));
    await tester.pump();
    expect(links, isEmpty);

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
