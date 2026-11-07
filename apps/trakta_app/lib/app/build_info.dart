import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app version, the same as `version:` in pubspec.yaml (name + build
/// number). Kept here because reading it at run time needs a plugin that
/// pulls in a network package. test/build_info_test.dart fails when the two
/// differ, so bump both together.
const appVersion = '1.1.0+2';

String get appVersionName => appVersion.split('+').first;
String get appBuildNumber => appVersion.split('+').last;

/// Where this build was installed from, so Settings can say where updates
/// come from (the app has no internet access and cannot check for them).
/// The release workflow sets it with `--dart-define=TRAKTA_CHANNEL=...`.
enum DistributionChannel {
  /// Signed APK from GitHub releases, also used by Obtainium and IzzyOnDroid.
  github,
  googlePlay,
  apple,

  /// Built from source by someone else, or a local development build.
  source;

  static DistributionChannel parse(String value) => switch (value) {
        'github' => github,
        'play' => googlePlay,
        'apple' => apple,
        _ => source,
      };
}

/// The channel this build was made for. Overridden in tests.
final distributionChannelProvider = Provider<DistributionChannel>(
  (ref) => DistributionChannel.parse(const String.fromEnvironment('TRAKTA_CHANNEL')),
);
