import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import 'shadow_kdf.dart';

/// The two keys that make a derived address a mailbox somebody owns.
///
/// - **Ed25519** proves ownership. The address itself is a hash of this
///   public key, so "I own this mailbox" is a signature, not an account.
/// - **X25519** receives. Mail is sealed to it on arrival, and only this
///   device can open it.
///
/// Both come from the same HKDF block off the identity branch, and neither
/// private half ever leaves this object — callers get public keys and
/// operations. Two keypairs rather than one because converting an Ed25519
/// key to its Montgomery form would mean hand-writing the birational map in
/// the most dangerous possible place, and would collapse signing and key
/// exchange onto one key for the sake of 32 bytes.
class SiteMailboxKeys {
  SiteMailboxKeys._(this._signingSeed, this._sealingSeed)
      : _signingKey = ed.newKeyFromSeed(Uint8List.fromList(_signingSeed));

  /// Splits the 64 bytes of `mail/v1` (or `handle/v1`) material.
  factory SiteMailboxKeys.fromMaterial(Uint8List material) {
    if (material.length != materialLength) {
      throw ArgumentError.value(
        material.length,
        'material',
        'mailbox material must be exactly $materialLength bytes',
      );
    }
    return SiteMailboxKeys._(
      material.sublist(0, 32),
      material.sublist(32, 64),
    );
  }

  static const int materialLength = 64;

  /// How many base32 characters of the address hash to keep: 100 bits.
  ///
  /// This one number is the whole security parameter of the address, because
  /// the address *is* the hash. Twelve characters (60 bits) is a break, not a
  /// weakness, and the reason is multi-target rather than single-target work.
  /// The mail server rejects unregistered local parts — which is what stops
  /// the domain looking like a catch-all — and that also makes the registered
  /// set enumerable over SMTP. Grinding against a known set of N addresses
  /// costs 2^bits / N, so at 2^23 mailboxes 60 bits falls to about 2^37,
  /// which is minutes. 80 bits gives 2^57. 100 bits leaves 2^77 and puts
  /// accidental collisions in a now-shared namespace out of reach too.
  ///
  /// The cost is four characters in an address that is machine-filled and
  /// which nobody ever reads aloud.
  static const int localPartLength = 20;

  /// Domain-separated so this digest can never collide with another use of
  /// SHA-256 over the same public key.
  static const String _localPartContext = 'shadow.mail.localpart.v1';

  final List<int> _signingSeed;
  final List<int> _sealingSeed;
  final ed.PrivateKey _signingKey;

  bool _wiped = false;

  /// Proves ownership of [localPart]. Public, safe to log or send.
  Uint8List get ed25519PublicKey {
    _assertUsable();
    return Uint8List.fromList(ed.public(_signingKey).bytes);
  }

  /// The address, without the domain.
  ///
  /// Self-certifying: to claim it you must present a key that hashes to it
  /// and sign with the matching private half. There is no account to create
  /// and nothing for the server to remember about who you are.
  String get localPart {
    _assertUsable();
    final digest = sha256.convert(<int>[
      ...utf8.encode(_localPartContext),
      ...ed25519PublicKey,
    ]);
    return base32Encode(digest.bytes).substring(0, localPartLength);
  }

  /// The full address at [aliasDomain].
  String addressAt(String aliasDomain) {
    final domain = aliasDomain.trim().toLowerCase().replaceAll(RegExp(r'^@'), '');
    return '$localPart@$domain';
  }

  /// Signs a request to the mail server.
  ///
  /// Every call to the mail service is authenticated per mailbox with one of
  /// these, and never with a shared token: a token that covers two mailboxes
  /// is itself the link between them.
  Uint8List sign(List<int> message) {
    _assertUsable();
    return ed.sign(_signingKey, Uint8List.fromList(message));
  }

  /// The key mail is sealed to. Async because X25519 clamping is.
  Future<Uint8List> x25519PublicKey() async {
    _assertUsable();
    final keyPair = await X25519().newKeyPairFromSeed(_sealingSeed);
    final public = await keyPair.extractPublicKey();
    return Uint8List.fromList(public.bytes);
  }

  /// The private half, for opening sealed mail. Kept out of the public API
  /// surface; only the sealed-mail layer should reach for it.
  Future<SimpleKeyPair> sealingKeyPair() async {
    _assertUsable();
    return X25519().newKeyPairFromSeed(_sealingSeed);
  }

  /// Zeroes both seeds. Call when the identity locks.
  void wipe() {
    for (var i = 0; i < _signingSeed.length; i++) {
      _signingSeed[i] = 0;
    }
    for (var i = 0; i < _sealingSeed.length; i++) {
      _sealingSeed[i] = 0;
    }
    _wiped = true;
  }

  void _assertUsable() {
    if (_wiped) {
      throw StateError('These mailbox keys have been wiped.');
    }
  }

  /// Redacted, mirroring [SiteIdentity]. The local part is not secret, but a
  /// mailbox identifier in a crash report is still a correlation handle.
  @override
  String toString() => 'SiteMailboxKeys(${_wiped ? 'wiped' : 'live'})';
}
