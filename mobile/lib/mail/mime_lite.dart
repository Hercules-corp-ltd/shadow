import 'dart:convert';

/// Just enough MIME to find a verification code.
///
/// Not a mail library. `enough_mail` is a full IMAP client and everything it
/// carries beyond parsing is surface this app does not want. What is needed
/// here is narrow: split the headers off, decode the transfer encoding, walk
/// down to the text, and stop.
///
/// ## Everything here is attacker-controlled
///
/// A message arrives from whoever felt like sending one. So nothing in this
/// file throws — a malformed part yields less text, never an exception — and
/// there are hard caps on size, part count and nesting depth. Without the
/// depth cap, forty nested `multipart/mixed` boundaries are a stack overflow
/// on the UI thread, sent by anyone who knows the address.
class MimeLite {
  MimeLite._();

  /// Beyond this the message is refused unparsed. The Worker already caps
  /// what it will seal at 64 KB; this is the belt to that braces.
  static const int maxBytes = 1024 * 1024;
  static const int maxParts = 20;
  static const int maxDepth = 8;

  /// Parses [raw], or returns a message marked [MimeMessage.degraded] when
  /// it cannot.
  static MimeMessage parse(String raw) {
    if (raw.length > maxBytes) {
      return const MimeMessage._(
        headers: <String, String>{},
        text: '',
        degraded: true,
      );
    }

    final parsed = _parsePart(raw, depth: 0, partBudget: _Budget(maxParts));
    return MimeMessage._(
      headers: parsed.headers,
      text: parsed.text,
      degraded: parsed.degraded,
    );
  }

  static _Part _parsePart(
    String raw, {
    required int depth,
    required _Budget partBudget,
  }) {
    if (depth > maxDepth || !partBudget.take()) {
      return const _Part(<String, String>{}, '', degraded: true);
    }

    final split = _splitHeaders(raw);
    final headers = split.headers;
    final body = split.body;

    final contentType = (headers['content-type'] ?? 'text/plain').toLowerCase();

    if (contentType.startsWith('multipart/')) {
      final boundary = _parameter(headers['content-type'] ?? '', 'boundary');
      if (boundary == null || boundary.isEmpty) {
        return _Part(headers, body, degraded: true);
      }
      return _walkMultipart(
        headers: headers,
        body: body,
        boundary: boundary,
        depth: depth,
        partBudget: partBudget,
      );
    }

    final decoded = _decodeBody(
      body,
      encoding: (headers['content-transfer-encoding'] ?? '').toLowerCase().trim(),
      charset: _parameter(headers['content-type'] ?? '', 'charset'),
    );

    final text = contentType.startsWith('text/html')
        ? stripTags(decoded.text)
        : decoded.text;

    return _Part(headers, text, degraded: decoded.degraded);
  }

  static _Part _walkMultipart({
    required Map<String, String> headers,
    required String body,
    required String boundary,
    required int depth,
    required _Budget partBudget,
  }) {
    final chunks = body.split('--$boundary');
    var degraded = false;
    String? plain;
    String? html;

    for (final chunk in chunks) {
      final trimmed = chunk.trim();
      if (trimmed.isEmpty || trimmed == '--') continue;

      final part = _parsePart(chunk, depth: depth + 1, partBudget: partBudget);
      degraded = degraded || part.degraded;
      if (part.text.trim().isEmpty) continue;

      final type =
          (part.headers['content-type'] ?? 'text/plain').toLowerCase();
      if (type.startsWith('text/html')) {
        html ??= part.text;
      } else if (type.startsWith('text/') || part.headers.isEmpty) {
        plain ??= part.text;
      }
    }

    // text/plain wins. It is shorter, has no markup to confuse a code
    // matcher, and is the part a sender writes for a human to read.
    return _Part(headers, plain ?? html ?? '', degraded: degraded);
  }

  static _Split _splitHeaders(String raw) {
    final normalised = raw.replaceAll('\r\n', '\n');
    final blank = normalised.indexOf('\n\n');
    if (blank == -1) {
      // No body at all. Treat the lot as headers rather than as text, so a
      // Subject: line is still reachable.
      return _Split(_parseHeaders(normalised), '');
    }
    return _Split(
      _parseHeaders(normalised.substring(0, blank)),
      normalised.substring(blank + 2),
    );
  }

