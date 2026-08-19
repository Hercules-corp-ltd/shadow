/// A real envelope, produced by the mail Worker.
///
/// Generated against `services/mail-worker` running under `wrangler dev`,
/// from fixed seeds, and pasted here verbatim.
///
/// The point is that this was sealed by the *other* implementation. A test
/// that seals and opens with the same Dart code proves the code is
/// self-consistent, which is not the property that matters: the two halves
/// live in different languages, on different runtimes, using different
/// crypto libraries, and they have to agree byte for byte or mail silently
/// cannot be read. This constant is the only thing in the suite that can
/// catch them drifting apart.
library;

/// 32 bytes of 0x07 then 32 bytes of 0x09 — the mail/v1 material the
/// fixture was built from.
const String fixtureSignSeedB64 =
    'BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc=';
const String fixtureSealSeedB64 =
    'CQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQk=';

const String fixtureLocalPart = 'exkhu6wfl3lx2pexvcgx';
const String fixtureEd25519PubB64 =
    '6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iw=';
const String fixtureX25519PubB64 =
    'V9tLNZ8jrl4Ubk4lEgVnBHIlBjSMFQwUdT0Mkz0E1CE=';

const String fixturePlaintext = 'From: Twitter <verify@twitter.com>\r\n'
    'Subject: 483920 is your code\r\n'
    '\r\n'
    'Your code is 483920.';

/// epk(32) ‖ nonce(12) ‖ ciphertext ‖ tag(16), padded to the 4 KB bucket.
const String fixtureEnvelopeB64 =
    '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';
