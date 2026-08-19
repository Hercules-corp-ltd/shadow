import 'package:flutter/foundation.dart';

import '../identity/identity.dart';
import '../mail/claimable_name.dart';
import '../mail/registration_work.dart';
import '../services/local_store.dart';
import '../services/mailbox_api.dart';

/// What the device knows about this identity's one public address.
enum PublicAddressState {
  /// Nothing read from storage yet.
  loading,

  /// Storage has no name, and the mail service has not been asked.
  ///
  /// The distinction from [none] is the whole point. A fresh install of an
  /// identity that already owns a name looks exactly like an identity that
  /// owns nothing, and claiming from here would take a second name the user
  /// can never undo. So this state must not offer to claim.
  unknown,

  /// The mail service was asked and says this identity holds nothing.
  none,

  /// A name is held. See [PublicAddressProvider.claimed].
  held,
}

/// One claimed address, as kept on the device.
class ClaimedAddress {
  const ClaimedAddress({required this.name, required this.retired});

  final String name;

  /// The owner has stopped it accepting mail. Still theirs, permanently.
  final bool retired;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'retired': retired,
      };

  static ClaimedAddress fromJson(Map<String, dynamic> json) => ClaimedAddress(
        name: json['name'] as String? ?? '',
        retired: json['retired'] as bool? ?? false,
      );
}

/// Owns the one address a person can hand out.
///
/// ## Why this is separate from MailboxProvider
///
/// Every mask is per site, derived, and disposable; the interesting operations
/// on one are register, poll and burn. This is one address per identity, chosen
/// rather than derived, and it can never be burned or renamed. Folding it into
/// the same object would mean one class whose methods are half about a
/// throwaway and half about something permanent, and the two have opposite
/// failure postures: losing a mask costs an account, and losing this costs
/// every address a person has given to every human who writes to them.
class PublicAddressProvider with ChangeNotifier {
  PublicAddressProvider({
    required String Function() mailBaseUrl,
    MailboxApi Function(String baseUrl)? apiFactory,
    int powBits = 22,
  })  : _mailBaseUrl = mailBaseUrl,
        _apiFactory =
            apiFactory ?? ((String baseUrl) => MailboxApi(baseUrl: baseUrl)),
        _powBits = powBits {
    // Touch the lazy future so the read starts now rather than on first ask.
    _loaded;
  }

  static final LocalStore<ClaimedAddress> _store = LocalStore<ClaimedAddress>(
    key: 'shadow_public_address_v1',
    encode: (value) => value.toJson(),
    decode: ClaimedAddress.fromJson,
  );

  final String Function() _mailBaseUrl;
  final MailboxApi Function(String baseUrl) _apiFactory;
  final int _powBits;

  MailboxApi get _api => _apiFactory(_mailBaseUrl());

  PublicAddressState _state = PublicAddressState.loading;
  ClaimedAddress? _claimed;
  bool _busy = false;
  String? _lastProblem;
  bool _asked = false;

  /// Completes when storage has been read.
  ///
  /// Callers need this because the first thing the screen wants to do is ask
  /// the mail service when the device knows nothing — and until the read
  /// finishes, "knows nothing" is indistinguishable from "has not looked yet".
  /// Without somewhere to wait, that check runs against [
  /// PublicAddressState.loading], decides there is nothing to do, and the
  /// lookup silently never happens.
  late final Future<void> _loaded = _load();

  PublicAddressState get state => _state;
  ClaimedAddress? get claimed => _claimed;

  /// True while a claim or lookup is in flight. Both are slow.
  bool get busy => _busy;

  /// The last failure, in words for the user. Null when nothing went wrong.
  String? get lastProblem => _lastProblem;

  /// Whether the mail service has been asked at all this session.
  ///
  /// The screen needs this to avoid telling the user a lookup failed when none
  /// was ever made. "We have not asked" and "we asked and could not reach it"
  /// are different sentences, and only one of them is true at a time.
  bool get hasAsked => _asked;

  /// Proof-of-work cost, so the UI can warn before a long wait.
  int get powBits => _powBits;

  Future<void> _load() async {
    final records = await _store.readAll();
    if (records.isEmpty || records.first.name.isEmpty) {
      _state = PublicAddressState.unknown;
    } else {
      _claimed = records.first;
      _state = PublicAddressState.held;
    }
    notifyListeners();
  }

