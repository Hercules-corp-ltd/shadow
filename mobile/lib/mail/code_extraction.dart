import 'mime_lite.dart';

/// Something worth offering the user out of a message.
sealed class ExtractedCredential {
  const ExtractedCredential();
}

/// A one-time code: inert data, which the human then submits themselves.
final class OneTimeCode extends ExtractedCredential {
  const OneTimeCode({
    required this.value,
    required this.confidence,
    required this.context,
  });

  final String value;

  /// Higher is better. Used to order candidates, never to pick one
  /// automatically — an ambiguous message shows its options.
  final int confidence;

  /// The few words around it, so the user can see what they are agreeing to.
  final String context;
}

/// A magic link, which is a different kind of thing entirely.
///
/// A code is data. A link is a **bearer credential**: fetching it *is* the
/// authentication. So there is no "fill it in and let the user press the
/// button" — following it completes the action. Hence: never navigated
/// automatically, and never prefetched, HEAD-ed, unfurled or safety-checked,
/// because many are single-use and any fetch at all burns them and locks the
/// user out of the account they were trying to reach.
final class MagicLink extends ExtractedCredential {
  const MagicLink({required this.url, required this.host});

  final Uri url;
  final String host;
}

/// Pulls codes and links out of a decrypted message.
///
/// ## What decides whether a code may be filled
///
/// Not the sender. Verification mail overwhelmingly ships from ESPs —
/// `sendgrid.net`, `amazonses.com`, `mg.somesite.com` — so matching `From:`
/// against the site produces false negatives on exactly the mail that
/// matters. It is also unnecessary: **the address is the routing.** Mail
/// arriving at a per-site mailbox is, by construction, mail for that one
/// site, because that address was never given to anybody else.
///
/// What does decide it is the fill target, and that check lives in the
/// browser: a code may only be typed into a page whose registrable domain
/// owns the mailbox the code arrived in. See `CodeFillScript`.
class CodeExtraction {
  CodeExtraction._();

  /// Words that make a nearby number look like a code.
  static final RegExp _trigger = RegExp(
    r'\b(code|verification|verify|otp|one[- ]time|passcode|pin|confirm\w*|'
    r'security code|2fa|two[- ]factor|authenticat\w*)\b',
    caseSensitive: false,
  );

  /// Words that make a nearby number look like anything but a code.
  static final RegExp _antiTrigger = RegExp(
    r'\b(order|invoice|receipt|ticket|reference|ref|tracking|account number|'
    r'phone|tel|zip|postcode|suite|apt)\b',
    caseSensitive: false,
  );

  /// Everything after this is footer, and footers are full of numbers.
  static final RegExp _footer = RegExp(
    r'(unsubscribe|manage (your )?preferences|view (this )?in (your )?browser|'
    r'privacy policy|terms of service)',
    caseSensitive: false,
  );

  static final RegExp _digits = RegExp(r'\b\d{4,8}\b');
  static final RegExp _alphanumeric = RegExp(r'\b[A-Z0-9]{6,8}\b');
  static final RegExp _grouped = RegExp(r'\b(\d{3})[- ](\d{3})\b');

  /// How far either side of a number to look for a trigger word.
  static const int _window = 80;

  /// Everything worth offering, best first.
  static List<ExtractedCredential> extract(
    MimeMessage message, {
    String? aliasLocalPart,
  }) {
    final results = <ExtractedCredential>[];
    final seen = <String>{};

    void addCode(String value, int confidence, String context) {
      final normalised = value.toUpperCase();
      if (seen.contains(normalised)) return;
      if (aliasLocalPart != null &&
          aliasLocalPart.toUpperCase().contains(normalised)) {
        // The address itself is base32, so uppercased it matches the
        // alphanumeric shape. Offering the user a slice of their own email
        // address as a verification code would be a confident, useless lie.
        return;
      }
      seen.add(normalised);
      results.add(OneTimeCode(
        value: value,
        confidence: confidence,
        context: context,
      ));
    }

    // 1. The header, if the sender used it. Near-zero adoption, five lines.
    final declared = message.declaredCode;
    if (declared != null && declared.isNotEmpty) {
      addCode(declared, 100, 'Declared by the sender');
    }

    // 2. The subject. Short, low-noise, and codes live there constantly.
    for (final candidate in _candidatesIn(message.subject)) {
      addCode(candidate, 80, message.subject.trim());
    }

    // 3. The body, above the footer.
    final body = _beforeFooter(message.text);
    for (final match in _scan(body)) {
      addCode(match.value, match.confidence, match.context);
    }

    results.sort((a, b) {
      if (a is OneTimeCode && b is OneTimeCode) {
        return b.confidence.compareTo(a.confidence);
      }
      return 0;
    });

    results.addAll(_links(body));
    return results;
  }

  /// The highest-confidence code, or null when there is nothing convincing.
  static OneTimeCode? bestCode(
    MimeMessage message, {
    String? aliasLocalPart,
  }) {
    for (final result
        in extract(message, aliasLocalPart: aliasLocalPart)) {
      if (result is OneTimeCode) return result;
    }
    return null;
  }

  static String _beforeFooter(String text) {
    final match = _footer.firstMatch(text);
    return match == null ? text : text.substring(0, match.start);
  }

