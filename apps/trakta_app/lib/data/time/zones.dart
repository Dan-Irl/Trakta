import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Time-zone conversion between stored UTC instants and the local wall-clock
/// times the rules engine works with. The IANA database is
/// bundled in the `timezone` package; nothing is fetched at runtime.
abstract final class Zones {
  static const stockholm = 'Europe/Stockholm';
  static bool _initialized = false;

  /// Backward-compatible IANA names that some tz data sets only carry as
  /// links (Europe/Stockholm has been a link to Europe/Berlin since tzdata
  /// 2022b; the offsets are identical).
  static const _links = {'Europe/Stockholm': 'Europe/Berlin'};

  static tz.Location location(String zone) {
    ensureInitialized();
    try {
      return tz.getLocation(zone);
    } on Object {
      final target = _links[zone];
      if (target == null) rethrow;
      return tz.getLocation(target);
    }
  }

  static void ensureInitialized() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  /// UTC instant → wall-clock time at [zone] (a UTC-mode DateTime, see
  /// trakta_core's WallTime).
  static DateTime toWall(DateTime instant, String zone) {
    ensureInitialized();
    final t = tz.TZDateTime.from(instant.toUtc(), location(zone));
    return DateTime.utc(t.year, t.month, t.day, t.hour, t.minute);
  }

  /// Wall-clock time at [zone] → UTC instant.
  static DateTime fromWall(DateTime wall, String zone) {
    ensureInitialized();
    final t = tz.TZDateTime(location(zone), wall.year, wall.month, wall.day, wall.hour, wall.minute);
    return DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch, isUtc: true);
  }
}
