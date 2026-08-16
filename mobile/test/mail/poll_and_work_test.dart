import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/mail/poll_schedule.dart';
import 'package:shadow_mobile/mail/registration_work.dart';
import 'package:shadow_mobile/services/fetch_outcome.dart';
import 'package:shadow_mobile/services/mailbox_api.dart';

void main() {
  group('the poll schedule is a pure function', () {
    Duration? at(int seconds, PollTrigger trigger) =>
        PollSchedule.intervalAt(Duration(seconds: seconds), trigger);

    test('a signup is watched closely and then let go', () {
      expect(at(0, PollTrigger.signup), const Duration(seconds: 3));
      expect(at(119, PollTrigger.signup), const Duration(seconds: 3));
      expect(at(121, PollTrigger.signup), const Duration(seconds: 10));
      expect(at(299, PollTrigger.signup), const Duration(seconds: 10));
      expect(at(301, PollTrigger.signup), const Duration(seconds: 30));
      expect(at(899, PollTrigger.signup), const Duration(seconds: 30));
      // Null is "stop". There is no idle polling at all, ever — Shadow talks
      // to the mail server when it has a reason to, and otherwise not.
      expect(at(901, PollTrigger.signup), isNull);
    });

    test('a login gives up after a minute', () {
      expect(at(0, PollTrigger.login), const Duration(seconds: 5));
      expect(at(59, PollTrigger.login), const Duration(seconds: 5));
      expect(at(61, PollTrigger.login), isNull);
    });

    test('a negative elapsed time stops rather than spinning', () {
      expect(
        PollSchedule.intervalAt(const Duration(seconds: -1), PollTrigger.signup),
        isNull,
      );
    });

    test('two password fields is a signup, one is a login', () {
      // Already carried by AutofillResult, so telling them apart needs no
      // new JavaScript in the page.
      expect(PollSchedule.triggerForFill(passwordFieldsSeen: 2),
          PollTrigger.signup);
      expect(PollSchedule.triggerForFill(passwordFieldsSeen: 3),
          PollTrigger.signup);
      expect(PollSchedule.triggerForFill(passwordFieldsSeen: 1),
          PollTrigger.login);
      expect(PollSchedule.triggerForFill(passwordFieldsSeen: 0),
          PollTrigger.login);
    });

    test('a whole signup costs about forty requests', () {
      // Worth pinning: this is the number that has to stay small enough that
      // no push notification is ever needed. A device token would be one
      // stable identifier per install with no per-mailbox variant.
      var elapsed = Duration.zero;
      var polls = 0;
      while (true) {
        final next = PollSchedule.intervalAt(elapsed, PollTrigger.signup);
        if (next == null) break;
        elapsed += next;
        polls++;
      }
      expect(polls, lessThan(80));
      expect(polls, greaterThan(40));
    });
  });

  group('registration work', () {
    test('a mined nonce satisfies the difficulty', () {
      final nonce = RegistrationWork.mine('exkhu6wfl3lx2pexvcgx', bits: 12);
      expect(
        RegistrationWork.satisfies('exkhu6wfl3lx2pexvcgx', nonce, 12),
        isTrue,
      );
    });

    test('the proof is bound to the address it claims', () {
      // Otherwise one proof would buy every address, and the cost would be
      // paid once for an unlimited number of mailboxes.
      final nonce = RegistrationWork.mine('exkhu6wfl3lx2pexvcgx', bits: 12);
      expect(
        RegistrationWork.satisfies('a-different-local-part', nonce, 12),
        isFalse,
      );
    });

    test('an unmined nonce is refused', () {
      expect(
        RegistrationWork.satisfies('exkhu6wfl3lx2pexvcgx', 'not-mined', 20),
        isFalse,
      );
    });

    test('zero bits is satisfied by anything', () {
      expect(RegistrationWork.satisfies('x', 'y', 0), isTrue);
    });
  });

  group('mailbox outcomes never lie about why', () {
    FetchOutcome<int> map(int? status, Object? data) =>
        outcomeFromMailboxResponse<int>(
          statusCode: status,
          data: data,
          parse: (_) => 1,
        );

    test('an empty page is success, not absence', () {
      // "The mailbox exists and nothing has arrived" is a different fact
      // from "there is no mailbox", and the user needs a different sentence
      // for each.
      expect(
        map(200, <String, dynamic>{'ok': true, 'messages': <dynamic>[]}),
        isA<FetchSuccess<int>>(),
      );
    });

    test('404 is not found, so the user can be offered a retry', () {
      expect(map(404, null), isA<FetchNotFound<int>>());
    });

    test('a network failure is never rendered as "no code arrived"', () {
      // The exact failure FetchOutcome exists to prevent. Telling someone
      // their code has not arrived, when the truth is the phone could not
      // ask, costs them the account.
      for (final outcome in <FetchOutcome<int>>[
        map(null, null),
        map(500, null),
        map(401, null),
        map(402, null),
        map(409, null),
        map(200, 'not an object'),
        map(200, <String, dynamic>{'ok': false}),
      ]) {
        expect(outcome, isA<FetchUnreachable<int>>());
        expect((outcome as FetchUnreachable<int>).reason, isNotEmpty);
      }
    });

    test('each refusal says something different', () {
      String reason(int status) =>
          (map(status, null) as FetchUnreachable<int>).reason;

      expect(reason(401), contains('signature'));
      expect(reason(409), contains('different key'));
      expect(reason(402), contains('work'));
    });
  });

  group('the registration receipt is checked, not trusted', () {
    test('matches only the exact key', () {
      final receipt = MailboxReceipt(
        localPart: 'x',
        x25519PublicKey: Uint8List.fromList(<int>[1, 2, 3, 4]),
      );

      expect(receipt.matches(Uint8List.fromList(<int>[1, 2, 3, 4])), isTrue);
      expect(receipt.matches(Uint8List.fromList(<int>[1, 2, 3, 5])), isFalse);
      expect(receipt.matches(Uint8List.fromList(<int>[1, 2, 3])), isFalse);
      expect(receipt.matches(Uint8List.fromList(<int>[])), isFalse);
    });
  });
}
