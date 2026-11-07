import 'package:test/test.dart';
import 'package:trakta_tool/offline_check.dart';

void main() {
  test('manifest detection', () {
    expect(manifestHasInternet('<uses-permission android:name="android.permission.INTERNET"/>'), isTrue);
    expect(manifestHasInternet('<manifest><application/></manifest>'), isFalse);
  });

  test('banned packages', () {
    expect(isBanned('http'), isTrue);
    expect(isBanned('firebase_core'), isTrue);
    expect(isBanned('sentry_flutter'), isTrue);
    expect(isBanned('drift'), isFalse);
    expect(isBanned('path_provider'), isFalse);
  });

  test('finds a transitive banned package with its path', () {
    final found = findBanned('app', ['a', 'b'], {
      'a': ['c'],
      'b': [],
      'c': ['dio'],
    });
    expect(found.single, ['app', 'a', 'c', 'dio']);
  });

  test('build-time-only hooks are not traversed', () {
    final found = findBanned('app', ['sqlite3'], {
      'sqlite3': ['hooks'],
      'hooks': ['http'],
    });
    expect(found, isEmpty);
  });

  test('dev dependencies are ignored', () {
    final deps = parseDepsJson({
      'packages': [
        {
          'name': 'trakta_app',
          'kind': 'root',
          'dependencies': ['drift', 'build_runner'],
          'directDependencies': ['drift'],
          'devDependencies': ['build_runner'],
        },
        {'name': 'drift', 'dependencies': <String>[]},
        {'name': 'build_runner', 'dependencies': ['http']},
      ],
    }, 'trakta_app');
    expect(deps.runtimeDeps, ['drift']);
    expect(findBanned('trakta_app', deps.runtimeDeps, deps.graph), isEmpty);
  });

  test('dev dependencies of other workspace members are ignored', () {
    final deps = parseDepsJson({
      'packages': [
        {
          'name': 'trakta_app',
          'kind': 'root',
          'dependencies': ['trakta_core'],
          'directDependencies': ['trakta_core'],
          'devDependencies': <String>[],
        },
        {
          'name': 'trakta_core',
          'kind': 'root',
          'dependencies': ['test'],
          'directDependencies': <String>[],
          'devDependencies': ['test'],
        },
        {'name': 'test', 'kind': 'transitive', 'dependencies': ['web_socket_channel']},
      ],
    }, 'trakta_app');
    expect(findBanned('trakta_app', deps.runtimeDeps, deps.graph), isEmpty);
  });

  test('allowed edge timezone -> http is not reported, other paths to http are', () {
    expect(findBanned('app', ['timezone'], {'timezone': ['http']}), isEmpty);
    expect(findBanned('app', ['other'], {'other': ['http']}).single, ['app', 'other', 'http']);
  });
}
