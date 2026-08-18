import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/mail/alias_activity.dart';
import 'package:shadow_mobile/models/site_adapter_record.dart';

const MailboxRecord fresh = MailboxRecord(
  state: MailboxState.registered,
  localPart: 'aedo6jovqv2j7guvgzqi',
);

void main() {
  group('recording what arrived', () {
    test('a poll that found mail counts both sides', () {
      final after = AliasActivity.record(
        fresh,
        deliveredSeq: 3,
        opened: 3,
        today: 20000,
      );

      expect(after.delivered, 3);
      expect(after.opened, 3);
      expect(after.unopened, 0);
      expect(after.checkedDay, 20000);
    });

    test('a poll that found nothing still records the check', () {
      // The distinction the card lives on. Without this, "checked, and quiet"
      // and "never looked" render as the same blank, and only one of them is
      // reassuring.
      final after = AliasActivity.record(
        fresh,
        deliveredSeq: 0,
        opened: 0,
        today: 20000,
      );

      expect(after.checkedDay, 20000);
      expect(after.delivered, 0);
    });

    test('the gap between arrived and opened is kept', () {
      // Shadow only fetches while a signup is in flight, so most of what
      // arrives is never read. Hiding that would turn a quiet card into a
      // false all-clear.
      final after = AliasActivity.record(
        fresh,
        deliveredSeq: 12,
        opened: 2,
        today: 20000,
      );

      expect(after.delivered, 12);
      expect(after.opened, 2);
      expect(after.unopened, 10);
    });

    test('opened accumulates across polls, delivered does not double count',
        () {
      var record = AliasActivity.record(
        fresh,
        deliveredSeq: 2,
        opened: 2,
        today: 20000,
      );
      record = AliasActivity.record(
        record,
        deliveredSeq: 5,
        opened: 3,
        today: 20001,
      );

      expect(record.delivered, 5, reason: 'the server sequence, not a sum');
      expect(record.opened, 5);
      expect(record.checkedDay, 20001);
    });

    test('a lower sequence never walks the count backwards', () {
      // A reordered or hostile answer must not erase an arrival the user has
      // already been shown.
      var record = AliasActivity.record(
        fresh,
        deliveredSeq: 9,
        opened: 0,
        today: 20000,
      );
      record = AliasActivity.record(
        record,
        deliveredSeq: 4,
        opened: 0,
        today: 20001,
      );

      expect(record.delivered, 9);
    });

    test('counts saturate rather than growing without bound', () {
      final after = AliasActivity.record(
        fresh,
        deliveredSeq: 500000,
        opened: 500000,
        today: 20000,
      );

      expect(after.delivered, MailboxRecord.countCap);
      expect(after.opened, MailboxRecord.countCap);
    });
  });

  group('dismissing the notice', () {
    test('acknowledging clears it until something new arrives', () {
      var record = AliasActivity.record(
        fresh,
        deliveredSeq: 4,
        opened: 4,
        today: 20000,
      );
      expect(record.unacknowledged, 4);

      record = AliasActivity.acknowledge(record);
      expect(record.unacknowledged, 0);

      record = AliasActivity.record(
        record,
        deliveredSeq: 6,
        opened: 6,
        today: 20001,
      );
      expect(record.unacknowledged, 2, reason: 'only the new ones');
    });

    test('what was dismissed is a number, not a list of senders', () {
      // A per-sender dismissal would be an allowlist, and an allowlist of who
      // may write to you is a correspondent graph sitting in plain storage.
      final record = AliasActivity.acknowledge(
        AliasActivity.record(fresh, deliveredSeq: 3, opened: 3, today: 20000),
      );

      final json = record.toJson();
      expect(json['ack'], 3);
      expect(
        json.keys.any((k) => k.contains('sender') || k.contains('from')),
        isFalse,
      );
    });
  });

  group('what reaches disk', () {
    test('nothing about any message survives a round trip', () {
      final record = AliasActivity.record(
        fresh,
        deliveredSeq: 7,
        opened: 4,
        today: 20000,
      );

      final back = MailboxRecord.fromJson(record.toJson());
      expect(back.delivered, 7);
      expect(back.opened, 4);
      expect(back.checkedDay, 20000);

      // Five integers and a state. No sender, no subject, no body, no time
      // more precise than a day.
      expect(
        record.toJson().keys.toSet(),
        <String>{'state', 'local_part', 'delivered', 'opened', 'checked_day'},
      );
    });

    test('a record written before this feature reads as never checked', () {
      final old = MailboxRecord.fromJson(<String, dynamic>{
        'state': 'registered',
        'local_part': 'aedo6jovqv2j7guvgzqi',
        'cursor': '4',
      });

      expect(old.checkedDay, isNull, reason: 'not zero, which reads as 1970');
      expect(old.delivered, 0);
      expect(old.opened, 0);
    });

    test('a hostile backup cannot plant a permanent alarm', () {
      final tampered = MailboxRecord.fromJson(<String, dynamic>{
        'state': 'registered',
        'delivered': 999999999,
        'opened': -5,
        'checked_day': 999999999,
        'ack': 'not a number',
      });

      expect(tampered.delivered, MailboxRecord.countCap);
      expect(tampered.opened, 0);
      expect(tampered.checkedDay, isNull);
      expect(tampered.acknowledged, 0);
    });
  });

  group('day buckets', () {
    test('a day, never a timestamp', () {
      final a = AliasActivity.dayOf(DateTime.utc(2026, 8, 17, 3, 14));
      final b = AliasActivity.dayOf(DateTime.utc(2026, 8, 17, 23, 59));
      final c = AliasActivity.dayOf(DateTime.utc(2026, 8, 18, 0, 1));

      expect(a, b, reason: 'same day, whatever the hour');
      expect(c, a + 1);
    });
  });
}
