import 'public_suffix_data.dart';

/// Reduces any URL or host to the domain that identities are keyed on.
///
/// This is load-bearing: the registrable domain is the derivation key, so
/// `twitter.com`, `www.twitter.com` and `https://twitter.com/settings` must
/// all collapse to the same string or the user gets a different password
/// depending on how they happened to arrive at the site.
///
/// ## Why the full Public Suffix List, and not a curated subset
///
/// It used to hold ~60 hand-picked two-label suffixes with a fallback to
/// "last two labels". That is wrong in one direction that matters: on a
/// multi-tenant host the PSL knows about but the subset did not — say
/// `alice.myshopify.com` and `bob.myshopify.com` — two unrelated shops
/// collapse to `myshopify.com` and receive *the same derived identity*.
///
/// Sharing a password there is already bad. Sharing a **mailbox** is worse:
/// whoever runs shop A can ask shop B for a password reset on the user's
/// account and read the code out of a mailbox they also own. So the real
/// list ships, generated into [kPublicSuffixRules] by `tool/build_psl.mjs`.
class RegistrableDomain {
  RegistrableDomain._();

  /// Built once, lazily — ~10k entries parsed on first derivation rather
  /// than at import time, so a test that never touches a domain pays
  /// nothing.
  static final Set<String> _rules = _lines(kPublicSuffixRules);
  static final Set<String> _wildcardParents = _lines(kWildcardParents);
  static final Set<String> _exceptions = _lines(kSuffixExceptions);

  static Set<String> _lines(String data) =>
      data.split('\n').where((line) => line.isNotEmpty).toSet();

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

    // Path, query and fragment first — then credentials.
    //
    // The order is the whole correctness of this function. Taking the text
    // after the last `@` first means any `@` further along the URL is read as
    // the end of a userinfo section, so
    //
    //     https://evil.test/@bank.com
    //
    // derived an identity for bank.com. Every site controls its own paths, so
    // that was a page anybody could serve to make Shadow hand them another
    // site's password, username and alias — the per-site isolation this whole
    // app is built on, defeated by a path. `?next=@bank.com` did the same
    // through a query string, which even a legitimate site with an open
    // redirect could carry.
    //
    // An authority can never contain `/`, `?` or `#`, so cutting at those
    // first leaves exactly `[userinfo@]host[:port]`, and the `@` that remains
    // is the only one that was ever userinfo.
    for (final separator in const <String>['/', '?', '#']) {
      final index = value.indexOf(separator);
      if (index != -1) value = value.substring(0, index);
    }
    final atIndex = value.lastIndexOf('@');
    if (atIndex != -1) value = value.substring(atIndex + 1);

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

    final suffixLabels = _publicSuffixLabelCount(labels);

    // The host is itself a public suffix (`co.uk`, `foo.ck`). There is no
    // registrable domain below it, so it is its own key.
    if (labels.length <= suffixLabels) return value;

    return labels.sublist(labels.length - suffixLabels - 1).join('.');
  }

  /// How many trailing labels of [labels] form the public suffix.
  ///
  /// Implements the matching rules from publicsuffix.org/list: an exception
  /// beats everything, otherwise the longest matching rule wins, and an
  /// unlisted TLD falls back to the implicit `*` rule.
  static int _publicSuffixLabelCount(List<String> labels) {
    // Exceptions first, because the spec says an exception prevails over any
    // other matching rule regardless of length. There are only eight, all of
    // the form `!city.kobe.jp`, and each means "this host is registrable
    // after all" — so the suffix is the rule minus its leftmost label.
    for (var i = 0; i < labels.length; i++) {
      if (_exceptions.contains(labels.sublist(i).join('.'))) {
        return labels.length - i - 1;
      }
    }

    // Longest match otherwise. Starting from the front yields the longest
    // candidate first, so the first hit is already the prevailing rule.
    for (var i = 0; i < labels.length; i++) {
      if (_rules.contains(labels.sublist(i).join('.'))) {
        return labels.length - i;
      }
      // A wildcard rule `*.ck` says any single label under `ck` is itself a
      // public suffix, so the question to ask of a candidate is whether its
      // PARENT is a wildcard — which is why the generator stores parents.
      if (i + 1 < labels.length &&
          _wildcardParents.contains(labels.sublist(i + 1).join('.'))) {
        return labels.length - i;
      }
    }

    // The implicit `*` rule: an unknown TLD is its own public suffix, so the
    // registrable domain is the last two labels. Same answer the old curated
    // subset gave, now as a documented fallback rather than the whole design.
    return 1;
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
