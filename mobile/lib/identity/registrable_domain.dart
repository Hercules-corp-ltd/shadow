/// Reduces any URL or host to the domain that identities are keyed on.
///
/// This is load-bearing: the registrable domain is the derivation key, so
/// `twitter.com`, `www.twitter.com` and `https://twitter.com/settings` must
/// all collapse to the same string or the user gets a different password
/// depending on how they happened to arrive at the site.
class RegistrableDomain {
  RegistrableDomain._();

  /// Public suffixes with two labels, where the registrable domain therefore
  /// needs three.
  ///
  /// This is a deliberately small subset of the Public Suffix List covering
  /// the suffixes real users actually sign up under. The full list is ~10k
  /// entries and changes monthly; shipping it belongs in an adapter bundle
  /// that can be updated without an app release, not compiled in here.
  /// Anything unlisted falls back to the last two labels, which is correct
  /// for every single-label suffix (.com, .org, .app, .io, …).
  static const Set<String> _twoLabelSuffixes = <String>{
    'co.uk', 'org.uk', 'me.uk', 'ac.uk', 'gov.uk', 'net.uk', 'sch.uk',
    'co.jp', 'or.jp', 'ne.jp', 'ac.jp', 'go.jp',
    'com.au', 'net.au', 'org.au', 'edu.au', 'gov.au',
    'co.nz', 'net.nz', 'org.nz', 'govt.nz',
    'com.br', 'net.br', 'org.br', 'gov.br',
    'com.cn', 'net.cn', 'org.cn', 'gov.cn', 'edu.cn',
    'co.in', 'net.in', 'org.in', 'gen.in', 'firm.in',
    'com.mx', 'com.ar', 'com.co', 'com.tr', 'com.tw',
    'com.sg', 'com.hk', 'com.my', 'com.ph', 'com.vn',
    'co.za', 'org.za', 'net.za',
    'co.kr', 'or.kr', 'ne.kr',
    'com.pl', 'net.pl', 'org.pl',
    'co.il', 'org.il', 'net.il',
    'com.ua', 'com.ru', 'com.es', 'com.pt', 'com.gr',
    'github.io', 'gitlab.io', 'pages.dev', 'workers.dev',
    'vercel.app', 'netlify.app', 'herokuapp.com', 'web.app',
    'firebaseapp.com', 'appspot.com', 'azurewebsites.net',
    's3.amazonaws.com', 'cloudfront.net',
  };

  /// Extracts the registrable domain from [input].
  ///
  /// Accepts a bare host, a host with a port, or a full URL. Returns a
  /// lowercase host with no scheme, port, path or leading `www.`. Throws
  /// [FormatException] when [input] yields nothing usable.
  static String of(String input) {
    var value = input.trim().toLowerCase();
    if (value.isEmpty) {
      throw const FormatException('Cannot derive an identity for an empty host');
    }

    // Strip scheme.
    final schemeIndex = value.indexOf('://');
    if (schemeIndex != -1) value = value.substring(schemeIndex + 3);

    // Strip credentials, path, query and fragment.
    final atIndex = value.lastIndexOf('@');
    if (atIndex != -1) value = value.substring(atIndex + 1);
    for (final separator in const <String>['/', '?', '#']) {
      final index = value.indexOf(separator);
      if (index != -1) value = value.substring(0, index);
    }

    // Strip port, but leave bracketed IPv6 literals intact.
    if (!value.startsWith('[')) {
      final colonIndex = value.indexOf(':');
      if (colonIndex != -1) value = value.substring(0, colonIndex);
    }

    value = value.replaceAll(RegExp(r'\.+$'), ''); // trailing root dot

    if (value.isEmpty) {
      throw FormatException('No host found in "$input"');
    }

    // IP literals and single-label hosts (localhost) are their own key.
    if (_looksLikeIpAddress(value)) return value;

    final labels = value.split('.').where((l) => l.isNotEmpty).toList();
    if (labels.length <= 1) return value;

    final lastTwo = labels.sublist(labels.length - 2).join('.');
    if (labels.length >= 3 && _twoLabelSuffixes.contains(lastTwo)) {
      return labels.sublist(labels.length - 3).join('.');
    }
    return lastTwo;
  }

  /// Best-effort variant that returns null instead of throwing.
  static String? tryOf(String input) {
    try {
      return of(input);
    } on FormatException {
      return null;
    }
  }

  static bool _looksLikeIpAddress(String host) {
    if (host.startsWith('[')) return true; // [::1]
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) return true;
    return false;
  }
}