  /// Unfolds continuation lines and lowercases names.
  static Map<String, String> _parseHeaders(String block) {
    final headers = <String, String>{};
    final unfolded = <String>[];

    for (final line in block.split('\n')) {
      if (line.isEmpty) continue;
      if ((line.startsWith(' ') || line.startsWith('\t')) &&
          unfolded.isNotEmpty) {
        unfolded[unfolded.length - 1] += ' ${line.trim()}';
      } else {
        unfolded.add(line);
      }
    }

    for (final line in unfolded) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      final name = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();
      // First wins. A second From: is a spoofing attempt, not an update.
      headers.putIfAbsent(name, () => value);
    }
    return headers;
  }

  static String? _parameter(String headerValue, String name) {
    final match = RegExp(
      '$name\\s*=\\s*"?([^";\\s]+)"?',
      caseSensitive: false,
    ).firstMatch(headerValue);
    return match?.group(1);
  }

  static _Decoded _decodeBody(
    String body, {
    required String encoding,
    required String? charset,
  }) {
    List<int> bytes;
    var degraded = false;

    switch (encoding) {
      case 'base64':
        try {
          bytes = base64Decode(body.replaceAll(RegExp(r'\s'), ''));
        } on FormatException {
          return _Decoded(body, degraded: true);
        }
      case 'quoted-printable':
        bytes = _decodeQuotedPrintable(body);
      default:
        bytes = utf8.encode(body);
    }

    final normalisedCharset = (charset ?? 'utf-8').toLowerCase();
    switch (normalisedCharset) {
      case 'utf-8':
      case 'utf8':
      case 'us-ascii':
      case 'ascii':
        return _Decoded(
          utf8.decode(bytes, allowMalformed: true),
          degraded: degraded,
        );
      case 'iso-8859-1':
      case 'latin1':
      case 'windows-1252':
        return _Decoded(latin1.decode(bytes, allowInvalid: true),
            degraded: degraded);
      default:
        // Some charset nobody bundled. Decode as best we can and say so,
        // rather than throwing away a message that probably still has a
        // perfectly readable ASCII code in it.
        return _Decoded(
          utf8.decode(bytes, allowMalformed: true),
          degraded: true,
        );
    }
  }

  static List<int> _decodeQuotedPrintable(String input) {
    final out = <int>[];
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char != '=') {
        out.addAll(utf8.encode(char));
        continue;
      }
      // Soft line break.
      if (i + 1 < input.length && input[i + 1] == '\n') {
        i += 1;
        continue;
      }
      if (i + 2 < input.length && input.substring(i + 1, i + 3) == '\r\n') {
        i += 2;
        continue;
      }
      if (i + 2 < input.length) {
        final hex = int.tryParse(input.substring(i + 1, i + 3), radix: 16);
        if (hex != null) {
          out.add(hex);
          i += 2;
          continue;
        }
      }
      out.addAll(utf8.encode(char));
    }
    return out;
  }

  /// Decodes RFC 2047 encoded-words, as used in subject lines.
  ///
  /// Codes turn up in subjects far more often than anywhere else, and a
  /// subject carrying one is frequently encoded because the rest of it is
  /// not ASCII.
  static String decodeEncodedWords(String value) {
    return value.replaceAllMapped(
      RegExp(r'=\?([^?]+)\?([BbQq])\?([^?]*)\?='),
      (match) {
        final charset = (match.group(1) ?? 'utf-8').toLowerCase();
        final kind = (match.group(2) ?? 'b').toLowerCase();
        final payload = match.group(3) ?? '';

        List<int> bytes;
        try {
          if (kind == 'b') {
            bytes = base64Decode(payload.replaceAll(RegExp(r'\s'), ''));
          } else {
            // Q encoding: like quoted-printable, but underscore is space.
            bytes = _decodeQuotedPrintable(payload.replaceAll('_', ' '));
          }
        } on FormatException {
          return match.group(0) ?? '';
        }

        if (charset.startsWith('iso-8859') || charset.startsWith('windows-')) {
          return latin1.decode(bytes, allowInvalid: true);
        }
        return utf8.decode(bytes, allowMalformed: true);
      },
    );
  }

  /// Turns HTML into something a code matcher can read.
  ///
  /// Style and script contents go first and entirely. Leaving them in is how
  /// a matcher ends up confidently reporting `#ffffff` or a `600` from a
  /// table width as somebody's verification code.
  static String stripTags(String html) {
    var text = html
        .replaceAll(
          RegExp(r'<(script|style)[^>]*>.*?</\1>',
              caseSensitive: false, dotAll: true),
          ' ',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|tr|h[1-6])>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ');

    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    return text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  }
}

/// A parsed message, reduced to the parts that matter here.
class MimeMessage {
  const MimeMessage._({
    required this.headers,
    required this.text,
    required this.degraded,
  });

  final Map<String, String> headers;

  /// The best text body found: `text/plain` if there was one, otherwise
  /// HTML with its tags stripped.
  final String text;

  /// Something could not be decoded cleanly — an unknown charset, a bad
  /// base64 run, a part budget exhausted. The text is still worth searching;
  /// this only means "do not be surprised if it is short".
  final bool degraded;

  String get subject =>
      MimeLite.decodeEncodedWords(headers['subject'] ?? '').trim();

  /// The `From:` header, as written. Displayed to the user so they can see
  /// who a code claims to be from — never used to decide whether to offer
  /// one, because verification mail almost always ships from an ESP.
  String get from => MimeLite.decodeEncodedWords(headers['from'] ?? '').trim();

  /// The sender's registrable domain, best effort.
  String? get fromDomain {
    final match = RegExp(r'@([A-Za-z0-9._-]+)').firstMatch(from);
    return match?.group(1)?.toLowerCase();
  }

  /// RFC-shaped one-time code, if the sender bothered.
  ///
  /// `draft-wells-origin-bound-one-time-codes` expired in June 2024 with no
  /// successor and effectively zero adoption, but it has an Apple pedigree
  /// and costs five lines to support. Free upside; never relied upon.
  String? get declaredCode {
    final header = headers['one-time-code'];
    if (header == null) return null;
    final match = RegExp(r'code\s*=\s*([A-Za-z0-9-]+)').firstMatch(header);
    return match?.group(1);
  }
}

class _Part {
  const _Part(this.headers, this.text, {required this.degraded});
  final Map<String, String> headers;
  final String text;
  final bool degraded;
}

class _Split {
  const _Split(this.headers, this.body);
  final Map<String, String> headers;
  final String body;
}

class _Decoded {
  const _Decoded(this.text, {required this.degraded});
  final String text;
  final bool degraded;
}

/// Shared part allowance across a whole nested walk.
class _Budget {
  _Budget(this._remaining);
  int _remaining;

  bool take() {
    if (_remaining <= 0) return false;
    _remaining--;
    return true;
  }
}
