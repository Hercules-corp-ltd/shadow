import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/identity/identity.dart';
import 'package:shadow_mobile/providers/mailbox_provider.dart';
import 'package:shadow_mobile/services/fetch_outcome.dart';
import 'package:shadow_mobile/services/mailbox_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A mail server that knows about a fixed set of addresses.
class FakeMailboxApi extends MailboxApi {
  FakeMailboxApi({required this.registered, this.reachable = true})
      : super(baseUrl: 'http://fake.invalid');

  final Set<String> registered;
  final bool reachable;
  final List<String> probed = <String>[];

  @override
  Future<FetchOutcome<bool>> probe({required SiteMailboxKeys keys}) async {
    probed.add(keys.localPart);
    if (!reachable) {
      return const FetchUnreachable<bool>('offline');
    }
    return FetchSuccess<bool>(registered.contains(keys.localPart));
  }
}

/// Distinct keys per epoch, without needing a real phrase.
SiteMailboxKeys keysFor(int epoch) => SiteMailboxKeys.fromMaterial(
      Uint8List(64)..fillRange(0, 64, epoch),
    );

MailboxProvider providerWith(FakeMailboxApi api) => MailboxProvider(
      mailBaseUrl: () => 'http://fake.invalid',
      apiFactory: (_) => api,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('recovering which alias epoch a site is on', () {
    test('finds the highest registered epoch', () async {
      // Epochs 1 and 2 were used and burned; 2 is where the site is now.
      final api = FakeMailboxApi(registered: <String>{
        keysFor(1).localPart,
        keysFor(2).localPart,
      });

      final found = await providerWith(api).recoverAliasEpoch(
        derive: keysFor,
        maxEpoch: 5,
      );

      expect(found, 2);
    });

    test('returns null when the site has no mailbox at all', () async {
      final api = FakeMailboxApi(registered: <String>{});

      expect(
        await providerWith(api).recoverAliasEpoch(derive: keysFor, maxEpoch: 5),
        isNull,
      );
    });

    test('refuses to answer when the server cannot be reached', () async {
      // The dangerous case. Reporting "found nothing" here would adopt epoch
      // 1 and derive an address the site does not have — mail going nowhere,
      // silently, which is the exact failure this recovery exists to fix.
      final api = FakeMailboxApi(
        registered: <String>{keysFor(3).localPart},
        reachable: false,
      );

      expect(
        await providerWith(api).recoverAliasEpoch(derive: keysFor, maxEpoch: 5),
        isNull,
      );
    });

    test('stops rather than guessing if the identity locks partway', () async {
      final api = FakeMailboxApi(registered: <String>{keysFor(1).localPart});

      final found = await providerWith(api).recoverAliasEpoch(
        // Locks after the first epoch.
        derive: (epoch) => epoch == 1 ? keysFor(1) : null,
        maxEpoch: 5,
      );

      expect(found, isNull);
    });

    test('probes one site, not every site', () async {
      // The reason this is lazy and per site: a sweep would hand the
      // operator a grouping of the user's whole mailbox set, from one IP,
      // in one burst.
      final api = FakeMailboxApi(registered: <String>{keysFor(1).localPart});
      await providerWith(api).recoverAliasEpoch(derive: keysFor, maxEpoch: 4);

      expect(api.probed, hasLength(4));
      expect(api.probed.toSet(), hasLength(4), reason: 'one per epoch');
    });

    test('a gap does not stop the search', () async {
      // Epoch 2's mailbox has expired server-side while 3 is live. Stopping
      // at the first miss would adopt 1 and derive a dead address.
      final api = FakeMailboxApi(registered: <String>{
        keysFor(1).localPart,
        keysFor(3).localPart,
      });

      expect(
        await providerWith(api).recoverAliasEpoch(derive: keysFor, maxEpoch: 5),
        3,
      );
    });
  });
}
