// The version shown in Settings, the channel set by the release workflow and
// the trakta.app pages the app opens.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakta_app/app/build_info.dart';
import 'package:trakta_app/features/common/website_link.dart';

void main() {
  test('appVersion is the version in pubspec.yaml (bump both together)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)![1];
    expect(appVersion, version);
    expect('$appVersionName+$appBuildNumber', appVersion);
  });

  test('TRAKTA_CHANNEL values from the release workflow', () {
    expect(DistributionChannel.parse('github'), DistributionChannel.github);
    expect(DistributionChannel.parse('play'), DistributionChannel.googlePlay);
    expect(DistributionChannel.parse('apple'), DistributionChannel.apple);
    // Not set: a local build or someone else's build from source.
    expect(DistributionChannel.parse(''), DistributionChannel.source);
    expect(DistributionChannel.parse('GitHub'), DistributionChannel.source);
  });

  test('every page the app opens is on trakta.app, in the app language', () {
    for (final page in WebsitePage.values) {
      for (final locale in const [Locale('sv'), Locale('en')]) {
        final uri = page.uri(locale);
        expect(uri.scheme, 'https');
        expect(uri.host, 'trakta.app');
      }
    }
    expect(WebsitePage.source.uri(const Locale('sv')).toString(), 'https://trakta.app/kallkod');
    expect(WebsitePage.source.uri(const Locale('en')).toString(), 'https://trakta.app/source');
    expect(WebsitePage.download.uri(const Locale('sv')).toString(), 'https://trakta.app/ladda-ner/');
    expect(WebsitePage.download.uri(const Locale('en')).toString(), 'https://trakta.app/en/download/');
    expect(WebsitePage.home.uri(const Locale('en')).toString(), 'https://trakta.app');
  });
}
