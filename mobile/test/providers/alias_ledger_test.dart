import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/identity/identity.dart';
import 'package:shadow_mobile/models/site_adapter_record.dart';
import 'package:shadow_mobile/providers/mailbox_provider.dart';
import 'package:shadow_mobile/services/fetch_outcome.dart';
import 'package:shadow_mobile/services/mailbox_api.dart';
import 'package:shadow_mobile/services/site_adapter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A mail service that answers one poll with a fixed cursor and no messages.
///
/// No messages on purpose: this is about the ledger, and a sealed envelope
/// this test could open would only prove the crypto, which is tested next
/// door.
class FakePollApi extends MailboxApi {
  FakePollApi({required this.cursor}) : super(baseUrl: 'http://fake.invalid');

  final int cursor;
  int polls = 0;

  @override
  Future<FetchOutcome<MailboxPage>> poll({
    required SiteMailboxKeys keys,
    int cursor = 0,
  }) async {
    polls++;
    return FetchSuccess<MailboxPage>(
      MailboxPage(messages: const <SealedMessage>[], cursor: this.cursor),
    );
  }
}

SiteMailboxKeys keysFor(int seed) =>
    SiteMailboxKeys.fromMaterial(Uint8List(64)..fillRange(0, 64, seed));

MailboxProvider providerWith(FakePollApi api) => MailboxProvider(
      mailBaseUrl: () => 'http://fake.invalid',
      apiFactory: (_) => api,
    );

Future<SiteAdapterRecord> seed({
  required String domain,
  required SiteMailboxKeys keys,
  required SiteMode mode,
  MailboxState state = MailboxState.registered,
}) async {
  const service = SiteAdapterService();
  final record = await service.resolve(domain);
  return service.upsert(
    record.copyWith(
      account: record.account.copyWith(
        mode: mode,
        mailbox: MailboxRecord(state: state, localPart: keys.localPart),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('counting arrivals at a per-site alias', () {
    test('a check is recorded even when nothing arrived', () async {
      final keys = keysFor(1);
      await seed(domain: 'githack.com', keys: keys, mode: SiteMode.masked);

      final api = FakePollApi(cursor: 0);
      await providerWith(api).checkNow(keys: keys, domain: 'githack.com');

      final after = await const SiteAdapterService().resolve('githack.com');
      expect(after.account.mailbox.checkedDay, isNotNull);
      expect(after.account.mailbox.delivered, 0);
    });

    test('the server sequence becomes the arrival count', () async {
      final keys = keysFor(2);
      await seed(domain: 'example.com', keys: keys, mode: SiteMode.masked);

      final api = FakePollApi(cursor: 6);
      await providerWith(api).checkNow(keys: keys, domain: 'example.com');

      final after = await const SiteAdapterService().resolve('example.com');
      expect(after.account.mailbox.delivered, 6);
      // Nothing was opened, and the card has to be able to say so rather than
      // implying six messages were read and found harmless.
      expect(after.account.mailbox.opened, 0);
      expect(after.account.mailbox.unopened, 6);
    });
  });

  group('what the ledger refuses to count', () {
    test('a site put back to normal browsing IS still counted', () async {
      // Not an exclusion. The alias registered before the switch is still
      // live and still receiving, and this screen is the only place it can be
      // seen — so refusing to count would leave the check button polling and
      // recording nothing behind a card reading "not checked yet".
      final keys = keysFor(3);
      await seed(domain: 'plain.example', keys: keys, mode: SiteMode.off);

      final api = FakePollApi(cursor: 9);
      await providerWith(api).checkNow(keys: keys, domain: 'plain.example');

      final after = await const SiteAdapterService().resolve('plain.example');
      expect(after.account.mailbox.delivered, 9);
      expect(after.account.mailbox.checkedDay, isNotNull);
    });

    test('the identity-wide public address is never counted', () async {
      // The case this gate exists for. That address is handed to people on
      // purpose, so mail from strangers is the feature working — a card
      // counting arrivals there is noise, and noise teaches a user to ignore
      // the same card on the aliases where it means something.
      final keys = keysFor(4);
      await seed(domain: 'public.example', keys: keys, mode: SiteMode.public);

      final api = FakePollApi(cursor: 40);
      await providerWith(api).checkNow(keys: keys, domain: 'public.example');

      final after = await const SiteAdapterService().resolve('public.example');
      expect(after.account.mailbox.delivered, 0);
      expect(after.account.mailbox.checkedDay, isNull);
    });

    test('a mailbox that was never registered is not counted', () async {
      final keys = keysFor(5);
      await seed(
        domain: 'unregistered.example',
        keys: keys,
        mode: SiteMode.masked,
        state: MailboxState.none,
      );

      final api = FakePollApi(cursor: 5);
      await providerWith(api)
          .checkNow(keys: keys, domain: 'unregistered.example');

      final after =
          await const SiteAdapterService().resolve('unregistered.example');
      expect(after.account.mailbox.delivered, 0);
    });

    test('keys that are not the ones on record are not counted', () async {
      // Guards against attributing one alias's arrivals to another after a
      // burn, when the record still names the old local part.
      final onRecord = keysFor(6);
      final different = keysFor(7);
      await seed(domain: 'moved.example', keys: onRecord, mode: SiteMode.masked);

      final api = FakePollApi(cursor: 11);
      await providerWith(api).checkNow(keys: different, domain: 'moved.example');

      final after = await const SiteAdapterService().resolve('moved.example');
      expect(after.account.mailbox.delivered, 0);
    });
  });
}
