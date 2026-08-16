import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The cost of claiming an address.
///
/// This is what stands in place of an identity gate. Requiring a wallet
/// signature would have handed the mail operator a map from a publicly
/// cross-referenceable, KYC-linkable on-chain identity to the user's entire
/// list of accounts — the exact harm the product exists to prevent — while
/// stopping no abuser at all, because Solana keypairs are free and instant
/// and one can be generated per registration.
///
/// Work costs the same whoever you are, and reveals nothing about you.
class RegistrationWork {
  RegistrationWork._();

  /// Matches `shadow-mail-pow/v1` in `services/mail-worker/src/auth.ts`.
  static const String _context = 'shadow-mail-pow/v1';

  /// Finds a nonce whose digest starts with [bits] zero bits.
  ///
  /// About a second of phone CPU at 20 bits — nothing to someone creating a
  /// few dozen mailboxes over a year, and roughly a hundred CPU-days per ten
  /// million. Synchronous and CPU-bound, so callers should hand it to
  /// `compute()` rather than block a frame.
  static String mine(String localPart, {int bits = 20, int limit = 1 << 26}) {
    for (var nonce = 0; nonce < limit; nonce++) {
      if (satisfies(localPart, nonce.toString(), bits)) return nonce.toString();
    }
    throw StateError('No proof of work found within $limit attempts');
  }

  /// Whether [nonce] is a valid proof for [localPart] at [bits].
  static bool satisfies(String localPart, String nonce, int bits) {
    final digest =
        sha256.convert(utf8.encode('$_context|$localPart|$nonce')).bytes;

    var remaining = bits;
    for (final byte in digest) {
      if (remaining <= 0) return true;
      if (remaining >= 8) {
        if (byte != 0) return false;
        remaining -= 8;
      } else {
        return (byte >> (8 - remaining)) == 0;
      }
    }
    return remaining <= 0;
  }
}
