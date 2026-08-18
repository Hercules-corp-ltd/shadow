import 'dart:async';

import 'package:flutter/foundation.dart';

import '../identity/identity.dart';
import '../mail/alias_activity.dart';
import '../mail/code_extraction.dart';
import '../mail/mime_lite.dart';
import '../mail/poll_schedule.dart';
import '../mail/registration_work.dart';
import '../mail/sealed_mail.dart';
import '../models/site_adapter_record.dart';
import '../services/fetch_outcome.dart';
import '../services/mailbox_api.dart';
import '../services/site_adapter_service.dart';

/// Why a mailbox is not usable, when it is not.
enum MailboxProblem {
  /// The mail server could not be reached at all.
  unreachable,

  /// It answered, and refused.
  refused,
}

/// What came back from trying to claim an address.
class RegistrationOutcome {
  const RegistrationOutcome._({this.problem, this.detail = ''});

  const RegistrationOutcome.ok() : this._();
  const RegistrationOutcome.failed(MailboxProblem problem, String detail)
      : this._(problem: problem, detail: detail);

  final MailboxProblem? problem;
  final String detail;

  bool get succeeded => problem == null;
}

/// Runs proof of work off the UI thread.
///
/// A second of hashing on the main isolate is a second of frozen scrolling.
String _mineOffThread(_MineRequest request) =>
    RegistrationWork.mine(request.localPart, bits: request.bits);

class _MineRequest {
  const _MineRequest(this.localPart, this.bits);
  final String localPart;
  final int bits;
}

/// Owns mailboxes: claiming them, watching them, opening what arrives.
///
/// ## Nothing decrypted is ever written down
///
/// Messages live in this object and nowhere else, mirroring `SiteIdentity`'s
/// posture — it can always be fetched again while the server still has it,
/// so there is no reason for a copy to exist on disk, in a log or in a crash
/// report. What persists in the adapter record is the cursor and a few
/// counts — how much has arrived, how much was opened, the day of the last
/// check. None of them holds a sender, a subject or a word of any message.
class MailboxProvider with ChangeNotifier {
  MailboxProvider({
    required String Function() mailBaseUrl,
    SiteAdapterService adapters = const SiteAdapterService(),
    MailboxApi Function(String baseUrl)? apiFactory,
    int powBits = 20,
  })  : _mailBaseUrl = mailBaseUrl,
        _adapters = adapters,
        _apiFactory =
            apiFactory ?? ((String baseUrl) => MailboxApi(baseUrl: baseUrl)),
        _powBits = powBits;

  final String Function() _mailBaseUrl;
  final SiteAdapterService _adapters;
  final MailboxApi Function(String baseUrl) _apiFactory;
  final int _powBits;

  Timer? _timer;
  DateTime? _watchStartedAt;
  PollTrigger? _trigger;
  SiteMailboxKeys? _watching;
  String? _watchingDomain;
  int _watchingAccountIndex = 0;

  final List<ExtractedCredential> _found = <ExtractedCredential>[];

  /// Codes and links pulled from mail that has arrived this session.
  List<ExtractedCredential> get found => List.unmodifiable(_found);

  /// The registrable domain the current findings belong to.
  String? get foundForDomain => _watchingDomain;

  bool get isWatching => _timer != null;

  MailboxApi get _api => _apiFactory(_mailBaseUrl());

  /// Claims the address for [domain], if it is not claimed already.
  ///
  /// Idempotent: an address already registered to this key succeeds without
  /// touching the network a second time.
  Future<RegistrationOutcome> ensureRegistered({
    required SiteMailboxKeys keys,
    required String domain,
    required String aliasDomain,
    int accountIndex = 0,
  }) async {
    final record = await _adapters.resolve(domain, accountIndex: accountIndex);
    if (record.account.mailbox.isRegistered &&
        record.account.mailbox.localPart == keys.localPart) {
      return const RegistrationOutcome.ok();
    }

    final pow = await compute(
      _mineOffThread,
      _MineRequest(keys.localPart, _powBits),
    );

    final outcome = await _api.register(keys: keys, powNonce: pow);

    switch (outcome) {
      case FetchSuccess<MailboxReceipt>(value: final receipt):
        // Check the server is sealing to the key we actually hold, before
        // this address goes anywhere near a form. A substituted
        // registration would otherwise eat the user's mail forever, and the
        // account would be unrecoverable with no error at any point.
        final expected = await keys.x25519PublicKey();
        if (!receipt.matches(expected)) {
          await _adapters.markMailbox(
            domain,
            accountIndex: accountIndex,
            state: MailboxState.failed,
            localPart: keys.localPart,
          );
          return const RegistrationOutcome.failed(
            MailboxProblem.refused,
            'The mail server registered a different key for this address.',
          );
        }

        await _adapters.markMailbox(
          domain,
          accountIndex: accountIndex,
          state: MailboxState.registered,
          localPart: keys.localPart,
          aliasDomain: aliasDomain,
        );
        return const RegistrationOutcome.ok();

      case FetchNotFound<MailboxReceipt>():
        await _markFailed(domain, accountIndex, keys.localPart);
        return const RegistrationOutcome.failed(
          MailboxProblem.refused,
          'The mail server did not accept the address.',
        );

      case FetchUnreachable<MailboxReceipt>(reason: final reason):
        await _markFailed(domain, accountIndex, keys.localPart);
        return RegistrationOutcome.failed(MailboxProblem.unreachable, reason);
    }
  }

