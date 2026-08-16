import 'dart:convert';

import 'autofill_script.dart';

/// Types a verification code into the page's own code field.
///
/// ## Why this is a separate file from AutofillScript
///
/// `autofill_test.dart` asserts that the credential script contains no
/// occurrence of `otp`, `captcha` or `recaptcha`, and that assertion must
/// keep passing untouched. It is not pedantry: it defends a real boundary,
/// which is that the thing filling a signup form never goes near a
/// challenge field.
///
/// This is a different operation with a different gate. It runs only after
/// the user has read a code in Shadow's own chrome and tapped to accept it,
/// and it fills exactly one field. Keeping it in its own file means the
/// credential script's guarantee stays literally true rather than becoming
/// a comment about intent.
///
/// ## It fills. It never submits.
///
/// Same rule as the credential path, and here it carries more weight,
/// because a code arriving is a *server-timed* event. Letting something the
/// server chose the moment of write into a page and press the button is the
/// line between a credential manager and an agent creating accounts on its
/// own. The tap keeps the gesture human.
class CodeFillScript {
  CodeFillScript._();

  /// Builds the injection for [code].
  ///
  /// [expectedDomain] is the registrable domain that owns the mailbox this
  /// code arrived in. The script refuses to fill anything if the page has
  /// moved somewhere else since the user tapped — the check is repeated
  /// in-page rather than trusted from Dart, because navigation can happen
  /// between the two.
  static String build({
    required String code,
    required String expectedDomain,
  }) {
    final payload = AutofillScript.harden(
      jsonEncode(<String, String>{
        'code': code,
        'domain': expectedDomain,
      }),
    );

    return '''
(function () {
  var input = $payload;

  // The page must still be the site whose mailbox this code arrived in.
  // Shadow checks this before injecting too; doing it again here closes the
  // window between the user's tap and this script running.
  var host = String(location.hostname || '').toLowerCase();
  var wanted = String(input.domain || '').toLowerCase();
  if (host !== wanted && host !== 'www.' + wanted &&
      host.lastIndexOf('.' + wanted) !== host.length - wanted.length - 1) {
    return JSON.stringify({ filled: 0, refused: 'domain' });
  }

  function visible(el) {
    if (!el || el.disabled || el.readOnly) return false;
    if (el.type === 'hidden') return false;
    var style = window.getComputedStyle(el);
    if (style.visibility === 'hidden' || style.display === 'none') return false;
    var rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  // React and Vue track values through a property descriptor, so a plain
  // el.value = x updates the DOM and never reaches the framework's state —
  // the field looks filled and then submits empty.
  function setValue(el, value) {
    var descriptor = Object.getOwnPropertyDescriptor(
      HTMLInputElement.prototype, 'value');
    if (descriptor && descriptor.set) {
      descriptor.set.call(el, value);
    } else {
      el.value = value;
    }
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }

  function hint(el) {
    return [
      el.getAttribute('autocomplete'),
      el.getAttribute('name'),
      el.getAttribute('id'),
      el.getAttribute('placeholder'),
      el.getAttribute('aria-label')
    ].join(' ').toLowerCase();
  }

  var all = document.querySelectorAll('input');
  var candidates = [];
  for (var i = 0; i < all.length; i++) {
    if (visible(all[i])) candidates.push(all[i]);
  }

  // Fields that contain the word "code" and are emphatically not this one.
  //
  // A discount box is the single most common false positive on a checkout
  // or signup page, and "coupon_code" matches a naive /code/ rule perfectly.
  function isDecoy(h) {
    return /(coupon|promo|discount|voucher|gift|referral|invite|zip|postal)/
      .test(h);
  }

  function eligible(el) {
    var type = (el.getAttribute('type') || '').toLowerCase();
    if (type === 'password' || type === 'submit' || type === 'button' ||
        type === 'checkbox' || type === 'radio' || type === 'email' ||
        type === 'tel' || type === 'search') {
      return false;
    }
    return !isDecoy(hint(el));
  }

  // How explicitly a field says it is the one-time code field.
  function rankOf(el) {
    var h = hint(el);
    // What both platforms' native autofill actually keys on.
    if (/one-time-code/.test(h)) return 4;
    if (/(^|[^a-z])(otp|verification|passcode)/.test(h)) return 3;
    if (/(^|[^a-z])(code|pin|token)/.test(h)) return 2;
    var inputMode = (el.getAttribute('inputmode') || '').toLowerCase();
    var len = parseInt(el.getAttribute('maxlength'), 10);
    if (inputMode === 'numeric' && len > 0 && len <= 8) return 1;
    return 0;
  }

  var usable = [];
  for (var j = 0; j < candidates.length; j++) {
    if (eligible(candidates[j])) usable.push(candidates[j]);
  }

  var best = null;
  var bestRank = 0;
  for (var k = 0; k < usable.length; k++) {
    var rank = rankOf(usable[k]);
    if (rank > bestRank) {
      bestRank = rank;
      best = usable[k];
    }
  }

  // Split-digit boxes, found by shape rather than by name.
  //
  // Extremely common on verification screens, and exactly what a naive
  // el.value = code gets wrong: the whole code lands in the first box and
  // is truncated to one character. Names are no help — real ones are called
  // everything from "otp-1" to "d1" — so what identifies a row is that it
  // IS a row: enough sibling inputs, in document order, each holding one
  // character. That structure is not something another kind of field
  // accidentally has.
  var row = [];
  for (var m = 0; m < usable.length; m++) {
    var el = usable[m];
    if (parseInt(el.getAttribute('maxlength'), 10) === 1) {
      if (row.length > 0 && row[row.length - 1].parentNode !== el.parentNode) {
        row = [];
      }
      row.push(el);
      if (row.length >= input.code.length) break;
    } else if (row.length > 0) {
      row = [];
    }
  }

  // An explicitly named field beats structure; structure beats a guess.
  if (bestRank < 3 && row.length >= input.code.length) {
    for (var c = 0; c < input.code.length; c++) {
      setValue(row[c], input.code.charAt(c));
    }
    return JSON.stringify({ filled: input.code.length, split: true });
  }

  if (!best) return JSON.stringify({ filled: 0, refused: 'no-field' });

  setValue(best, input.code);

  // Nothing is clicked and no form is submitted. The person does that.
  return JSON.stringify({ filled: 1, split: false });
})();
''';
  }

