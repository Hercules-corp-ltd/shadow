import '../identity/identity.dart';

/// How Shadow behaves on one site.
///
/// Sticky per site, and the default is [off] — Shadow is an ordinary browser
/// until asked. That is a privacy property as much as a usability one: the
/// mail service never hears about a site the user merely visited.
enum SiteMode {
  /// Normal browsing. No derived identity, no contact with the mail service.
  off,

  /// A per-site alias, password and username. Unlinkable to every other site.
  masked,

  /// The user's one shareable address, plus a derived password. For places
  /// they want to be findable — a mailing list, a shop that has to look up
  /// an order.
  public,
}

/// Where the mailbox for this site has got to.
enum MailboxState {
  /// Never registered with the mail service.
  none,

  /// Registration was attempted and did not land. The address must not be
  /// filled into a signup form in this state — mail sent to it would go
  /// nowhere and the account would be unrecoverable.
  failed,

  /// Registered and receiving.
  registered,

  /// Deliberately burned. Kept so an old address can be recognised rather
  /// than silently forgotten.
  retired,
}

/// The public half of an adapter: facts about a site, true for everyone.
///
/// This is the part that could eventually be published — on chain, or in a
/// community bundle — because it says nothing about any particular user.
class SitePolicy {
  const SitePolicy({
    this.passwordPolicy = PasswordPolicy.standard,
    this.handleSeparator = '',
  });

  final PasswordPolicy passwordPolicy;
  final String handleSeparator;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'password_policy': passwordPolicy.toJson(),
        'handle_separator': handleSeparator,
      };

  /// Never throws. See [SiteAdapterRecord.fromJson].
  factory SitePolicy.fromJson(Map<String, dynamic> json) {
    PasswordPolicy policy = PasswordPolicy.standard;
    final raw = json['password_policy'];
    if (raw is Map) {
      try {
        policy = PasswordPolicy.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {
        policy = PasswordPolicy.standard;
      }
    }
    return SitePolicy(
      passwordPolicy: policy,
      handleSeparator: json['handle_separator'] as String? ?? '',
    );
  }
}

/// What Shadow knows about this user's mailbox on this site.
class MailboxRecord {
  const MailboxRecord({
    this.state = MailboxState.none,
    this.localPart,
    this.aliasDomain,
    this.cursor,
    this.delivered = 0,
    this.opened = 0,
    this.checkedDay,
    this.acknowledged = 0,
  });

  /// Counts saturate here rather than growing without bound.
  ///
  /// The mail service caps a mailbox at 50 messages for its whole life, so
  /// anything past this is a broken or hostile answer rather than a real
  /// arrival, and clamping means a bad number cannot become a permanent
  /// scary one on the user's screen.
  static const int countCap = 99;

  final MailboxState state;
  final String? localPart;
  final String? aliasDomain;

  /// Highest message already pulled. Sent on every poll so the server
  /// returns only what is new and never learns what was read.
  final String? cursor;

  /// How many messages have ever reached this address.
  ///
  /// The server's own per-mailbox sequence, which it can only raise by
  /// actually accepting a delivery to a 20-character address derived from a
  /// key this device holds. That is what makes it the one arrival fact no
  /// sender writes: a sender chooses every header in a message, but nothing
  /// a sender does can move this number for a mailbox it cannot name.
  final int delivered;

  /// How many of those this device has opened and read.
  ///
  /// Kept apart from [delivered] because the gap is the honest part. Shadow
  /// fetches mail only while a signup or sign-in is in flight, so most of
  /// what arrives is never looked at, and a card that showed only what it
  /// had read would present a quiet screen as an all-clear.
  final int opened;

  /// Whole days since the epoch, UTC, when the mail service last answered.
  ///
  /// Null means never asked — which must not render as "nothing has
  /// arrived", the same distinction the public address screen keeps between
  /// not having looked and having looked and found nothing.
  final int? checkedDay;

  /// What [delivered] read when the user last dismissed the notice.
  ///
  /// A number rather than a list of senders on purpose: anything per-sender
  /// would be an allowlist, an allowlist is a record of who writes to this
  /// person, and that is a correspondent graph sitting in plain storage.
  final int acknowledged;

  /// Arrivals this device has never looked at.
  int get unopened => delivered > opened ? delivered - opened : 0;

  /// Arrivals since the user last dismissed the notice.
  int get unacknowledged =>
      delivered > acknowledged ? delivered - acknowledged : 0;

  bool get isRegistered => state == MailboxState.registered;

