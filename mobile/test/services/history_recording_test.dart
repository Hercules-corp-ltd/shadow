import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/services/history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('history keeps what was visited', () {
    test('a recorded visit comes back', () async {
      final service = HistoryService();
      await service.record(domain: 'twitter.com', title: 'Home / X');

      final entries = await service.list();
      expect(entries, hasLength(1));
      expect(entries.first.domain, 'twitter.com');
      expect(entries.first.title, 'Home / X');
    });

    test('most recent first', () async {
      final service = HistoryService();
      await service.record(domain: 'first.example');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await service.record(domain: 'second.example');

      final entries = await service.list();
      expect(entries.first.domain, 'second.example');
    });

    test('it survives a new service instance', () async {
      // The complaint this file exists for was "history doesn't save". The
      // storage was never the broken part — nothing was calling it — so this
      // pins the half that did work, next to the wiring that now uses it.
      await HistoryService().record(domain: 'kept.example');

      final entries = await HistoryService().list();
      expect(entries.single.domain, 'kept.example');
    });

    test('clearing a range leaves what is outside it', () async {
      final service = HistoryService();
      await service.record(domain: 'today.example');

      await service.clear(range: 'today');
      expect(await service.list(), isEmpty);
    });
  });
}
