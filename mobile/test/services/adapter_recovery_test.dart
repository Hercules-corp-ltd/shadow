import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/models/site_adapter_record.dart';
import 'package:shadow_mobile/services/site_adapter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const SiteAdapterService service = SiteAdapterService();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('an unrecorded site is one worth probing', () {
    test('a site never touched is unrecorded', () async {
      final record = await service.resolve('twitter.com');
      expect(record.account.isUnrecorded, isTrue);
    });

    test('any state at all makes it recorded', () async {
      await service.setMode('a.com', SiteMode.masked);
      await service.bumpPasswordEpoch('b.com');
      await service.beginAliasBurn('c.com');
      await service.recordSignup('d.com', handleUsed: 'someone1234');
      await service.markMailbox('e.com',
          state: MailboxState.registered, localPart: 'x');

      for (final domain in <String>['a.com', 'b.com', 'c.com', 'd.com', 'e.com']) {
        expect(
          (await service.resolve(domain)).account.isUnrecorded,
          isFalse,
          reason: domain,
        );
      }
    });

    test('a failed registration counts as recorded', () async {
      // Otherwise every fill on a site whose mail server was down would
      // re-probe the whole epoch range, over and over.
      await service.markMailbox('a.com',
          state: MailboxState.failed, localPart: 'x');
      expect((await service.resolve('a.com')).account.isUnrecorded, isFalse);
    });
  });

  group('adopting a recovered alias epoch', () {
    test('writes the epoch and marks the mailbox registered', () async {
      // The probe proved exactly that: the address exists and answers to
      // this key.
      final record = await service.adoptRecoveredAliasEpoch(
        'twitter.com',
        aliasEpoch: 3,
      );

      expect(record.account.aliasEpoch, 3);
      expect(record.account.mailbox.isRegistered, isTrue);
      expect((await service.resolve('twitter.com')).account.aliasEpoch, 3);
    });

    test('never walks a surviving record backwards', () async {
      // A recovery that lowered an epoch would derive an address the site
      // no longer has, which is the failure it exists to prevent.
      await service.beginAliasBurn('twitter.com');
      await service.commitAliasBurn('twitter.com');
      await service.beginAliasBurn('twitter.com');
      await service.commitAliasBurn('twitter.com');
      expect((await service.resolve('twitter.com')).account.aliasEpoch, 3);

      await service.adoptRecoveredAliasEpoch('twitter.com', aliasEpoch: 2);

      expect((await service.resolve('twitter.com')).account.aliasEpoch, 3);
    });

    test('leaves the password epoch alone', () async {
      // The server has never seen anything derived from it, so a recovery
      // has nothing to say about it and must not pretend otherwise.
      await service.bumpPasswordEpoch('twitter.com');
      await service.adoptRecoveredAliasEpoch('twitter.com', aliasEpoch: 4);

      final record = await service.resolve('twitter.com');
      expect(record.account.passwordEpoch, 2);
      expect(record.account.aliasEpoch, 4);
    });

    test('does not disturb a burn in progress', () async {
      await service.beginAliasBurn('twitter.com');
      await service.adoptRecoveredAliasEpoch('twitter.com', aliasEpoch: 2);

      final record = await service.resolve('twitter.com');
      expect(record.account.pendingAliasEpoch, 2);
    });
  });
}