  /// Codes in a short string where everything is close to everything else.
  static List<String> _candidatesIn(String line) {
    if (line.isEmpty) return const <String>[];
    final out = <String>[];
    for (final match in _digits.allMatches(line)) {
      final value = match.group(0)!;
      if (_looksLikeAYear(value, line, match.start)) continue;
      out.add(value);
    }
    return out;
  }

  static Iterable<_Candidate> _scan(String body) sync* {
    final safe = _maskNoise(body);

    for (final match in _grouped.allMatches(safe)) {
      final context = _contextAround(safe, match.start, match.end);
      if (!_trigger.hasMatch(context)) continue;
      yield _Candidate(
        '${match.group(1)}${match.group(2)}',
        60,
        context.trim(),
      );
    }

    for (final match in _digits.allMatches(safe)) {
      final value = match.group(0)!;
      final context = _contextAround(safe, match.start, match.end);
      if (!_trigger.hasMatch(context)) continue;
      if (_antiTrigger.hasMatch(context)) continue;
      if (_looksLikeAYear(value, safe, match.start)) continue;

      // Six digits is the overwhelmingly common shape.
      yield _Candidate(value, value.length == 6 ? 70 : 50, context.trim());
    }

    for (final match in _alphanumeric.allMatches(safe)) {
      final value = match.group(0)!;
      if (RegExp(r'^\d+$').hasMatch(value)) continue; // already covered
      final context = _contextAround(safe, match.start, match.end);
      if (!_trigger.hasMatch(context)) continue;
      if (_antiTrigger.hasMatch(context)) continue;
      yield _Candidate(value, 55, context.trim());
    }
  }

  /// Blanks out the runs that produce confident wrong answers.
  ///
  /// This is where naive extractors fail. A marketing email is full of hex
  /// colours, table widths, prices, dates and tracking tokens, every one of
  /// which matches a plain digit rule. Masking rather than deleting keeps
  /// the offsets intact so context windows still line up.
  static String _maskNoise(String text) {
    String blank(Match m) => ' ' * m.group(0)!.length;

    return text
        // URLs and href targets — a number in one is a magic-link token,
        // not something to type into a box.
        .replaceAllMapped(RegExp(r'https?://\S+'), blank)
        .replaceAllMapped(
            RegExp(r'href\s*=\s*"[^"]*"', caseSensitive: false), blank)
        // Anything still inside a tag, plus inline CSS.
        .replaceAllMapped(RegExp(r'<[^>]*>'), blank)
        .replaceAllMapped(
            RegExp(r'style\s*=\s*"[^"]*"', caseSensitive: false), blank)
        .replaceAllMapped(RegExp(r'#[0-9a-fA-F]{3,8}\b'), blank)
        .replaceAllMapped(
            RegExp(r'\b\d+(px|pt|em|rem|%)\b', caseSensitive: false), blank)
        // Money.
        .replaceAllMapped(
            RegExp(r'[\$£€¥]\s?\d[\d,]*(\.\d{2})?'), blank)
        .replaceAllMapped(RegExp(r'\b\d[\d,]*\.\d{2}\b'), blank)
        // Phone numbers.
        .replaceAllMapped(RegExp(r'\+\d[\d\s().-]{7,}'), blank)
        // Dates in numeric form.
        .replaceAllMapped(RegExp(r'\b\d{1,4}[/-]\d{1,2}[/-]\d{1,4}\b'), blank)
        // Message-ID and similar angle-bracketed noise.
        .replaceAllMapped(RegExp(r'<[^\s>]+@[^\s>]+>'), blank);
  }

  static bool _looksLikeAYear(String value, String text, int start) {
    if (value.length != 4) return false;
    final year = int.tryParse(value);
    if (year == null || year < 1900 || year > 2100) return false;

    final around = _contextAround(text, start, start + 4, span: 24);
    return RegExp(
      r'(©|copyright|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|'
      r'\bin\b|\bsince\b)',
      caseSensitive: false,
    ).hasMatch(around);
  }

  static String _contextAround(
    String text,
    int start,
    int end, {
    int span = _window,
  }) {
    final from = (start - span).clamp(0, text.length);
    final to = (end + span).clamp(0, text.length);
    return text.substring(from, to).replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<MagicLink> _links(String body) {
    final out = <MagicLink>[];
    final seen = <String>{};

    for (final match in RegExp(r'https://[^\s<>"\)]+').allMatches(body)) {
      final raw = match.group(0)!.replaceAll(RegExp(r'[.,;:]+$'), '');
      final uri = Uri.tryParse(raw);
      if (uri == null || uri.host.isEmpty) continue;

      // A link is only interesting if it looks like it carries a credential.
      final looksLikeAuth = RegExp(
        r'(verify|confirm|activate|magic|signin|sign-in|login|auth|token|'
        r'validate)',
        caseSensitive: false,
      ).hasMatch(uri.path + uri.query);
      if (!looksLikeAuth) continue;

      if (!seen.add(uri.toString())) continue;
      out.add(MagicLink(url: uri, host: uri.host.toLowerCase()));
      if (out.length >= 3) break;
    }
    return out;
  }
}

class _Candidate {
  const _Candidate(this.value, this.confidence, this.context);
  final String value;
  final int confidence;
  final String context;
}
