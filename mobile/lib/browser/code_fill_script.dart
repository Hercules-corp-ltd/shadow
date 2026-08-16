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

  // Split-digit boxes: six inputs of maxlength 1, one character each.
  //
  // Extremely common on verification screens, and exactly the shape a naive
  // el.value = code gets wrong — it drops the whole code into the first box,
  // which then truncates it to one character.
  var boxes = [];
  for (var b = 0; b < candidates.length; b++) {
    var maxLength = parseInt(candidates[b].getAttribute('maxlength'), 10);
    if (maxLength === 1) boxes.push(candidates[b]);
  }
  if (boxes.length >= input.code.length) {
    for (var c = 0; c < input.code.length; c++) {
      setValue(boxes[c], input.code.charAt(c));
    }
    return JSON.stringify({ filled: input.code.length, split: true });
  }

  // Otherwise one field, chosen in descending order of how explicitly it
  // says what it is.
  var best = null;
  var bestRank = 0;

  for (var j = 0; j < candidates.length; j++) {
    var el = candidates[j];
    var type = (el.getAttribute('type') || '').toLowerCase();
    if (type === 'password' || type === 'submit' || type === 'button' ||
        type === 'checkbox' || type === 'radio' || type === 'email') {
      continue;
    }

    var h = hint(el);
    var rank = 0;

    // What both platforms' native autofill actually keys on.
    if (/one-time-code/.test(h)) {
      rank = 4;
    } else if (/(^|[^a-z])(otp|verification|passcode)/.test(h)) {
      rank = 3;
    } else if (/(^|[^a-z])(code|pin|token)/.test(h)) {
      rank = 2;
    } else {
      var inputMode = (el.getAttribute('inputmode') || '').toLowerCase();
      var len = parseInt(el.getAttribute('maxlength'), 10);
      if (inputMode === 'numeric' && len > 0 && len <= 8) rank = 1;
    }

    if (rank > bestRank) {
      bestRank = rank;
      best = el;
    }
  }

  if (!best) return JSON.stringify({ filled: 0, refused: 'no-field' });

  setValue(best, input.code);

  // Nothing is clicked and no form is submitted. The person does that.
  return JSON.stringify({ filled: 1, split: false });
})();
''';
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
