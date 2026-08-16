import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/identity/identity.dart';

const String testPhrase =
    'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';

const String aliasDomain = 'mail.shadow.test';

void main() {
  final engine = ShadowIdentity.fromMnemonic(testPhrase, passphrase: 'unit-test');

  group('mailbox derivation', () {
    test('is deterministic', () {
      final rebuilt =
          ShadowIdentity.fromMnemonic(testPhrase, passphrase: 'unit-test');
      expect(
        engine.mailboxKeysFor('twitter.com').localPart,
        rebuilt.mailboxKeysFor('twitter.com').localPart,
      );
    });

    test('gives every site an unrelated mailbox', () {
      final a = engine.mailboxKeysFor('twitter.com');
      final b = engine.mailboxKeysFor('reddit.com');

      expect(a.localPart, isNot(b.localPart));
      expect(a.ed25519PublicKey, isNot(b.ed25519PublicKey));
    });

    test('normalises the host the same way credentials do', () {
      expect(
        engine.mailboxKeysFor('https://www.twitter.com/signup').localPart,
        engine.mailboxKeysFor('twitter.com').localPart,
      );
    });

    test('a different passphrase is a different mailbox', () {
      final other = ShadowIdentity.fromMnemonic(testPhrase, passphrase: 'other');
      expect(
        engine.mailboxKeysFor('twitter.com').localPart,
        isNot(other.mailboxKeysFor('twitter.com').localPart),
      );
    });

    test('rejects an out-of-range account index or epoch', () {
      expect(() => engine.mailboxKeysFor('a.com', accountIndex: -1),
          throwsArgumentError);
      expect(() => engine.mailboxKeysFor('a.com', aliasEpoch: 0),
          throwsArgumentError);
      expect(() => engine.handleMailboxKeys(handleEpoch: 0),
          throwsArgumentError);
    });

    test('is refused after wipe', () {
      final wiped = ShadowIdentity.fromMnemonic(testPhrase)..wipe();
      expect(() => wiped.mailboxKeysFor('a.com'), throwsStateError);
      expect(() => wiped.handleMailboxKeys(), throwsStateError);
    });
  });

  group('the local part certifies itself', () {
    test('is exactly 20 lowercase base32 characters', () {
      final localPart = engine.mailboxKeysFor('twitter.com').localPart;
      expect(localPart.length, 20);
      expect(localPart, matches(RegExp(r'^[a-z2-7]{20}$')));
    });

    test('is the domain-separated hash of the public key, and nothing else',
        () {
      // Recomputed here from first principles rather than by calling the
      // same code path. This is the property the mail server relies on to
      // decide that a registration is legitimate without knowing anything
      // about who is registering, so it is worth checking independently.
      final keys = engine.mailboxKeysFor('twitter.com');
      final expected = base32Encode(
        sha256
            .convert(<int>[
              ...utf8.encode('shadow.mail.localpart.v1'),
              ...keys.ed25519PublicKey,
            ])
            .bytes,
      ).substring(0, 20);

      expect(keys.localPart, expected);
    });

    test('a signature verifies against the advertised public key', () {
      final keys = engine.mailboxKeysFor('twitter.com');
      final message = utf8.encode('mail-poll/v1|${keys.localPart}|12345');
      final signature = keys.sign(message);

      expect(
        ed.verify(ed.PublicKey(keys.ed25519PublicKey), message, signature),
        isTrue,
      );
      // ...and not against a different mailbox's key.
      final other = engine.mailboxKeysFor('reddit.com');
      expect(
        ed.verify(ed.PublicKey(other.ed25519PublicKey), message, signature),
        isFalse,
      );
    });

    test('builds the address at whatever domain it is given', () {
      final keys = engine.mailboxKeysFor('twitter.com');
      expect(keys.addressAt(aliasDomain), '${keys.localPart}@$aliasDomain');
      expect(keys.addressAt('@MAIL.Shadow.Test  '),
          '${keys.localPart}@mail.shadow.test');
    });
  });

  group('the sealing key', () {
    test('is 32 bytes and deterministic', () async {
      final a = await engine.mailboxKeysFor('twitter.com').x25519PublicKey();
      final b = await engine.mailboxKeysFor('twitter.com').x25519PublicKey();

      expect(a.length, 32);
      expect(a, b);
    });

    test('is independent of the signing key', () async {
      final keys = engine.mailboxKeysFor('twitter.com');
      final sealing = await keys.x25519PublicKey();
      expect(sealing, isNot(keys.ed25519PublicKey));
    });
  });

  group('the shareable handle mailbox', () {
    test('is not keyed on any site', () {
      final handle = engine.handleMailboxKeys();
      expect(handle.localPart,
          isNot(engine.mailboxKeysFor('twitter.com').localPart));
      expect(handle.localPart, engine.handleMailboxKeys().localPart);
    });

    test('has its own epoch', () {
      expect(
        engine.handleMailboxKeys(handleEpoch: 1).localPart,
        isNot(engine.handleMailboxKeys(handleEpoch: 2).localPart),
      );
    });
  });

  group('mailbox keys are wipeable', () {
    test('refuse to work afterwards', () {
      final keys = engine.mailboxKeysFor('twitter.com')..wipe();
      expect(() => keys.localPart, throwsStateError);
      expect(() => keys.sign(<int>[1]), throwsStateError);
      expect(keys.toString(), contains('wiped'));
    });

    test('do not leak key material through toString', () {
      final keys = engine.mailboxKeysFor('twitter.com');
      expect(keys.toString(), isNot(contains(keys.localPart)));
    });
  });
}
