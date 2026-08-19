import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/identity/identity.dart';
import 'package:shadow_mobile/mail/sealed_mail.dart';

import 'worker_fixture.dart';

/// The mailbox the fixture was sealed to.
SiteMailboxKeys fixtureKeys() {
  final material = Uint8List(64)
    ..setAll(0, base64Decode(fixtureSignSeedB64))
    ..setAll(32, base64Decode(fixtureSealSeedB64));
  return SiteMailboxKeys.fromMaterial(material);
}

void main() {
  group('the two implementations agree', () {
    test('the local part matches what the Worker computed', () {
      // If this drifts, every address in the app points at a mailbox the
      // server has never heard of, and mail goes nowhere with no error.
      expect(fixtureKeys().localPart, fixtureLocalPart);
    });

    test('the public keys match', () async {
      final keys = fixtureKeys();
      expect(base64Encode(keys.ed25519PublicKey), fixtureEd25519PubB64);
      expect(base64Encode(await keys.x25519PublicKey()), fixtureX25519PubB64);
    });

    test('an envelope sealed by the Worker opens here', () async {
      // The test that actually matters. Sealing and opening with the same
      // Dart code would only prove self-consistency; the two halves are in
      // different languages on different runtimes with different crypto
      // libraries, and they have to agree byte for byte.
      final opened = await SealedMail.open(
        envelope: base64Decode(fixtureEnvelopeB64),
        keys: fixtureKeys(),
      );

      expect(opened, fixturePlaintext);
      expect(opened, contains('483920'));
    });

    test('the padding hides the real length', () {
      final envelope = base64Decode(fixtureEnvelopeB64);
      // 32 epk + 12 nonce + 4096 bucket + 16 tag.
      expect(envelope.length, 4156);
      // A 90-byte message and a 3000-byte message are indistinguishable on
      // the wire, which is what stops a site padding its own mail so the
      // length encodes an account id.
      expect(envelope.length, greaterThan(fixturePlaintext.length * 10));
    });
  });

  group('opening refuses rather than throwing', () {
    test('a tampered envelope returns null', () async {
      final envelope = base64Decode(fixtureEnvelopeB64);
      envelope[envelope.length - 1] ^= 0xFF;

      expect(
        await SealedMail.open(envelope: envelope, keys: fixtureKeys()),
        isNull,
      );
    });

    test('a flipped ephemeral key returns null', () async {
      final envelope = base64Decode(fixtureEnvelopeB64);
      envelope[0] ^= 0x01;

      expect(
        await SealedMail.open(envelope: envelope, keys: fixtureKeys()),
        isNull,
      );
    });

    test('a different mailbox cannot open it', () async {
      // The transcript binds both public keys into the derivation, so a
      // ciphertext cannot be replayed at another mailbox.
      final other =
          SiteMailboxKeys.fromMaterial(Uint8List(64)..fillRange(0, 64, 3));

      expect(
        await SealedMail.open(
          envelope: base64Decode(fixtureEnvelopeB64),
          keys: other,
        ),
        isNull,
      );
    });

    test('truncated and empty input return null', () async {
      final keys = fixtureKeys();
      expect(await SealedMail.open(envelope: Uint8List(0), keys: keys), isNull);
      expect(
          await SealedMail.open(envelope: Uint8List(60), keys: keys), isNull);
      expect(
        await SealedMail.open(
          envelope: base64Decode(fixtureEnvelopeB64).sublist(0, 200),
          keys: keys,
        ),
        isNull,
      );
    });

    test('random bytes of a plausible length return null', () async {
      final noise = Uint8List(4156);
      for (var i = 0; i < noise.length; i++) {
        noise[i] = (i * 31 + 7) & 0xFF;
      }
      expect(
        await SealedMail.open(envelope: noise, keys: fixtureKeys()),
        isNull,
      );
    });
  });
}
