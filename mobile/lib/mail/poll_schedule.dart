/// What the browser just watched happen, which decides how hard to poll.
enum PollTrigger {
  /// A form with two or more password fields was filled — a signup. The
  /// verification mail is seconds away.
  signup,

  /// One password field: a login, possibly with email 2FA.
  login,

  /// The user asked, by opening the mailbox screen or tapping "I didn't get
  /// the code".
  manual,
}

/// When to ask the mail server again.
///
/// A pure function of "how long since the thing happened", so the whole
/// policy is testable without a single timer.
///
/// ## Foreground only, and never on a schedule of its own
///
/// There is no push and there must never be one: a device token is one
/// stable identifier per install, with no per-mailbox variant, and adding it
/// would hand the operator the very join key the rest of the design goes out
/// of its way not to have. There is no background fetch either.
///
/// So Shadow polls when it has a reason to think something is coming, and
/// otherwise not at all. It has that reason because it is the browser: it
/// watched the form get filled. A signup costs about forty small requests
/// over two minutes, once, and then silence.
class PollSchedule {
  PollSchedule._();

  /// The gap before the next poll, or null to stop.
  static Duration? intervalAt(Duration since, PollTrigger trigger) {
    if (since.isNegative) return null;

    switch (trigger) {
      case PollTrigger.signup:
        // Verification mail lands in five to thirty seconds, so the first
        // two minutes are worth watching closely. After that it is either
        // lost or the user has wandered off.
        if (since < const Duration(seconds: 120)) {
          return const Duration(seconds: 3);
        }
        if (since < const Duration(seconds: 300)) {
          return const Duration(seconds: 10);
        }
        if (since < const Duration(seconds: 900)) {
          return const Duration(seconds: 30);
        }
        return null;

      case PollTrigger.login:
        if (since < const Duration(seconds: 60)) {
          return const Duration(seconds: 5);
        }
        return null;

      case PollTrigger.manual:
        if (since < const Duration(seconds: 60)) {
          return const Duration(seconds: 5);
        }
        return null;
    }
  }

  /// How long this trigger stays interested at all.
  static Duration windowFor(PollTrigger trigger) {
    switch (trigger) {
      case PollTrigger.signup:
        return const Duration(seconds: 900);
      case PollTrigger.login:
      case PollTrigger.manual:
        return const Duration(seconds: 60);
    }
  }

  /// Which trigger a completed fill implies.
  ///
  /// `passwordFieldsSeen` already rides along on `AutofillResult`, so no new
  /// JavaScript is needed to tell a signup from a login: two password boxes
  /// on one screen is a signup form with a confirmation field.
  static PollTrigger triggerForFill({required int passwordFieldsSeen}) {
    return passwordFieldsSeen >= 2 ? PollTrigger.signup : PollTrigger.login;
  }
}
