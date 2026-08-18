import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/models/site_adapter_record.dart';
import 'package:shadow_mobile/services/site_adapter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String storeKey = 'shadow_site_adapters_v1';
const SiteAdapterService service = SiteAdapterService();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('defaults', () {
    test('an unknown site resolves to off, epoch 1, no mailbox', () async {
      final record = await service.resolve('twitter.com');

      expect(record.domain, 'twitter.com');
      expect(record.account.mode, SiteMode.off);
      expect(record.account.passwordEpoch, 1);
      expect(record.account.aliasEpoch, 1);
      expect(record.account.mailbox.state, MailboxState.none);
      expect(record.account.isBurning, isFalse);
    });

    test('off is the default, so merely visiting a site records nothing',
        () async {
      // The mail service must never learn about a site the user only looked
      // at. That property starts here: nothing is written until a mode is
      // chosen.
      await service.resolve('twitter.com');
      expect(await service.list(), isEmpty);
      expect(await service.configured(), isEmpty);
    });

    test('two accounts on one site are two records', () async {
      await service.setMode('twitter.com', SiteMode.masked);
      await service.setMode('twitter.com', SiteMode.public, accountIndex: 1);

      expect(
        (await service.resolve('twitter.com')).account.mode,
        SiteMode.masked,
      );
      expect(
        (await service.resolve('twitter.com', accountIndex: 1)).account.mode,
        SiteMode.public,
      );
      expect(await service.list(), hasLength(2));
    });
  });

  group('rotation counters', () {
    test('bumping the password epoch leaves the alias epoch alone', () async {
      await service.bumpPasswordEpoch('twitter.com');
      final record = await service.resolve('twitter.com');

      expect(record.account.passwordEpoch, 2);
      expect(record.account.aliasEpoch, 1);
    });

    test('they persist across reads', () async {
      await service.bumpPasswordEpoch('twitter.com');
      await service.bumpPasswordEpoch('twitter.com');

      expect((await service.resolve('twitter.com')).account.passwordEpoch, 3);
    });
  });

  group('burning an alias is two-phase', () {
    test('begin does not move the live epoch', () async {
      // Adopting the new epoch immediately would strand the user: the record
      // would say 2 while the site still mails 1, and the old mailbox would
      // already be gone.
      await service.beginAliasBurn('twitter.com');
      final record = await service.resolve('twitter.com');

      expect(record.account.aliasEpoch, 1);
      expect(record.account.pendingAliasEpoch, 2);
      expect(record.account.isBurning, isTrue);
    });

    test('commit adopts it and drops the pending marker', () async {
      await service.beginAliasBurn('twitter.com');
      await service.commitAliasBurn('twitter.com');
      final record = await service.resolve('twitter.com');

      expect(record.account.aliasEpoch, 2);
      expect(record.account.pendingAliasEpoch, isNull);
      expect(record.account.isBurning, isFalse);
      // The new address has not been registered yet.
      expect(record.account.mailbox.state, MailboxState.none);
    });

    test('abandon leaves the old address live', () async {
      await service.beginAliasBurn('twitter.com');
      await service.abandonAliasBurn('twitter.com');
      final record = await service.resolve('twitter.com');

      expect(record.account.aliasEpoch, 1);
      expect(record.account.isBurning, isFalse);
    });

    test('beginning twice does not skip an epoch', () async {
      await service.beginAliasBurn('twitter.com');
      await service.beginAliasBurn('twitter.com');

      expect(
        (await service.resolve('twitter.com')).account.pendingAliasEpoch,
        2,
      );
    });

    test('committing without beginning does nothing', () async {
      await service.commitAliasBurn('twitter.com');
      expect((await service.resolve('twitter.com')).account.aliasEpoch, 1);
    });
  });

  group('mailbox and signup state', () {
    test('records where the mailbox got to', () async {
      await service.markMailbox(
        'twitter.com',
        state: MailboxState.registered,
        localPart: 'hbsq2dsr3ffksbwlsklb',
        aliasDomain: 'mail.shadow.test',
      );
      final record = await service.resolve('twitter.com');

      expect(record.account.mailbox.isRegistered, isTrue);
      expect(record.account.mailbox.localPart, 'hbsq2dsr3ffksbwlsklb');
    });

    test('remembers the handle actually used, not the derived one', () async {
      await service.recordSignup('twitter.com', handleUsed: 'quietharbor4821');
      expect(
        (await service.resolve('twitter.com')).account.registeredHandle,
        'quietharbor4821',
      );
    });
  });

  group('decoding is total, because losing this data is not free', () {
    test('round-trips everything', () async {
      await service.setMode('twitter.com', SiteMode.masked);
      await service.bumpPasswordEpoch('twitter.com');
      await service.beginAliasBurn('twitter.com');
      await service.recordSignup('twitter.com', handleUsed: 'someone1234');
      await service.markMailbox('twitter.com',
          state: MailboxState.registered, localPart: 'abc');

      final json = (await service.resolve('twitter.com')).toJson();
      final restored =
          SiteAdapterRecord.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);

      expect(restored.account.mode, SiteMode.masked);
      expect(restored.account.passwordEpoch, 2);
      expect(restored.account.pendingAliasEpoch, 2);
      expect(restored.account.registeredHandle, 'someone1234');
      expect(restored.account.mailbox.localPart, 'abc');
      expect(restored.policy.passwordPolicy.preferredLength,
          const SitePolicy().passwordPolicy.preferredLength);
    });

    test('a malformed field costs its own value, not the record', () {
      final record = SiteAdapterRecord.fromJson(<String, dynamic>{
        'domain': 'twitter.com',
        'account_index': 'not a number',
        'mode': 'nonsense',
        'account': <String, dynamic>{
          'password_epoch': 'three',
          'alias_epoch': 0,
          'mailbox': 'not an object',
        },
        'policy': 'not an object',
      });

      expect(record.domain, 'twitter.com');
      expect(record.accountIndex, 0);
      expect(record.account.passwordEpoch, 1);
      // Zero is not a smaller epoch, it is a derivation that throws.
      expect(record.account.aliasEpoch, 1);
      expect(record.account.mailbox.state, MailboxState.none);
    });

    test('a record from a newer schema still yields usable defaults', () {
      final record = SiteAdapterRecord.fromJson(<String, dynamic>{
        'schema': 99,
        'domain': 'twitter.com',
        'something_from_the_future': <String, dynamic>{'x': 1},
        'account': <String, dynamic>{'password_epoch': 4},
      });

      expect(record.account.passwordEpoch, 4);
      expect(record.account.mode, SiteMode.off);
    });

    test('one corrupt record does not empty the whole store', () async {
      // LocalStore returns [] on a FormatException, which is right for
      // bookmarks and wrong here: an empty list silently resets every
      // rotation counter, so the client re-derives epoch-1 credentials for
      // sites the user has already rotated. Wrong password, wrong address,
      // no error anywhere.
      SharedPreferences.setMockInitialValues(<String, Object>{
        storeKey: jsonEncode(<dynamic>[
          <String, dynamic>{'domain': 'good.com', 'account': <String, dynamic>{'password_epoch': 5}},
          <String, dynamic>{'domain': 'weird.com', 'account': 42, 'policy': true},
        ]),
      });

      final all = await service.list();
      expect(all, hasLength(2));
      expect((await service.resolve('good.com')).account.passwordEpoch, 5);
      expect((await service.resolve('weird.com')).account.passwordEpoch, 1);
    });
  });

  group('forgetting', () {
    test('drops one site and leaves the rest', () async {
      await service.setMode('twitter.com', SiteMode.masked);
      await service.setMode('reddit.com', SiteMode.masked);

      await service.forget('twitter.com');

      expect(await service.list(), hasLength(1));
      expect((await service.resolve('twitter.com')).account.mode, SiteMode.off);
    });
  });

  group("sites that still hold an address", () {
    test("a site put back to normal browsing keeps its address visible",
        () async {
      // The defect: configured() filtered on mode alone, so switching a site
      // back to normal browsing hid an address that was still registered and
      // still accepting mail. Nothing could show what arrived at it and
      // nothing could retire it — an address the user cannot see is one they
      // cannot close.
      const service = SiteAdapterService();
      final record = await service.resolve("fomo.family");
      await service.upsert(
        record.copyWith(
          account: record.account.copyWith(
            mode: SiteMode.off,
            mailbox: const MailboxRecord(
              state: MailboxState.registered,
              localPart: "4fq6qacjd6dmjecfhdmk",
            ),
          ),
        ),
      );

      final listed = await service.configured();
      expect(listed.map((r) => r.domain), contains("fomo.family"));
    });

    test("a site with no mode and no mailbox stays out of the list", () async {
      const service = SiteAdapterService();
      final record = await service.resolve("visited.example");
      await service.upsert(record);

      final listed = await service.configured();
      expect(listed.map((r) => r.domain), isNot(contains("visited.example")));
    });
  });
}
