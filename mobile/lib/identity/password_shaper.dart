import 'shadow_kdf.dart';
import 'password_policy.dart';

/// Turns fixed entropy into a password that satisfies a site's rules.
///
/// Deterministic by construction: the same entropy and the same policy always
/// produce the same password, which is what lets a user recover every account
/// from their recovery phrase alone. That also means the policy must travel
/// with the account — change the policy and the password changes with it.
class PasswordShaper {
  PasswordShaper._();

  static String shape({
    required List<int> entropy,
    PasswordPolicy policy = PasswordPolicy.standard,
  }) {
    policy.validate();

    final stream = DeterministicBytes(entropy, domainSeparator: 'password');
    final length = policy.targetLength;
    final characters = <String>[];

    // Seed one character from each required class first, so the result can
    // never fail a site's own validator on a technicality.
    if (policy.requireLowercase) {
      characters.add(_pick(policy.lowercase, stream));
    }
    if (policy.requireUppercase) {
      characters.add(_pick(policy.uppercase, stream));
    }
    if (policy.requireDigit) {
      characters.add(_pick(policy.digits, stream));
    }
    if (policy.requireSymbol) {
      characters.add(_pick(policy.symbolSet, stream));
    }

    final alphabet = policy.alphabet;
    while (characters.length < length) {
      characters.add(_pick(alphabet, stream));
    }

    // Without this the required characters would always sit in class order at
    // the front, which is both a distinguishable fingerprint and a needless
    // reduction in effective search space.
    stream.shuffle(characters);

    return characters.join();
  }

  static String _pick(String alphabet, DeterministicBytes stream) {
    return alphabet[stream.nextInt(alphabet.length)];
  }
}
