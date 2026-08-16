import '../models/history_entry.dart';
import 'local_store.dart';

/// Browsing history, kept on the device.
///
/// This is the one that most needed moving. A privacy browser posting every
/// page its users visit to a server is the contradiction at the centre of the
/// old design — and it did not even work: `GET /history` 400'd because the
/// handler required a `q` query parameter the client never sent, and the
/// server ignored `range` entirely.
class HistoryService {
  static const _store = LocalStore<HistoryEntry>(
    key: 'shadow_history_v1',
    encode: _encode,
    decode: HistoryEntry.fromJson,
  );

  static Map<String, dynamic> _encode(HistoryEntry e) => e.toJson();

  /// Most recent first.
  Future<List<HistoryEntry>> list({int limit = 50, String? range}) async {
    final all = await _store.readAll()
      ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    final cutoff = _cutoffFor(range);
    final windowed = cutoff == null
        ? all
        : all.where((e) => e.visitedAt.isAfter(cutoff)).toList();
    return windowed.take(limit).toList();
  }

  Future<void> record({
    required String domain,
    String? programAddress,
    String? title,
    int timeSpentSeconds = 0,
  }) async {
    final all = await _store.readAll();
    all.add(HistoryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      domain: domain,
      programAddress: programAddress,
      title: title,
      visitedAt: DateTime.now(),
      timeSpentSeconds: timeSpentSeconds,
    ));

    // Bounded, so history cannot grow without limit on a device.
    all.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    await _store.writeAll(all.take(_maxEntries).toList());
  }

  /// Clears history within [range], or everything when null or 'all'.
  ///
  /// The range genuinely applies here. It previously stopped at the clear
  /// screen's local state and never reached the delete, so choosing "Today"
  /// erased the lot.
  Future<void> clear({String? range}) async {
    final cutoff = _cutoffFor(range);
    if (cutoff == null) {
      await _store.clear();
      return;
    }
    final all = await _store.readAll();
    await _store.writeAll(
      all.where((e) => !e.visitedAt.isAfter(cutoff)).toList(),
    );
  }

  static const int _maxEntries = 2000;

  /// Entries newer than the returned instant are in range. Null means
  /// "no limit", i.e. everything.
  static DateTime? _cutoffFor(String? range) {
    final now = DateTime.now();
    switch (range) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case 'yesterday':
        return DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      case 'all':
      case null:
      default:
        return null;
    }
  }
}
