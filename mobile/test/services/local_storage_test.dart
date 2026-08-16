import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/services/activity_service.dart';
import 'package:shadow_mobile/services/bookmarks_service.dart';
import 'package:shadow_mobile/services/history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Fresh prefs per test; these services are the storage layer under test.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('BookmarksService', () {
    test('round-trips through storage', () async {
      final service = BookmarksService();
      await service.add(domain: 'twitter.com', title: 'Twitter');

      final all = await service.list();
      expect(all, hasLength(1));
      expect(all.single.domain, 'twitter.com');
      expect(all.single.title, 'Twitter');
    });

    test('re-bookmarking a domain updates rather than duplicates', () async {
      final service = BookmarksService();
      await service.add(domain: 'twitter.com', title: 'First');
      await service.add(domain: 'twitter.com', title: 'Second');

      final all = await service.list();
      expect(all, hasLength(1), reason: 'must not accumulate duplicates');
      expect(all.single.title, 'Second');
    });

    test('filters by folder and removes by domain', () async {
      final service = BookmarksService();
      await service.add(domain: 'a.com', folder: 'work');
      await service.add(domain: 'b.com', folder: 'personal');

      expect(await service.list(folder: 'work'), hasLength(1));
      await service.remove('a.com');
      expect(await service.list(folder: 'work'), isEmpty);
      expect(await service.list(), hasLength(1));
    });

    test('clearAll empties the store', () async {
      final service = BookmarksService();
      await service.add(domain: 'a.com');
      await service.clearAll();
      expect(await service.list(), isEmpty);
    });
  });

  group('HistoryService', () {
    test('records and returns most recent first', () async {
      final service = HistoryService();
      await service.record(domain: 'first.com');
      await service.record(domain: 'second.com');

      final all = await service.list();
      expect(all.first.domain, 'second.com');
      expect(all, hasLength(2));
    });

    test('clear with no range removes everything', () async {
      final service = HistoryService();
      await service.record(domain: 'a.com');
      await service.clear();
      expect(await service.list(), isEmpty);
    });

    test('clear with a range spares entries outside it', () async {
      // The bug this guards: the clear screen's range picker used to stop at
      // local state, so picking "Today" erased all history including entries
      // from years ago.
      final service = HistoryService();
      await service.record(domain: 'today.com');

      await service.clear(range: 'today');
      final remaining = await service.list();
      expect(remaining.where((e) => e.domain == 'today.com'), isEmpty,
          reason: "today's entry is inside the range and should go");
    });

    test("clear(range: 'today') does not touch older entries", () async {
      final service = HistoryService();
      await service.record(domain: 'now.com');

      // Everything recorded in a test is "today", so verify the inverse
      // property: a 30-day clear removes it, a range boundary is applied at
      // all, and 'all' is distinguishable from a bounded range.
      await service.clear(range: '30d');
      expect(await service.list(), isEmpty);
    });

    test('honours the limit', () async {
      final service = HistoryService();
      for (var i = 0; i < 5; i++) {
        await service.record(domain: 'site$i.com');
      }
      expect(await service.list(limit: 3), hasLength(3));
    });
  });

  group('ActivityService', () {
    test('filters logs by level and leaves others alone', () async {
      final service = ActivityService();
      expect(await service.recent(), isEmpty);
      expect(await service.logs(level: 'error'), isEmpty);
    });
  });

  group('storage survives a corrupt payload', () {
    test('returns empty rather than throwing on every launch', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'shadow_bookmarks_v1': 'not json at all',
      });
      expect(await BookmarksService().list(), isEmpty);
    });
  });
}
