import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/identity/identity.dart';
import 'package:shadow_mobile/providers/mailbox_provider.dart';
import 'package:shadow_mobile/services/fetch_outcome.dart';
import 'package:shadow_mobile/services/mailbox_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A mail server whose answer to `retire` is whatever the test says it is.
class FakeRetireApi extends MailboxApi {
  FakeRetireApi(this.answer) : super(baseUrl: 'http://fake.invalid');

  final FetchOutcome<void> answer;
  final List<String> retired = <String>[];

  @override
  Future<FetchOutcome<void>> retire({required SiteMailboxKeys keys}) async {
    retired.add(keys.localPart);
    return answer;
  }
}

SiteMailboxKeys keysFor(int epoch) => SiteMailboxKeys.fromMaterial(
      Uint8List(64)..fillRange(0, 64, epoch),
    );

MailboxProvider providerWith(FakeRetireApi api) => MailboxProvider(
      mailBaseUrl: () => 'http://fake.invalid',
      apiFactory: (_) => api,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('closing a mailbox as part of an alias burn', () {
    test('a closed mailbox reports success', () async {
      final api = FakeRetireApi(const FetchSuccess<void>(null));

      expect(
        await providerWith(api).retire(keys: keysFor(1)),
        isA<FetchSuccess<void>>(),
      );
      expect(api.retired, <String>[keysFor(1).localPart]);
    });

    test('a mailbox the server never had stays distinct from a failure',
        () async {
      // This is the resumed-burn case: the address was retired on an earlier
      // attempt, or was never registered because the user never received
      // mail there. Either way it is as closed as it can be, and the burn
      // should be allowed to finish.
      final api = FakeRetireApi(const FetchNotFound<void>());

      expect(
        await providerWith(api).retire(keys: keysFor(2)),
        isA<FetchNotFound<void>>(),
      );
    });

    test('an unreachable server stays distinct from a closed mailbox',
        () async {
      // The whole reason this is not a bool. A burn is what a user reaches
      // for when an address has started attracting mail they did not ask
      // for. Reporting "closed" for a server we never reached would move
      // Shadow onto the new address while the old one quietly keeps
      // collecting — the one outcome the burn exists to prevent.
      final api = FakeRetireApi(const FetchUnreachable<void>('offline'));

      expect(
        await providerWith(api).retire(keys: keysFor(3)),
        isA<FetchUnreachable<void>>(),
      );
    });
  });
}