  /// Asks the mail service which name this identity holds.
  ///
  /// Safe to call on an install that has never claimed anything: it takes
  /// nothing and creates nothing. Leaves the state at [PublicAddressState
  /// .unknown] when the service cannot be reached, because "we could not ask"
  /// and "you own nothing" must not look the same here — the second one
  /// invites a claim, and a claim cannot be undone.
  Future<void> refresh({required SiteMailboxKeys keys}) async {
    await _loaded;
    _asked = true;
    _busy = true;
    _lastProblem = null;
    notifyListeners();

    final result = await _api.claimedName(keys: keys);
    switch (result) {
      case ClaimHeld(name: final name, retired: final retired):
        await _remember(ClaimedAddress(name: name, retired: retired));
      case ClaimNone():
        _claimed = null;
        _state = PublicAddressState.none;
        await _store.writeAll(const <ClaimedAddress>[]);
      case ClaimUnreachable(detail: final detail):
        _lastProblem = detail;
        if (_claimed == null) _state = PublicAddressState.unknown;
      case ClaimTaken():
      case ClaimRefused():
        // Neither is answerable by a lookup. Treat as not knowing rather than
        // inventing a meaning for it.
        _lastProblem = 'The mail service gave an answer Shadow did not expect.';
        if (_claimed == null) _state = PublicAddressState.unknown;
    }

    _busy = false;
    notifyListeners();
  }

  /// Asks once, if and only if the device does not already know.
  ///
  /// Waits for storage first. Called on screen open, so it must not fire for
  /// an identity that already has a name recorded — that would spend a round
  /// trip to be told what is already on disk.
  Future<void> ensureKnown({required SiteMailboxKeys keys}) async {
    await _loaded;
    if (_state != PublicAddressState.unknown || _busy) return;
    await refresh(keys: keys);
  }

  /// Claims [name].
  ///
  /// Returns the result so the caller can word its own message: the outcomes
  /// are genuinely different actions for the user, and flattening them to a
  /// bool is how "taken" and "we could not tell" end up sharing a sentence.
  ///
  /// A success may carry a *different* name than the one asked for — that is
  /// this identity recovering the name it already held, not a bug.
  Future<ClaimResult> claim({
    required SiteMailboxKeys keys,
    required String name,
  }) async {
    final problem = ClaimableName.check(name);
    if (problem != null) {
      // Refused here rather than after several seconds of hashing, and with
      // the real reason: the server's refusal is a single opaque status by
      // design and cannot say which character was wrong.
      return const ClaimRefused(ClaimRefusal.refusedName);
    }

    _busy = true;
    _lastProblem = null;
    notifyListeners();

    try {
      final nonce = await compute(
        _mineClaim,
        _ClaimWork(name, _powBits),
      );
      final result = await _api.claim(keys: keys, name: name, powNonce: nonce);

      switch (result) {
        case ClaimHeld(name: final held, retired: final retired):
          await _remember(ClaimedAddress(name: held, retired: retired));
        case ClaimUnreachable(detail: final detail):
          // Deliberately does not touch the stored state. The request may have
          // landed with the reply lost, so nothing here knows whether the name
          // was taken — and saying otherwise either way would be a guess.
          _lastProblem = detail;
        case ClaimTaken():
        case ClaimRefused():
        case ClaimNone():
          break;
      }
      return result;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _remember(ClaimedAddress address) async {
    _claimed = address;
    _state = PublicAddressState.held;
    await _store.writeAll(<ClaimedAddress>[address]);
  }

  /// Forgets the local copy. Does not release the name — nothing can.
  ///
  /// Only for wiping the identity off this device. The name stays bound to the
  /// key on the mail service forever, which is why there is no "give it up"
  /// anywhere in the UI: an address people have written down cannot be handed
  /// to somebody else without making every one of them reachable by a stranger.
  Future<void> forgetLocally() async {
    _claimed = null;
    _state = PublicAddressState.unknown;
    await _store.writeAll(const <ClaimedAddress>[]);
    notifyListeners();
  }
}

class _ClaimWork {
  const _ClaimWork(this.name, this.bits);
  final String name;
  final int bits;
}

/// Runs off the UI isolate. Several seconds at claim difficulty.
String _mineClaim(_ClaimWork work) =>
    RegistrationWork.mine(work.name, bits: work.bits);
