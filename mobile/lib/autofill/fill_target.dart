import '../identity/identity.dart';

/// What an autofill request is asking to have filled, as parsed by the
/// platform side.
class AutofillRequest {
  const AutofillRequest({
    required this.packageName,
    required this.browserTrusted,
    this.webDomains = const <String>[],
    this.wantsPassword = false,
    this.wantsUsername = false,
    this.wantsEmail = false,
  });

  /// The app asking. Comes from the platform, not from the app itself.
  final String packageName;

  /// Whether the platform recognised this package as a browser.
  ///
  /// Recognised means the package name is on a list Shadow ships, and that
  /// the package also actually handles http links on this device. What it
  /// does **not** mean is that the certificate was pinned: Shadow does not
  /// carry the signing hashes of every browser, and inventing them would be
  /// worse than not checking, because a wrong hash refuses the real browser
  /// while looking like security.
  ///
  /// What the check does rest on is that Android will not install two apps
  /// under one package name. To be `com.android.chrome` on a phone, an
  /// attacker has to get Chrome off it first, which is a different and much
  /// louder attack than the one this is defending against.
  final bool browserTrusted;

  /// Every distinct web domain the platform saw in the view structure.
  final List<String> webDomains;

  final bool wantsPassword;
  final bool wantsUsername;
  final bool wantsEmail;
}

/// Why Shadow will not fill something.
enum FillRefusal {
  /// The request came from an app rather than a recognised browser.
  ///
  /// Filling here needs a trustworthy mapping from a package to the site it
  /// belongs to, and Shadow does not have one yet.
  notABrowser,

  /// A recognised browser package whose signing certificate did not match.
  signatureMismatch,

  /// The browser reported no page, so there is nothing to key an identity on.
  noDomain,

  /// More than one site in one form. No single answer is correct.
  ambiguousDomain,

  /// A page whose address has no registrable domain — an IP, localhost, a
  /// bare suffix.
  underivableDomain,

  /// Nothing on the form that Shadow has anything to put in.
  nothingToFill,
}

/// The decision, before any key material is touched.
sealed class FillDecision {
  const FillDecision();
}

/// Offer an identity for [domain].
final class FillFor extends FillDecision {
  const FillFor(this.domain);
  final String domain;
}

final class FillRefused extends FillDecision {
  const FillRefused(this.reason);
  final FillRefusal reason;
}

/// Decides whether a request can be answered, and for which site.
///
/// ## Why this is in Dart and not in the service
///
/// Getting this wrong types one site's password into another site's form.
/// That is the worst thing this app could do — worse than not filling at all,
/// worse than a crash — because it hands a working credential to whoever
/// controls the page, silently, at the moment the user is trying to log in.
///
/// The Kotlin side walks the view structure and builds the platform objects;
/// this makes the decision, because this is where the tests are and where the
/// public suffix list already lives. The platform tells it what it saw. It
/// decides what that is allowed to mean.
///
/// ## What it refuses, and why the refusals are not conservatism
///
/// **Anything that is not a verified browser.** Filling into a native app
/// needs a trustworthy answer to "which website is this app?", and the only
/// real one is Digital Asset Links — fetching `/.well-known/assetlinks.json`
/// for a candidate domain and checking it names this package and signature.
/// Shadow does not do that yet, and the alternatives are guesses: a package
/// named `com.twitter.android` is evidence about who wrote it, not about who
/// owns it, and anybody may publish `com.twitter.android.helper`.
///
/// **Two domains in one structure.** A page with a login form and an embedded
/// third-party frame produces both. There is no way to tell from here which
/// one the focused field belongs to, and picking the wrong one is precisely
/// the failure above.
class FillTarget {
  FillTarget._();

  static FillDecision decide(AutofillRequest request) {
    if (!request.wantsPassword &&
        !request.wantsUsername &&
        !request.wantsEmail) {
      return const FillRefused(FillRefusal.nothingToFill);
    }
    if (!request.browserTrusted) {
      return const FillRefused(FillRefusal.notABrowser);
    }
    if (request.webDomains.isEmpty) {
      return const FillRefused(FillRefusal.noDomain);
    }

    final registrable = <String>{};
    for (final raw in request.webDomains) {
      final domain = RegistrableDomain.tryOf(_host(raw));
      // An unusable domain is not skipped. If a structure contains one site
      // Shadow understands and one it does not, it still contains two sites,
      // and answering for the half that parsed is answering a question
      // nobody asked.
      if (domain == null || !_isRealSite(domain)) {
        return const FillRefused(FillRefusal.underivableDomain);
      }
      registrable.add(domain);
    }

    if (registrable.length > 1) {
      return const FillRefused(FillRefusal.ambiguousDomain);
    }
    return FillFor(registrable.first);
  }

  /// Whether a key from [RegistrableDomain] names a site on the public web.
  ///
  /// That function deliberately hands back an IP literal or a single-label
  /// host as its own key, so Shadow's own browser can hold an identity for a
  /// machine on a LAN. Here the same answer is not good enough: a request
  /// arrives from another app naming somewhere, and `localhost` from a
  /// browser on this phone is whatever happens to be listening on this phone.
  /// Anything without a public suffix under it gets refused rather than
  /// filled.
  static bool _isRealSite(String domain) {
    if (domain.isEmpty) return false;
    if (domain.startsWith('[')) return false; // IPv6 literal
    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(domain)) return false;
    // At least one dot, and a label either side of the last one.
    final labels = domain.split('.');
    if (labels.length < 2) return false;
    return labels.every((l) => l.isNotEmpty);
  }

  /// Strips a scheme, credentials, port and path, leaving a bare host.
  ///
  /// A browser may hand over a full URL, and taking a domain off the front of
  /// one by hand is where parsers get this wrong: `https://evil.test/@bank.com`
  /// has to read as evil.test, not bank.com.
  static String _host(String value) {
    var input = value.trim().toLowerCase();
    if (input.isEmpty) return '';

    // Uri.parse only finds an authority when there is a scheme, so give it
    // one rather than hand-splitting on '/'.
    if (!input.contains('://')) input = 'https://$input';
    final uri = Uri.tryParse(input);
    if (uri == null) return '';
    return uri.host;
  }

  /// Plain-language reason, for the one place a refusal is worth showing.
  static String explain(FillRefusal reason) {
    switch (reason) {
      case FillRefusal.notABrowser:
        return 'Shadow only fills in browsers it recognises. It cannot yet '
            'tell which website an app belongs to, and guessing would mean '
            'handing one site\'s password to another.';
      case FillRefusal.signatureMismatch:
        return 'That app uses a known browser\'s name but is not signed by '
            'it. Shadow will not fill into it.';
      case FillRefusal.noDomain:
        return 'The browser did not say which page this is, so Shadow has '
            'nothing to derive an identity from.';
      case FillRefusal.ambiguousDomain:
        return 'This form spans more than one site, so there is no single '
            'right answer. Fill it from Shadow\'s own browser instead.';
      case FillRefusal.underivableDomain:
        return 'That address has no domain Shadow can key an identity on.';
      case FillRefusal.nothingToFill:
        return 'Nothing on this form is something Shadow fills.';
    }
  }
}
