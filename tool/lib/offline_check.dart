/// Pure logic behind bin/check_offline.dart.
library;

/// Packages that would give the app network access or phone home.
const bannedExact = {
  'http',
  'dio',
  'chopper',
  'retrofit',
  'graphql',
  'graphql_flutter',
  'web_socket_channel',
  'socket_io_client',
  'grpc',
  'cronet_http',
  'cupertino_http',
  'ok_http',
  'google_mobile_ads',
  // url_launcher is allowed: it only hands a link (trakta.app) to the phone's
  // own browser. The app itself still has no INTERNET permission, which the
  // merged-manifest check below keeps verifying.
  'webview_flutter',
  'flutter_inappwebview',
  'cached_network_image',
  'in_app_purchase',
  'supabase_flutter',
  'appwrite',
  'amplify_flutter',
};

const bannedPrefixes = [
  'firebase',
  'cloud_firestore',
  'sentry',
  'datadog',
  'amplitude',
  'mixpanel',
  'onesignal',
  'appsflyer',
  'adjust_sdk',
  'facebook',
  'google_analytics',
  'posthog',
  'segment',
  'bugsnag',
  'newrelic',
  'instabug',
];

bool isBanned(String package) =>
    bannedExact.contains(package) || bannedPrefixes.any((p) => package.startsWith(p));

/// Dependency edges that only run at build time on the developer's machine
/// (e.g. native-asset build hooks that download prebuilt libraries) and are
/// therefore allowed to reach banned packages. Keep this list short and
/// justified.
const buildTimeOnlyPackages = <String>{
  'hooks',
  'code_assets',
  'data_assets',
  'native_assets_cli',
  'native_toolchain_c',
};

/// Specific dependency edges that are allowed to reach a banned package,
/// with the reason. Each entry was checked by hand: the dependent package's
/// `lib/` never imports the banned package at runtime.
const allowedEdges = <String, Map<String, String>>{
  'timezone': {
    'http': 'Only used by timezone\'s own tool that downloads the IANA database; '
        'the tz data is bundled in lib/ and nothing in lib/ imports http.',
  },
};

bool _edgeAllowed(String from, String to) => allowedEdges[from]?.containsKey(to) ?? false;

/// Finds banned packages reachable from [rootPackage]'s runtime (non-dev)
/// dependencies. [graph] maps a package to its dependencies. Returns the
/// dependency path to each banned package found.
List<List<String>> findBanned(String rootPackage, List<String> runtimeDeps, Map<String, List<String>> graph) {
  final found = <List<String>>[];
  final seen = <String>{};
  final queue = <List<String>>[for (final d in runtimeDeps) [rootPackage, d]];
  while (queue.isNotEmpty) {
    final path = queue.removeAt(0);
    final pkg = path.last;
    if (!seen.add(pkg)) continue;
    if (isBanned(pkg)) {
      found.add(path);
      continue;
    }
    if (buildTimeOnlyPackages.contains(pkg)) continue;
    for (final next in graph[pkg] ?? const <String>[]) {
      if (_edgeAllowed(pkg, next)) continue;
      queue.add([...path, next]);
    }
  }
  return found;
}

/// Parses `pub deps --json` output into (runtime deps of [rootPackage], graph).
///
/// In a pub workspace every member is listed with kind `root`, and its
/// `dependencies` include dev dependencies (e.g. `test`). Dev dependencies
/// never ship, so for workspace members only the non-dev edges are kept.
({List<String> runtimeDeps, Map<String, List<String>> graph}) parseDepsJson(
    Map<String, Object?> json, String rootPackage) {
  final packages = (json['packages']! as List).cast<Map<String, Object?>>();
  final graph = <String, List<String>>{};
  List<String>? runtime;
  for (final p in packages) {
    final name = p['name']! as String;
    final deps = (p['dependencies'] as List? ?? const []).cast<String>();
    final direct = (p['directDependencies'] as List?)?.cast<String>();
    final dev = (p['devDependencies'] as List? ?? const []).cast<String>().toSet();
    final isWorkspaceMember = p['kind'] == 'root' || name == rootPackage;
    final edges = isWorkspaceMember ? (direct ?? deps).where((d) => !dev.contains(d)).toList() : deps;
    graph[name] = edges;
    if (name == rootPackage) runtime = edges;
  }
  if (runtime == null) throw StateError('Package $rootPackage not found in pub deps output');
  return (runtimeDeps: runtime, graph: graph);
}

final _internetPermission = RegExp(r'android\.permission\.INTERNET');

bool manifestHasInternet(String xml) => _internetPermission.hasMatch(xml);
