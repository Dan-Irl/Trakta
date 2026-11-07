// The app links to trakta.app (about, help, contact, support) from the
// overview and from Settings. It hands the link to the phone's browser.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_helpers.dart';

void main() {
  testWidgets('overview footer and settings open trakta.app', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final links = <Uri>[];
    final db = await pumpApp(tester, locale: const Locale('en', 'SE'), links: links);
    await pumpUntilFound(tester, find.textContaining('Expected deduction'));

    final overview = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Trakta · trakta.app'), 300, scrollable: overview);
    await tester.ensureVisible(find.text('Trakta · trakta.app'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Trakta · trakta.app'));
    await tester.pump();
    expect(links, [Uri.parse('https://trakta.app')]);

    await tester.tap(find.byTooltip('Settings'));
    await pumpUntilFound(tester, find.text('Language'));
    await tester.scrollUntilVisible(find.text('trakta.app'), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('trakta.app'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('trakta.app'));
    await tester.pump();
    expect(links, hasLength(2));

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
