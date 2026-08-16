import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../identity/identity.dart';

/// Opens what the mail Worker sealed.
///
/// The other half of this lives in `services/mail-worker/src/seal.ts`, and
/// the two must agree byte for byte. `services/mail-worker/tool/probe.mjs`
/// is the reference: it seals with the Worker and opens with an independent
/// implementation, so a disagreement shows up there rather than as mail that
/// silently cannot be read.
///
/// Wire format: `epk(32) ‖ nonce(12) ‖ ciphertext ‖ tag(16)`, where the
/// plaintext is `length(4, big-endian) ‖ message ‖ zero padding` to 4, 16 or
/// 64 KB.
class SealedMail {
  SealedMail._();

  static const int _epkBytes = 32;
  static const int _nonceBytes = 12;
  static const int _macBytes = 16;
  static const String _sealSalt = 'shadow.mail.seal.v1';

  /// Smallest envelope that can exist: keys, nonce, tag and the 4 KB bucket.
  static const int _minEnvelope = _epkBytes + _nonceBytes + 4096 + _macBytes;

  static final Hkdf _hkdf = Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  );

  /// Opens [envelope] with the mailbox's sealing key.
  ///
  /// Returns null when the envelope is malformed, truncated, or was not
  /// sealed to this mailbox. Never throws on bad input: this is
  /// attacker-controlled data arriving from a server, and a parse failure
  /// must not be able to take down the poll loop.
  static Future<String?> open({
    required Uint8List envelope,
    required SiteMailboxKeys keys,
  }) async {
    if (envelope.length < _minEnvelope) return null;

    final epk = envelope.sublist(0, _epkBytes);
    final nonce = envelope.sublist(_epkBytes, _epkBytes + _nonceBytes);
    final rest = envelope.sublist(_epkBytes + _nonceBytes);
    if (rest.length <= _macBytes) return null;

    try {
      final keyPair = await keys.sealingKeyPair();
      final myPublicKey = await keys.x25519PublicKey();

      final shared = await X25519().sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: SimplePublicKey(epk, type: KeyPairType.x25519),
      );

      // Never use raw ECDH output as a key, and bind both public keys into
      // the derivation. Without the recipient's key in the info, a
      // ciphertext sealed to one mailbox could be replayed at another and
      // would still open.
      final sealKey = await _hkdf.deriveKey(
        secretKey: shared,
        nonce: utf8.encode(_sealSalt),
        info: <int>[...epk, ...myPublicKey],
      );

      final padded = await AesGcm.with256bits().decrypt(
        SecretBox(
          rest.sublist(0, rest.length - _macBytes),
          nonce: nonce,
          mac: Mac(rest.sublist(rest.length - _macBytes)),
        ),
        secretKey: sealKey,
        aad: epk,
      );

      return _unpad(Uint8List.fromList(padded));
    } on SecretBoxAuthenticationError {
      // Tampered, truncated, or addressed to a different mailbox. All three
      // mean the same thing to a caller: this is not readable mail.
      return null;
    } on ArgumentError {
      return null;
    } on StateError {
      return null;
    }
  }

  /// Strips the length prefix and the padding that hides the real size.
  static String? _unpad(Uint8List padded) {
    if (padded.length < 4) return null;
    final length = ByteData.sublistView(padded).getUint32(0, Endian.big);
    if (length > padded.length - 4) return null;
    try {
      return utf8.decode(padded.sublist(4, 4 + length), allowMalformed: true);
    } on FormatException {
      return null;
    }
  }
}