  MailboxRecord copyWith({
    MailboxState? state,
    String? localPart,
    String? aliasDomain,
    String? cursor,
    int? delivered,
    int? opened,
    int? checkedDay,
    int? acknowledged,
  }) {
    return MailboxRecord(
      state: state ?? this.state,
      localPart: localPart ?? this.localPart,
      aliasDomain: aliasDomain ?? this.aliasDomain,
      cursor: cursor ?? this.cursor,
      delivered: delivered ?? this.delivered,
      opened: opened ?? this.opened,
      checkedDay: checkedDay ?? this.checkedDay,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'state': state.name,
        if (localPart != null) 'local_part': localPart,
        if (aliasDomain != null) 'alias_domain': aliasDomain,
        if (cursor != null) 'cursor': cursor,
        if (delivered != 0) 'delivered': delivered,
        if (opened != 0) 'opened': opened,
        if (checkedDay != null) 'checked_day': checkedDay,
        if (acknowledged != 0) 'ack': acknowledged,
      };

  factory MailboxRecord.fromJson(Map<String, dynamic> json) {
    return MailboxRecord(
      state: MailboxState.values.firstWhere(
        (s) => s.name == json['state'],
        orElse: () => MailboxState.none,
      ),
      localPart: json['local_part'] as String?,
      aliasDomain: json['alias_domain'] as String?,
      cursor: json['cursor'] as String?,
      // Clamped on the way in as well as the way out: a record can arrive
      // from a backup written by anyone, and a hostile count is otherwise a
      // permanent alarm on somebody else's screen.
      delivered: _count(json['delivered']),
      opened: _count(json['opened']),
      checkedDay: _day(json['checked_day']),
      acknowledged: _count(json['ack']),
    );
  }

  static int _count(Object? value) {
    final raw = value is int ? value : 0;
    if (raw < 0) return 0;
    return raw > countCap ? countCap : raw;
  }

  static int? _day(Object? value) {
    if (value is! int || value < 0) return null;
    // Roughly the year 2243. A day number past this is a broken clock or a
    // tampered backup, and "last checked in 200 years" is worse than silence.
    return value > 100000 ? null : value;
  }
}

/// The private half: this user's state on this site. Never published.
class SiteAccountState {
  const SiteAccountState({
    this.mode = SiteMode.off,
    this.passwordEpoch = 1,
    this.aliasEpoch = 1,
    this.pendingAliasEpoch,
    this.registeredHandle,
    this.mailbox = const MailboxRecord(),
  });

  final SiteMode mode;
  final int passwordEpoch;
  final int aliasEpoch;

  /// Set while an address is being replaced.
  ///
  /// Burning an alias is a two-step affair, because bumping the counter the
  /// moment the user asks would strand them: the record would say epoch 2
  /// while the site still mails epoch 1. During a burn both mailboxes are
  /// registered and receiving; the old one is retired only once the user
  /// confirms the site has been updated.
  final int? pendingAliasEpoch;

  /// The username actually used at signup.
  ///
  /// Rotating [passwordEpoch] also moves the *derived* handle — accepted,
  /// because a third counter would change every username already typed into
  /// a form. Recording what was really used means the UI can show that
  /// rather than a freshly derived stranger.
  final String? registeredHandle;

  final MailboxRecord mailbox;

  bool get isBurning => pendingAliasEpoch != null;

  /// Nothing has ever been written for this site.
  ///
  /// Cannot distinguish "never visited" from "record lost" — and that is the
  /// point of checking it. The two look identical from here, and the second
  /// one fails silently, so both are worth one probe.
  bool get isUnrecorded =>
      mode == SiteMode.off &&
      passwordEpoch == 1 &&
      aliasEpoch == 1 &&
      pendingAliasEpoch == null &&
      registeredHandle == null &&
      mailbox.state == MailboxState.none;