  Future<void> _markFailed(String domain, int accountIndex, String localPart) {
    return _adapters.markMailbox(
      domain,
      accountIndex: accountIndex,
      state: MailboxState.failed,
      localPart: localPart,
    );
  }

  /// Works out which alias epoch a site is really on, after the local
  /// record has been lost.
  ///
  /// ## Why this is lazy and per site, not a sweep at launch
  ///
  /// The obvious design — walk every known site on startup and probe them —
  /// cannot work and should not. It cannot, because after the store is gone
  /// there is no list of sites: nothing else records which ones the user
  /// has, and that absence is deliberate. And it should not, because a burst
  /// of probes from one IP within a few seconds hands the operator a perfect
  /// grouping of that user's entire mailbox set, which is exactly the
  /// linkage the rest of the design goes out of its way not to create.
  ///
  /// So it runs when the user is standing on a site and about to derive for
  /// it — one domain, at a moment the operator learns about anyway because
  /// registration or polling for that same site is about to happen.
  ///
  /// ## What this cannot recover
  ///
  /// The password epoch. It is not in the mail derivation, so the server has
  /// never seen anything derived from it and no probe can find it. That
  /// failure is at least loud — a stale password is rejected by the site,
  /// visibly — where a stale address fails silently, mail going nowhere with
  /// nothing to indicate it. Recovering the password epoch needs the
  /// encrypted export instead.
  Future<int?> recoverAliasEpoch({
    required SiteMailboxKeys? Function(int aliasEpoch) derive,
    int maxEpoch = 8,
  }) async {
    int? highest;

    for (var epoch = 1; epoch <= maxEpoch; epoch++) {
      // Null means the identity locked partway through. Stop rather than
      // report a highest found so far, which would be a partial answer
      // presented as a complete one.
      final keys = derive(epoch);
      if (keys == null) return null;

      final outcome = await _api.probe(keys: keys);

      switch (outcome) {
        case FetchSuccess<bool>(value: final exists):
          if (exists) highest = epoch;
        case FetchNotFound<bool>():
          break;
        case FetchUnreachable<bool>():
          // Cannot ask. Returning what has been found so far would be a
          // guess dressed as an answer, and adopting a too-low epoch writes
          // a wrong address into a form.
          return null;
      }
    }
    return highest;
  }

  /// Starts watching a mailbox, because something is expected to arrive.
  ///
  /// Foreground only, and only after the browser has watched something
  /// happen. There is no idle polling and no push: a device token would be
  /// one stable identifier per install with no per-mailbox variant, which is
  /// exactly the join key the rest of this design refuses to have.
  void watch({
    required SiteMailboxKeys keys,
    required String domain,
    required PollTrigger trigger,
    int accountIndex = 0,
  }) {
    stop();
    _watching = keys;
    _watchingDomain = domain;
    _watchingAccountIndex = accountIndex;
    _trigger = trigger;
    _watchStartedAt = DateTime.now();
    _found.clear();
    notifyListeners();
    _scheduleNext();
  }

