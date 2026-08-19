import '../models/activity.dart';
import 'local_store.dart';

/// A record of what you did in this app, kept on the device.
///
/// Both routes it used were absent. More to the point, the server-side version
/// of this was analytics on the people using an anonymity product, which
/// `docs/decisions/0001-postgres-on-supabase.md` marks for deletion rather
/// than migration. Kept local it is a useful log for the person it describes,
/// and nobody else can read it.
class ActivityService {
  static const _store = LocalStore<ActivityEntry>(
    key: 'shadow_activity_v1',
    encode: _encode,
    decode: ActivityEntry.fromJson,
  );

  static Map<String, dynamic> _encode(ActivityEntry e) => e.toJson();

  Future<List<ActivityEntry>> recent({int limit = 25}) async {
    final all = await _store.readAll()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all.take(limit).toList();
  }

  /// The same log, filtered. [level] matches [ActivityEntry.status].
  Future<List<ActivityEntry>> logs({int limit = 100, String? level}) async {
    final all = await recent(limit: _maxEntries);
    final filtered = level == null || level == 'all'
        ? all
        : all.where((e) => e.status == level).toList();
    return filtered.take(limit).toList();
  }

  Future<void> record(ActivityEntry entry) async {
    final all = await _store.readAll()
      ..add(entry);
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await _store.writeAll(all.take(_maxEntries).toList());
  }

  Future<void> clearAll() => _store.clear();

  static const int _maxEntries = 500;
}
