import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import '../identity/site_identity.dart';
import 'autofill_script.dart';

/// Why a fill attempt was refused, when it was.
enum AutofillRefusal {
  /// The identity layer has no unlocked engine yet.
  identityLocked,

  /// No page is open, or the page is not a real web document.
  noPage,

  /// The page is served over plain http. Filling here would put the
  /// password on the wire in cleartext.
  insecurePage,

  /// The page has no fields we recognise.
  noFieldsFound,
}

/// The outcome of a fill attempt.
class AutofillResult {
  const AutofillResult._({
    required this.filledEmail,
    required this.filledPassword,
    required this.filledHandle,
    required this.passwordFieldsSeen,
    this.refusal,
    this.domain,
  });

  const AutofillResult.refused(AutofillRefusal reason)
      : this._(
          filledEmail: 0,
          filledPassword: 0,
          filledHandle: 0,
          passwordFieldsSeen: 0,
          refusal: reason,
        );

  final int filledEmail;
  final int filledPassword;
  final int filledHandle;
  final int passwordFieldsSeen;
  final AutofillRefusal? refusal;
  final String? domain;

  bool get succeeded => refusal == null && totalFilled > 0;
  int get totalFilled => filledEmail + filledPassword + filledHandle;

  /// Wording for the user. Says what happened and, when nothing happened,
  /// what they can do about it.
  String get message {
    switch (refusal) {
      case AutofillRefusal.identityLocked:
        return 'Unlock your identity first, then try again.';
      case AutofillRefusal.noPage:
        return 'Open a site before filling.';
      case AutofillRefusal.insecurePage:
        return 'This page is not encrypted. Shadow will not put a password '
            'on an http connection.';
      case AutofillRefusal.noFieldsFound:
        return 'No sign-up or login fields found on this page.';
      case null:
        break;
    }

    final parts = <String>[];
    if (filledEmail > 0) parts.add('email');
    if (filledHandle > 0) parts.add('username');
    if (filledPassword > 0) {
      parts.add(filledPassword > 1 ? 'password and confirmation' : 'password');
    }
    final what = parts.isEmpty ? 'nothing' : parts.join(', ');
    return 'Filled $what for ${domain ?? 'this site'}. Check it over, then '
        'submit the form yourself.';
  }
}

/// Fills a page's own form with the identity derived for that page's domain.
///
/// ## Phishing resistance comes for free
///
/// Credentials are derived from the domain currently loaded, so a lookalike
/// site gets its own distinct, useless-elsewhere identity rather than the
/// real one. There is no "which saved login is this?" decision to get wrong,
/// and a user who fills on `twitter-login.example` has not leaked anything
/// that works on `twitter.com`. That property falls out of the derivation and
/// is worth protecting in any future change here.
class Autofill {
  Autofill._();

  /// Decides whether filling is allowed, without touching the page.
  ///
  /// Kept separate from [fill] so the policy is checked — and testable —
  /// before any script is built or evaluated. Returns null when filling may
  /// proceed.
  static AutofillRefusal? refusalFor({
    required Uri? pageUrl,
    required SiteIdentity? identity,
  }) {
    if (pageUrl == null || pageUrl.host.isEmpty) return AutofillRefusal.noPage;
    if (pageUrl.scheme != 'https') return AutofillRefusal.insecurePage;
    if (identity == null) return AutofillRefusal.identityLocked;
    return null;
  }

  static Future<AutofillResult> fill({
    required WebViewController controller,
    required Uri? pageUrl,
    required SiteIdentity? identity,
  }) async {
    final refusal = refusalFor(pageUrl: pageUrl, identity: identity);
    if (refusal != null) return AutofillResult.refused(refusal);

    final raw = await controller
        .runJavaScriptReturningResult(AutofillScript.build(identity!));

    final summary = _decode(raw);
    if (summary == null) {
      return const AutofillResult.refused(AutofillRefusal.noFieldsFound);
    }

    final result = AutofillResult._(
      filledEmail: summary['email'] as int? ?? 0,
      filledPassword: summary['password'] as int? ?? 0,
      filledHandle: summary['handle'] as int? ?? 0,
      passwordFieldsSeen: summary['passwordFieldsSeen'] as int? ?? 0,
      domain: identity.registrableDomain,
    );

    return result.totalFilled == 0
        ? const AutofillResult.refused(AutofillRefusal.noFieldsFound)
        : result;
  }

  /// Normalises what the platforms return.
  ///
  /// iOS hands back a native String while Android returns the value JSON
  /// encoded, so the payload arrives either as an object or as a string
  /// containing an object — sometimes double-encoded and quoted.
  static Map<String, dynamic>? _decode(Object? raw) {
    if (raw == null) return null;

    Object? value = raw;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      if (value is! String) return null;
      try {
        value = jsonDecode(value);
      } on FormatException {
        return null;
      }
    }
    return null;
  }
}
