/// Turns whatever the user typed into something safe to navigate to.
///
/// The address bar is the most privacy-sensitive control in a browser: get
/// this wrong and a typed password or a private note becomes a search query
/// sent to a third party. The rules here are deliberately conservative — if
/// the input looks even slightly like a destination, treat it as one.
class UrlInput {
  UrlInput._();

  /// Search is routed to DuckDuckGo rather than Google. A browser that sells
  /// privacy should not make its default action a query to an ad network.
  static const String searchEndpoint = 'https://duckduckgo.com/?q=';

  /// Schemes we will navigate to. Anything else — `javascript:`, `data:`,
  /// `file:`, custom app schemes — is refused: those are the classic vectors
  /// for a pasted-link attack, and none of them is something a user means to
  /// type into an address bar.
  static const Set<String> allowedSchemes = <String>{'http', 'https', 'about'};

  /// Resolves [raw] into a URL to load, or null when there is nothing usable.
  static Uri? resolve(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;

    // A hierarchical URL: scheme://host/...
    final hierarchical =
        RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*)://').firstMatch(input);
    if (hierarchical != null) {
      final scheme = hierarchical.group(1)!.toLowerCase();
      if (!allowedSchemes.contains(scheme)) return null;
      final parsed = Uri.tryParse(input);
      if (parsed == null || parsed.host.isEmpty) return null;
      return parsed;
    }

    // A bare colon is ambiguous: "localhost:3000" is host and port, while
    // "javascript:alert(1)" is an opaque scheme. Digits after the colon mean
    // a port; anything else means a scheme we do not open.
    final colonMatch =
        RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*):(.*)$').firstMatch(input);
    if (colonMatch != null) {
      final rest = colonMatch.group(2)!;
      final isPort = RegExp(r'^\d+(/.*)?$').hasMatch(rest);
      if (!isPort) {
        final scheme = colonMatch.group(1)!.toLowerCase();
        // "about:blank" is opaque but harmless and allow-listed.
        if (scheme == 'about') return Uri.tryParse(input);
        return null;
      }
      // Fall through: treat as host:port.
    }

    if (_looksLikeHost(input)) {
      // Default to https. Falling back to http on failure would silently
      // downgrade the connection, so a site that is http-only has to be
      // typed as http:// deliberately.
      return Uri.tryParse('https://$input');
    }

    return Uri.parse(searchEndpoint + Uri.encodeQueryComponent(input));
  }

  /// True when [input] reads as a hostname rather than a search phrase.
  static bool _looksLikeHost(String input) {
    if (input.contains(' ')) return false;

    final hostPart = input.split('/').first.split('?').first;
    if (hostPart.isEmpty) return false;

    if (hostPart == 'localhost' || hostPart.startsWith('localhost:')) {
      return true;
    }
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}(:\d+)?$').hasMatch(hostPart)) {
      return true;
    }

    // Needs a dot with a plausible TLD after it. "flutter 3.41" is caught by
    // the space check above; "3.41" is rejected here because a TLD is never
    // numeric.
    final labels = hostPart.split(':').first.split('.');
    if (labels.length < 2) return false;
    if (labels.any((l) => l.isEmpty)) return false;

    final tld = labels.last;
    if (tld.length < 2) return false;
    return RegExp(r'^[a-zA-Z]{2,}$').hasMatch(tld);
  }

  /// What to show in the address bar: the host alone, which is the part that
  /// tells a user where they actually are. Long paths push the host off
  /// screen, and hiding the host is how phishing works.
  static String displayLabel(Uri? uri) {
    if (uri == null) return '';
    if (uri.host.isEmpty) return uri.toString();
    final host = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
    return uri.path.isEmpty || uri.path == '/' ? host : '$host${uri.path}';
  }

  /// Whether the connection is actually encrypted — not a decorative badge.
  static bool isSecure(Uri? uri) => uri != null && uri.scheme == 'https';
}
