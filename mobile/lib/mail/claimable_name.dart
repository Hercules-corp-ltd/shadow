import '../identity/identity.dart';

/// Why a name cannot be claimed, in the user's terms.
enum NameProblem {
  tooShort,
  tooLong,
  badCharacters,

  /// Shaped like a derived mask address. The server refuses these outright.
  looksLikeAnAlias,

  /// Kept for whoever runs the mail service.
  reserved,
}

/// The rule for a name a person may claim.
///
/// ## Why this is duplicated from the Worker
///
/// `services/mail-worker/src/auth.ts` is the authority — it is what actually
/// refuses a bad name, and a client that disagreed would only be wrong. This
/// copy exists because the claim costs several seconds of hashing before the
/// server ever sees it, and a user who typed `alice1` deserves to be told
/// which character is the problem immediately, not after a wait and then a
/// status code that cannot say why.
///
/// The two must not drift. `claimable_name_test.dart` asserts this rejects
/// real derived local parts, which is the property that matters most: if mask
/// derivation ever changes shape, that test fails here and the equivalent
/// check fails in `tool/probe.mjs`.
class ClaimableName {
  ClaimableName._();

  /// Every length a derived mask address has ever used. Append, never edit.
  static const List<int> maskLengths = <int>[SiteMailboxKeys.localPartLength];

  static const int minLength = 5;
  static const int maxLength = 19;

  /// The mask alphabet, deliberately.
  ///
  /// A username field would allow `[a-z0-9_-]`. This does not, and the cost is
  /// real: no `alice1`, no `bob-smith`. What it buys is that no two claimable
  /// names can ever be confused for one another — there is no `0` against `o`,
  /// no `1` against `l`, no uppercase, and no hyphen to make `alice-support`
  /// sit alongside `alicesupport`. This is an address people read off a screen
  /// and type from memory, and impersonation is the failure that costs them
  /// more than expressiveness does.
  static final RegExp _allowed = RegExp(r'^[a-z2-7]+$');

  /// Names the mail service keeps. Mirrors RESERVED_NAMES in auth.ts.
  ///
  /// `postmaster` and `abuse` are required to reach whoever runs the domain —
  /// RFC 2142 — and the rest are the addresses people assume belong to the
  /// service, which is exactly what makes handing one to a stranger useful for
  /// phishing. Anything under [minLength] is already refused on length.
  static const Set<String> reserved = <String>{
    'abuse',
    'administrator',
    'billing',
    'contact',
    'hostmaster',
    'mailer',
    'noreply',
    'postmaster',
    'privacy',
    'security',
    'shadow',
    'staff',
    'support',
    'webmaster',
  };

  /// The first thing wrong with [name], or null if it can be claimed.
  static NameProblem? check(String name) {
    if (name.length < minLength) return NameProblem.tooShort;
    if (name.length > maxLength) return NameProblem.tooLong;
    if (!_allowed.hasMatch(name)) return NameProblem.badCharacters;
    if (maskLengths.contains(name.length)) return NameProblem.looksLikeAnAlias;
    if (reserved.contains(name)) return NameProblem.reserved;
    return null;
  }

  static bool isValid(String name) => check(name) == null;

  /// What to show the user. Says what to do, not what went wrong internally.
  static String explain(NameProblem problem) {
    switch (problem) {
      case NameProblem.tooShort:
        return 'Too short — $minLength characters or more.';
      case NameProblem.tooLong:
        return 'Too long — $maxLength characters at most.';
      case NameProblem.badCharacters:
        return 'Letters a-z and digits 2-7 only. No capitals, dots, hyphens, '
            'or the digits 0, 1, 8 and 9 — they are too easy to mistake for '
            'letters in an address someone is reading out.';
      case NameProblem.looksLikeAnAlias:
        return 'That is the shape of a per-site alias, which is a different '
            'kind of address. Pick a length other than '
            '${maskLengths.join(' or ')}.';
      case NameProblem.reserved:
        return 'Kept for the mail service itself.';
    }
  }
}
