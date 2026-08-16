import 'dart:convert';

import '../identity/site_identity.dart';

/// Builds the JavaScript that fills a site's own signup or login form with a
/// derived identity.
///
/// ## It fills. It never submits.
///
/// There is no click, no form.submit(), no Enter key anywhere in this script,
/// and that is a deliberate product boundary rather than an oversight. A tool
/// that fills a form while a person watches is a credential manager; one that
/// also presses the button is an agent creating accounts on its own, which is
/// what every anti-fraud system on the web is built to stop and what the terms
/// of most sites prohibit. Keeping the submit gesture with the human is what
/// keeps this defensible, and it is also why the behavioural telemetry a site
/// collects stays genuinely human — because it is.
///
/// The script likewise never touches a CAPTCHA, a challenge frame or an SMS
/// field. Those are handed to the person.
class AutofillScript {
  AutofillScript._();

  /// Escapes what JSON leaves alone but JavaScript does not.
  ///
  /// `jsonEncode` deals with quotes and backslashes. It does not touch angle
  /// brackets, and today that is harmless because this payload is evaluated
  /// directly rather than written into a script element — but that is a
  /// property of the injection method, not of the string, and it stops being
  /// true the moment anyone builds a script tag instead.
  ///
  /// Not hypothetical hygiene: the alias domain is free text the user types,
  /// so it is the one credential component whose characters are not drawn
  /// from a constrained alphabet. U+2028 and U+2029 are escaped too, since
  /// both are literal line terminators inside a JavaScript string.
  ///
  /// The escape is assembled from its parts rather than written as a literal,
  /// so nothing in this file contains a sequence that source-rewriting tools
  /// might normalise back into the character it is meant to encode.
  static String harden(String json) {
    const escapeMe = <int>{0x3C, 0x3E, 0x2028, 0x2029};
    final out = StringBuffer();
    for (final rune in json.runes) {
      if (escapeMe.contains(rune)) {
        out.writeCharCode(0x5C);
        out.write('u');
        out.write(rune.toRadixString(16).padLeft(4, '0').toUpperCase());
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// Produces an IIFE that returns a JSON summary of what it filled.
  static String build(SiteIdentity identity) {
    final payload = harden(jsonEncode(<String, String>{
      'email': identity.email,
      'password': identity.password,
      'handle': identity.handle,
    }));

    return '''
(function () {
  var creds = $payload;
  var filled = { email: 0, password: 0, handle: 0 };

  function visible(el) {
    if (!el || el.disabled || el.readOnly) return false;
    if (el.type === 'hidden') return false;
    var style = window.getComputedStyle(el);
    if (style.visibility === 'hidden' || style.display === 'none') return false;
    var rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
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

  // React and Vue track input values through a property descriptor, so a
  // plain el.value = x updates the DOM but never reaches the framework's
  // state — the field looks filled and then submits empty. Going through the
  // native setter and dispatching the events is what makes controlled
  // components actually register the change.
  function setValue(el, value) {
    var proto = el instanceof HTMLTextAreaElement
      ? HTMLTextAreaElement.prototype
      : HTMLInputElement.prototype;
    var descriptor = Object.getOwnPropertyDescriptor(proto, 'value');
    if (descriptor && descriptor.set) {
      descriptor.set.call(el, value);
    } else {
      el.value = value;
    }
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }

  // Only ever write into a box a person types text into.
  //
  // This is a whitelist on purpose. <input type="submit" name="login"> and
  // <input type="checkbox" name="email_updates"> are both ordinary markup,
  // both match the name patterns below, and naming the bad types one at a
  // time is a game you lose one form at a time. The consequences are not
  // cosmetic either: a submit input's value is its visible label, and a
  // ticked checkbox's value goes into the POST body, so a credential
  // written into one is a credential sent to the site under another name.
  var TEXT_ENTRY = { '': 1, 'text': 1, 'email': 1 };

  function textEntry(el) {
    if (el.tagName === 'TEXTAREA') return true;
    return TEXT_ENTRY[(el.getAttribute('type') || '').toLowerCase()] === 1;
  }

  var inputs = [];
  var all = document.querySelectorAll('input, textarea');
  for (var i = 0; i < all.length; i++) {
    if (visible(all[i])) inputs.push(all[i]);
  }

  var passwords = [];
  var emails = [];
  var handles = [];

  for (var j = 0; j < inputs.length; j++) {
    var el = inputs[j];
    var type = (el.getAttribute('type') || '').toLowerCase();
    var h = hint(el);

    if (type === 'password') { passwords.push(el); continue; }
    if (!textEntry(el)) continue;
    if (type === 'email' || /e-?mail/.test(h)) { emails.push(el); continue; }

    // Only treat a plain text field as a username when it says so. Guessing
    // here means writing a handle into a "full name" or "company" box.
    if (/(^|[^a-z])(username|user_name|login|handle|nickname|screen_?name)/
          .test(h)) {
      handles.push(el);
    }
  }

  for (var k = 0; k < emails.length; k++) {
    setValue(emails[k], creds.email);
    filled.email++;
  }

  for (var m = 0; m < handles.length; m++) {
    setValue(handles[m], creds.handle);
    filled.handle++;
  }

  // Two password boxes on one screen is a signup form with a confirmation
  // field, so both take the same value. More than two is unusual enough that
  // filling them all would probably be wrong, so only the first two are set.
  var limit = passwords.length > 2 ? 2 : passwords.length;
  for (var n = 0; n < limit; n++) {
    setValue(passwords[n], creds.password);
    filled.password++;
  }

  // Nothing is clicked and no form is submitted. The person does that.
  creds = null;
  return JSON.stringify({
    email: filled.email,
    password: filled.password,
    handle: filled.handle,
    passwordFieldsSeen: passwords.length
  });
})();
''';
  }
}
