import '../models/site_adapter_record.dart';

/// What has arrived at one alias, and how much of it Shadow has seen.
///
/// ## Why this counts instead of accusing
///
/// The obvious feature here is a leak canary: every site gets its own
/// address, so mail arriving at site A's address from anyone but site A is
/// proof that A sold, shared or lost it. Nothing else can offer that, because
/// nothing else has per-site addresses. It does not survive contact with the
/// evidence.
///
/// **Every signal about a sender is written by the sender.** The Worker seals
/// the message exactly as it arrived and reads nothing out of it, so the only
/// view this device has of "who sent this" is the `From:` line the sender
/// typed. `DKIM-Signature: d=` is no better — it is a header, unverified here,
/// and a leaker can set it to the site's own domain to keep the alarm quiet.
/// Worse, the same freedom points the other way: anyone who learns an alias
/// can send it a message naming an innocent company and have Shadow display
/// that company as the culprit. An alarm an attacker can aim is not an alarm.
///
/// **And authentication would not rescue it.** Suppose every sender were
/// perfectly verified. Mail from a site legitimately arrives from the ESP it
/// pays, its payment processor, its helpdesk vendor, its auth provider, its
/// parent company after an acquisition, and its regional domain. None of
/// those match, and none of them are leaks. A rule firing on all of that
/// would be wrong far more often than right — and being wrong here means
/// telling a user that a named company sold their address.
///
/// So the accusation is not available at any price. What *is* available is a
/// count that no sender can move: the mail service's own per-mailbox
/// sequence, which only rises when it accepts a delivery to a twenty
/// character address derived from a key this device holds. Shadow can say
/// how much arrived and when it last looked. The user knows whether they gave
/// the address to anyone, which Shadow does not. So Shadow states the number
/// and the person draws the conclusion — and the remedy, replacing the
/// address, is the same one whatever the cause turned out to be.
class AliasActivity {
  AliasActivity._();

  /// Folds one completed poll into the record.
  ///
  /// [deliveredSeq] is the server's cursor from the poll response, [opened]
  /// is how many messages this device actually unsealed and parsed in that
  /// poll, and [today] is whole days since the epoch from the device clock.
  ///
  /// Called for an empty page too. A poll that found nothing is the whole
  /// point of recording the day: without it, "checked and quiet" and "never
  /// looked" are the same blank card, and only one of them is reassuring.
  static MailboxRecord record(
    MailboxRecord mailbox, {
    required int deliveredSeq,
    required int opened,
    required int today,
  }) {
    // The server's sequence only ever climbs. Taking the max rather than
    // assigning means an operator that answers with a lower number — or a
    // reordered response — cannot walk the count backwards and quietly erase
    // an arrival the user has already been shown.
    final delivered =
        deliveredSeq > mailbox.delivered ? deliveredSeq : mailbox.delivered;

    return mailbox.copyWith(
      delivered: _clamp(delivered),
      opened: _clamp(mailbox.opened + (opened < 0 ? 0 : opened)),
      checkedDay: today,
    );
  }

  /// Marks everything that has arrived so far as seen by the user.
  ///
  /// Stores a number, never which senders were dismissed. A per-sender
  /// dismissal would be an allowlist, and an allowlist of who may write to
  /// you is a contact graph — sitting in ordinary app storage, and travelling
  /// in every backup.
  static MailboxRecord acknowledge(MailboxRecord mailbox) =>
      mailbox.copyWith(acknowledged: _clamp(mailbox.delivered));

  static int _clamp(int value) {
    if (value < 0) return 0;
    return value > MailboxRecord.countCap ? MailboxRecord.countCap : value;
  }

  /// Whole days since the Unix epoch, UTC.
  ///
  /// A day bucket rather than a timestamp, matching the rule the mail
  /// service's own schema states: an exact time of arrival is a behavioural
  /// record, and a day is enough to say "last week".
  static int dayOf(DateTime moment) =>
      moment.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}
