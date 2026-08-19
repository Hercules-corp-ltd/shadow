import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/identity/identity.dart';
import 'package:shadow_mobile/providers/public_address_provider.dart';
import 'package:shadow_mobile/services/mailbox_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A mail service whose answers the test dictates.
class FakeClaimApi extends MailboxApi {
  FakeClaimApi({this.claimAnswer, this.lookupAnswer})
      : super(baseUrl: 'http://fake.invalid');

  ClaimResult? claimAnswer;
  ClaimResult? lookupAnswer;

  final List<String> claimed = <String>[];
  int lookups = 0;

  @override
  Future<ClaimResult> claim({
    required SiteMailboxKeys keys,
    required String name,
    required String powNonce,
  }) async {
    claimed.add(name);
    return claimAnswer ?? const ClaimUnreachable('no answer configured');
  }

  @override
  Future<ClaimResult> claimedName({required SiteMailboxKeys keys}) async {
    lookups++;
    return lookupAnswer ?? const ClaimUnreachable('no answer configured');
  }
}

SiteMailboxKeys theKeys() =>
    SiteMailboxKeys.fromMaterial(Uint8List(64)..fillRange(0, 64, 9));

PublicAddressProvider providerWith(FakeClaimApi api) => PublicAddressProvider(
      mailBaseUrl: () => 'http://fake.invalid',
      apiFactory: (_) => api,
      // Keep the test off the real hashcash cost.
      powBits: 1,
    );

/// The constructor reads storage, so settle before asserting on state.
Future<PublicAddressProvider> ready(FakeClaimApi api) async {
  final provider = providerWith(api);
  await Future<void>.delayed(Duration.zero);
  return provider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('before anything is known', () {
    test('a fresh install does not claim to own nothing', () async {
      // The distinction this whole state machine exists for. "We have not
      // asked" must not render as "you own nothing", because only the second
      // one should offer a button that cannot be undone.
      final provider = await ready(FakeClaimApi());
      expect(provider.state, PublicAddressState.unknown);
      expect(provider.claimed, isNull);
    });

    test('an unreachable service leaves the state unknown, not none', () async {
      final api = FakeClaimApi(lookupAnswer: const ClaimUnreachable('offline'));
      final provider = await ready(api);

      await provider.refresh(keys: theKeys());

      expect(provider.state, PublicAddressState.unknown);
      expect(provider.lastProblem, 'offline');
    });

    test('only a real answer moves the state to none', () async {
      final api = FakeClaimApi(lookupAnswer: const ClaimNone());
      final provider = await ready(api);

      await provider.refresh(keys: theKeys());

      expect(provider.state, PublicAddressState.none);
    });

    test('a held name is adopted from the lookup', () async {
      final api = FakeClaimApi(
        lookupAnswer: const ClaimHeld(name: 'alice', retired: false),
      );
      final provider = await ready(api);

      await provider.refresh(keys: theKeys());

      expect(provider.state, PublicAddressState.held);
      expect(provider.claimed?.name, 'alice');
    });
  });

  group('asking on screen open', () {
    test('ensureKnown asks even when storage has not finished loading',
        () async {
      // The defect this covers: the screen asks in a post-frame callback, which
      // fires while the provider is still reading storage. A state check at
      // that moment sees 'loading', decides there is nothing to do, and the
      // lookup never happens — leaving the screen reporting that it could not
      // reach the mail service when it had not tried.
      final api = FakeClaimApi(lookupAnswer: const ClaimNone());
      final provider = providerWith(api); // deliberately not settled

      await provider.ensureKnown(keys: theKeys());

      expect(api.lookups, 1);
      expect(provider.state, PublicAddressState.none);
    });

    test('ensureKnown does not ask when a name is already on disk', () async {
      final held = FakeClaimApi(
        claimAnswer: const ClaimHeld(name: 'alice', retired: false),
      );
      final first = await ready(held);
      await first.claim(keys: theKeys(), name: 'alice');

      final api = FakeClaimApi(lookupAnswer: const ClaimNone());
      final second = providerWith(api);
      await second.ensureKnown(keys: theKeys());

      expect(api.lookups, 0, reason: 'already knew');
      expect(second.claimed?.name, 'alice');
    });

    test('nothing claims a lookup failed before one was made', () async {
      final provider = await ready(FakeClaimApi());
      expect(provider.hasAsked, isFalse);

      await provider.refresh(keys: theKeys());
      expect(provider.hasAsked, isTrue);
    });
  });

  group('claiming', () {
    test('a name that breaks the rule never reaches the network', () async {
      // Refused locally so the user hears the real reason immediately instead
      // of waiting seconds for an opaque status the server cannot explain.
      final api = FakeClaimApi();
      final provider = await ready(api);

      final result = await provider.claim(keys: theKeys(), name: 'Alice1');

      expect(result, isA<ClaimRefused>());
      expect(api.claimed, isEmpty);
    });

    test('an alias-shaped name never reaches the network either', () async {
      final api = FakeClaimApi();
      final provider = await ready(api);

      final alias = theKeys().localPart;
      final result = await provider.claim(keys: theKeys(), name: alias);

      expect(result, isA<ClaimRefused>());
      expect(api.claimed, isEmpty);
    });

    test('a successful claim is remembered', () async {
      final api = FakeClaimApi(
        claimAnswer: const ClaimHeld(name: 'alice', retired: false),
      );
      final provider = await ready(api);

      await provider.claim(keys: theKeys(), name: 'alice');

      expect(provider.state, PublicAddressState.held);
      expect(provider.claimed?.name, 'alice');
    });

    test('the server may answer with a different name, and that wins',
        () async {
      // One identity holds one name, so a claim from a key that already has
      // one returns the one it has. This is how a reinstall recovers, and the
      // stored value has to follow the server rather than what was typed.
      final api = FakeClaimApi(
        claimAnswer: const ClaimHeld(name: 'alice', retired: false),
      );
      final provider = await ready(api);

      final result = await provider.claim(keys: theKeys(), name: 'bassoon');

      expect((result as ClaimHeld).name, 'alice');
      expect(provider.claimed?.name, 'alice');
    });

    test('a taken name changes nothing on the device', () async {
      final api = FakeClaimApi(claimAnswer: const ClaimTaken());
      final provider = await ready(api);
      await provider.refresh(keys: theKeys());

      final result = await provider.claim(keys: theKeys(), name: 'alice');

      expect(result, isA<ClaimTaken>());
      expect(provider.claimed, isNull);
    });

    test('an unreachable claim records nothing either way', () async {
      // The request may have landed with the reply lost, so the device knows
      // neither that the name was claimed nor that it was not. Writing either
      // one down would be a guess presented as a fact.
      final api = FakeClaimApi(claimAnswer: const ClaimUnreachable('timeout'));
      final provider = await ready(api);

      final result = await provider.claim(keys: theKeys(), name: 'alice');

      expect(result, isA<ClaimUnreachable>());
      expect(provider.claimed, isNull);
      expect(provider.state, PublicAddressState.unknown);
    });
  });

  group('persistence', () {
    test('a claimed name survives a restart without asking again', () async {
      final api = FakeClaimApi(
        claimAnswer: const ClaimHeld(name: 'alice', retired: true),
      );
      final first = await ready(api);
      await first.claim(keys: theKeys(), name: 'alice');

      final second = await ready(FakeClaimApi());

      expect(second.state, PublicAddressState.held);
      expect(second.claimed?.name, 'alice');
      expect(second.claimed?.retired, isTrue);
    });
  });
}