  SiteAccountState copyWith({
    SiteMode? mode,
    int? passwordEpoch,
    int? aliasEpoch,
    int? pendingAliasEpoch,
    bool clearPendingAliasEpoch = false,
    String? registeredHandle,
    MailboxRecord? mailbox,
  }) {
    return SiteAccountState(
      mode: mode ?? this.mode,
      passwordEpoch: passwordEpoch ?? this.passwordEpoch,
      aliasEpoch: aliasEpoch ?? this.aliasEpoch,
      pendingAliasEpoch:
          clearPendingAliasEpoch ? null : (pendingAliasEpoch ?? this.pendingAliasEpoch),
      registeredHandle: registeredHandle ?? this.registeredHandle,
      mailbox: mailbox ?? this.mailbox,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mode': mode.name,
        'password_epoch': passwordEpoch,
        'alias_epoch': aliasEpoch,
        if (pendingAliasEpoch != null) 'pending_alias_epoch': pendingAliasEpoch,
        if (registeredHandle != null) 'registered_handle': registeredHandle,
        'mailbox': mailbox.toJson(),
      };

  factory SiteAccountState.fromJson(Map<String, dynamic> json) {
    final raw = json['mailbox'];
    return SiteAccountState(
      mode: SiteMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => SiteMode.off,
      ),
      passwordEpoch: _atLeastOne(json['password_epoch']),
      aliasEpoch: _atLeastOne(json['alias_epoch']),
      pendingAliasEpoch: json['pending_alias_epoch'] is int
          ? json['pending_alias_epoch'] as int
          : null,
      registeredHandle: json['registered_handle'] as String?,
      mailbox: raw is Map
          ? MailboxRecord.fromJson(Map<String, dynamic>.from(raw))
          : const MailboxRecord(),
    );
  }

  /// An epoch below 1 is not a smaller number, it is a derivation that throws.
  static int _atLeastOne(Object? value) {
    if (value is int && value >= 1) return value;
    return 1;
  }
}

/// Everything Shadow remembers about one site.
///
/// The "adapter" this codebase has been referring to since the beginning,
/// finally as an artifact rather than an intention. Split into a public
/// [policy] and a private [account] from day one, so that publishing the
/// public half later is a field move rather than a schema rewrite.
class SiteAdapterRecord {
  const SiteAdapterRecord({
    required this.domain,
    this.accountIndex = 0,
    this.policy = const SitePolicy(),
    this.account = const SiteAccountState(),
    this.source = AdapterSource.local,
  });

  /// Schema of the record itself, not of the store.
  ///
  /// The store key carries `_v1` too, but that only says "these are
  /// adapters". This says how to read *one*, which is what lets a record
  /// written by a newer client — eventually, one fetched from chain — be
  /// skipped instead of misread.
  static const int schema = 1;

  final String domain;
  final int accountIndex;
  final SitePolicy policy;
  final SiteAccountState account;
  final AdapterSource source;

  /// `(domain, accountIndex)` is the primary key. Two accounts on one site
  /// are two records, not one record with a counter — everything about them
  /// forks, correctly, because they are different accounts.
  String get id => '$domain#$accountIndex';

  SiteAdapterRecord copyWith({
    SitePolicy? policy,
    SiteAccountState? account,
    AdapterSource? source,
  }) {
    return SiteAdapterRecord(
      domain: domain,
      accountIndex: accountIndex,
      policy: policy ?? this.policy,
      account: account ?? this.account,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema': schema,
        'domain': domain,
        'account_index': accountIndex,
        'source': source.name,
        'policy': policy.toJson(),
        'account': account.toJson(),
      };

  /// Total by construction: never throws, whatever it is handed.
  ///
  /// [LocalStore.readAll] turns a `FormatException` into an empty list, and
  /// its doc explains why that is right for bookmarks — losing them costs
  /// nothing, because using the app rebuilds them. That reasoning does not
  /// carry here. This record holds rotation counters, and returning an empty
  /// list would silently reset every one of them, so the client would
  /// re-derive epoch-1 credentials for sites where the user has already
  /// rotated: wrong password, wrong address, no error.
  ///
  /// So every field defaults rather than throwing, and one malformed record
  /// costs its own fields rather than the whole list.
  factory SiteAdapterRecord.fromJson(Map<String, dynamic> json) {
    final policy = json['policy'];
    final account = json['account'];
    return SiteAdapterRecord(
      domain: json['domain'] as String? ?? '',
      accountIndex:
          json['account_index'] is int ? json['account_index'] as int : 0,
      source: AdapterSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => AdapterSource.local,
      ),
      policy: policy is Map
          ? SitePolicy.fromJson(Map<String, dynamic>.from(policy))
          : const SitePolicy(),
      account: account is Map
          ? SiteAccountState.fromJson(Map<String, dynamic>.from(account))
          : const SiteAccountState(),
    );
  }
}

/// Where a record came from, and therefore which one wins.
///
/// Resolution order is local override, then chain, then the built-in default.
/// Only [local] exists today; [chain] is here so that adding it later does
/// not mean rewriting every record already on a device.
enum AdapterSource { local, chain }