  /// How many fields the injected script actually wrote to.
  ///
  /// The platforms disagree about what a JavaScript return value looks like
  /// coming back — iOS hands over a native String, Android a JSON-encoded
  /// one, sometimes double-encoded — so this unwraps the same way
  /// `Autofill._decode` does. Zero means the page had no code field, which
  /// the caller must say out loud rather than claiming a fill.
  static int filledCount(Object? raw) {
    Object? value = raw;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (value is Map) return (value['filled'] as int?) ?? 0;
      if (value is! String) return 0;
      try {
        value = jsonDecode(value);
      } on FormatException {
        return 0;
      }
    }
    return 0;
  }

  /// Whether a code from [mailboxDomain] may be offered on [pageUrl].
  ///
  /// Pure, so the rule is testable without a page. **This is the check that
  /// kills cross-site code phishing outright**: a code may only ever go into
  /// the site whose mailbox it arrived in, no matter how convincing the mail
  /// that carried it. Shadow can enforce it because, unlike every other
  /// autofill, it knows which site the mailbox belongs to.
  static bool mayOffer({
    required Uri? pageUrl,
    required String mailboxDomain,
  }) {
    if (pageUrl == null || pageUrl.host.isEmpty) return false;
    // https only, same as the credential path.
    if (pageUrl.scheme != 'https') return false;
    if (mailboxDomain.isEmpty) return false;

    final host = pageUrl.host.toLowerCase();
    final domain = mailboxDomain.toLowerCase();
    return host == domain || host.endsWith('.$domain');
  }
}