  /// Stops early — the user navigated away, or backgrounded the app.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _watchStartedAt = null;
    _trigger = null;
    _watching = null;
  }

  /// Whether arrivals at this mailbox mean anything worth counting.
  ///
  /// The identity's one public address is the case this exists to exclude. It
  /// is handed to people on purpose, so mail from strangers is the feature
  /// working, and a card counting arrivals there would be noise that teaches
  /// the user to ignore the same card on the aliases where it matters.
  ///
  /// The discriminator is [SiteMode.public], not [SiteMode.masked]. Requiring
  /// `masked` looked equivalent and is not: a site switched back to normal
  /// browsing keeps the alias it registered earlier, and that address goes on
  /// receiving. Refusing to count there would leave "check for new mail"
  /// polling and recording nothing, with the card still reading "not checked
  /// yet" — a control reporting an outcome it did not achieve, on the one
  /// screen where that address can still be seen at all.
  ///
  /// Key shape alone is not enough either, since the public address derives
  /// the same kind of keys. So: not the public mode, a registered mailbox,
  /// the one these keys actually name, and alias-shaped — twenty characters,
  /// which a claimed public name can never be, being capped at nineteen
  /// precisely so the two namespaces cannot overlap.
  static final RegExp _aliasShaped = RegExp(r'^[a-z2-7]{20}$');

  bool _countsArrivalsFor(SiteAdapterRecord record, SiteMailboxKeys keys) {
    final mailbox = record.account.mailbox;
    return record.account.mode != SiteMode.public &&
        mailbox.state == MailboxState.registered &&
        mailbox.localPart == keys.localPart &&
        _aliasShaped.hasMatch(keys.localPart);
  }

  /// Fetches now, at the user's asking, rather than waiting for a window.
  ///
  /// Separate from [watch] because the two want opposite endings: a signup
  /// watch stops the moment a code arrives, which is what the user was
  /// waiting for. Someone tapping "check for new mail" wants the count
  /// brought up to date, so this does one pass and stops either way.
  Future<void> checkNow({
    required SiteMailboxKeys keys,
    required String domain,
    int accountIndex = 0,
  }) async {
    stop();
    _watching = keys;
    _watchingDomain = domain;
    _watchingAccountIndex = accountIndex;
    _trigger = PollTrigger.manual;
    _watchStartedAt = DateTime.now();
    notifyListeners();

    await _pollOnce();

    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  /// Closes a mailbox server-side, so mail to it is refused rather than
  /// stored. Part of committing an alias burn.
  ///
  /// The outcome is passed through rather than flattened to a bool. A
  /// mailbox the server has never heard of is already as closed as it can
  /// be; a server we could not reach has closed nothing. Collapsing those
  /// two into "failed" would either block a burn that is already finished or
  /// report one that never started.
  Future<FetchOutcome<void>> retire({required SiteMailboxKeys keys}) =>
      _api.retire(keys: keys);

  /// Drops findings once they have been used or dismissed.
  void clearFound() {
    if (_found.isEmpty) return;
    _found.clear();
    notifyListeners();
  }

  void _scheduleNext() {
    final startedAt = _watchStartedAt;
    final trigger = _trigger;
    if (startedAt == null || trigger == null) return;

    final next = PollSchedule.intervalAt(
      DateTime.now().difference(startedAt),
      trigger,
    );
    if (next == null) {
      stop();
      notifyListeners();
      return;
    }

    _timer = Timer(next, () async {
      await _pollOnce();
      _scheduleNext();
    });
  }

  Future<void> _pollOnce() async {
    final keys = _watching;
    final domain = _watchingDomain;
    if (keys == null || domain == null) return;

    final record =
        await _adapters.resolve(domain, accountIndex: _watchingAccountIndex);
    final cursor = int.tryParse(record.account.mailbox.cursor ?? '') ?? 0;

    final outcome = await _api.poll(keys: keys, cursor: cursor);
    if (outcome is! FetchSuccess<MailboxPage>) return;

    final page = outcome.value;

    var highest = cursor;
    var opened = 0;
    for (final sealed in page.messages) {
      final plaintext =
          await SealedMail.open(envelope: sealed.envelope, keys: keys);
      // The cursor moves only past what was actually opened. Advancing it
      // first meant a message that failed to unseal — a truncated envelope,
      // a transient decrypt failure — was skipped permanently on the next
      // poll, and the one that gets skipped is a verification code.
      if (plaintext == null) continue;
      highest = sealed.seq > highest ? sealed.seq : highest;
      opened++;

      final message = MimeLite.parse(plaintext);
      _found.addAll(
        CodeExtraction.extract(message, aliasLocalPart: keys.localPart),
      );
    }

    // The ledger is written on every answered poll, including one that found
    // nothing — recording the day is what separates "checked, and quiet" from
    // "never looked", and only one of those is reassuring.
    var mailbox = record.account.mailbox;
    if (highest > cursor) mailbox = mailbox.copyWith(cursor: '$highest');

    if (_countsArrivalsFor(record, keys)) {
      mailbox = AliasActivity.record(
        mailbox,
        deliveredSeq: page.cursor,
        opened: opened,
        today: AliasActivity.dayOf(DateTime.now()),
      );
    }

    await _adapters.upsert(
      record.copyWith(account: record.account.copyWith(mailbox: mailbox)),
    );

    if (_found.isNotEmpty) {
      // Something arrived and was readable. Stop asking.
      stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
