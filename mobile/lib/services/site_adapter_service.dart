import '../models/site_adapter_record.dart';
import 'local_store.dart';

/// Per-site adapter records, on the device.
///
/// Until now the rotation counters and the password policy existed only as
/// method parameters with defaults, and every caller passed the defaults —
/// so a site that forced a password reset had nowhere to record that it had.
///
/// ## This is a cache with no backup, and that is a real limitation
///
/// SharedPreferences is app-private but not sacred: Settings → Storage
/// clears it, a reinstall clears it, an OS restore may not carry it. Losing
/// it loses the site→epoch map, and there is deliberately no cross-mailbox
/// identity on the server to enumerate from — that absence is the privacy
/// property, so it cannot be traded away for convenience here.
///
/// The recovery path is a signed probe: re-derive the candidate mailbox for
/// epoch 1..N and ask the server which of those local parts exist, proving
/// ownership with the key just re-derived. That reveals nothing to an
/// eavesdropper and nothing to the server it could not already compute.
/// It needs the server, so it lands with the server — but the record shape
/// is designed for it now, because retrofitting it after users have lost
/// state helps nobody.
class SiteAdapterService {
  const SiteAdapterService();

  static const LocalStore<SiteAdapterRecord> _store =
      LocalStore<SiteAdapterRecord>(
    key: 'shadow_site_adapters_v1',
    encode: _encode,
    decode: SiteAdapterRecord.fromJson,
  );

  static Map<String, dynamic> _encode(SiteAdapterRecord r) => r.toJson();

  /// Never null.
  ///
  /// A site with no record is a site in its default state, not an error, so
  /// callers get a fully-populated record and never branch on absence.
  Future<SiteAdapterRecord> resolve(String domain, {int accountIndex = 0}) async {
    final all = await _store.readAll();
    for (final record in all) {
      if (record.domain == domain && record.accountIndex == accountIndex) {
        return record;
      }
    }
    return SiteAdapterRecord(domain: domain, accountIndex: accountIndex);
  }

  Future<List<SiteAdapterRecord>> list() => _store.readAll();

  /// Sites the user has actually chosen a behaviour for.
  Future<List<SiteAdapterRecord>> configured() async {
    final all = await _store.readAll();
    return all.where((r) => r.account.mode != SiteMode.off).toList();
  }

  Future<SiteAdapterRecord> upsert(SiteAdapterRecord record) async {
    final all = await _store.readAll();
    all.removeWhere(
      (r) => r.domain == record.domain && r.accountIndex == record.accountIndex,
    );
    all.add(record);
    await _store.writeAll(all);
    return record;
  }

  Future<SiteAdapterRecord> setMode(
    String domain,
    SiteMode mode, {
    int accountIndex = 0,
  }) async {
    final record = await resolve(domain, accountIndex: accountIndex);
    return upsert(
      record.copyWith(account: record.account.copyWith(mode: mode)),
    );
  }

  /// After a breach or a forced reset. Leaves the address alone.
  Future<SiteAdapterRecord> bumpPasswordEpoch(
    String domain, {
    int accountIndex = 0,
  }) async {
    final record = await resolve(domain, accountIndex: accountIndex);
    return upsert(record.copyWith(
      account: record.account.copyWith(
        passwordEpoch: record.account.passwordEpoch + 1,
      ),
    ));
  }

  /// Writes back an alias epoch worked out by probing the mail server.
  ///
  /// Marks the mailbox registered, because that is what the probe proved —
  /// the address exists and answers to this key. Not `upsert` with a whole
  /// record, so that a recovery can never quietly overwrite state that
  /// survived.
  Future<SiteAdapterRecord> adoptRecoveredAliasEpoch(
    String domain, {
    required int aliasEpoch,
    int accountIndex = 0,
  }) async {
    final record = await resolve(domain, accountIndex: accountIndex);
    if (aliasEpoch <= record.account.aliasEpoch &&
        !record.account.isUnrecorded) {
      return record;
    }
    return upsert(record.copyWith(
      account: record.account.copyWith(
        aliasEpoch: aliasEpoch,
        mailbox: record.account.mailbox.copyWith(
          state: MailboxState.registered,
        ),
      ),
    ));
  }

  /// Step one of replacing a leaked address.
  ///
  /// Records the *next* epoch without adopting it, so both mailboxes are
  /// live while the user goes and changes the address at the site. Adopting
  /// it here instead would strand them: the record would say epoch 2 while
  /// the site still mails epoch 1.
  Future<SiteAdapterRecord> beginAliasBurn(
    String domain, {
    int accountIndex = 0,
  }) async {
    final record = await resolve(domain, accountIndex: accountIndex);
    if (record.account.isBurning) return record;
    return upsert(record.copyWith(
      account: record.account.copyWith(
        pendingAliasEpoch: record.account.aliasEpoch + 1,
      ),
    ));
  }

  /// Step two: the user confirms the site now has the new address.
  Future<SiteAdapterRecord> commitAliasBurn(
    String domain, {
    int accountIndex = 0,
  }) async {
    final record = await resolve(domain, accountIndex: accountIndex);
    final pending = record.account.pendingAliasEpoch;
    if (pending == null) return record;
    return upsert(record.copyWith(
      account: record.account.copyWith(
        aliasEpoch: pending,
        clearPendingAliasEpoch: true,
        // The cursor has to go with the address. A new epoch is a different
        // local part, and the server starts its sequence at zero for it — so
        // carrying the old cursor over made the new address's first messages
        // invisible, which is exactly the mail that matters after a burn.
        mailbox: const MailboxRecord(state: MailboxState.none),
      ),
    ));
  }

  /// The user backed out. The old address stays live.
  Future<SiteAdapterRecord> abandonAliasBurn(
    String domain, {
    int accountIndex = 0,
  }) async {
    final record = await resolve(domain, accountIndex: accountIndex);
    if (!record.account.isBurning) return record;
    return upsert(record.copyWith(
      account: record.account.copyWith(clearPendingAliasEpoch: true),
    ));
  }

  Future<SiteAdapterRecord> markMailbox(
    String domain, {
    int accountIndex = 0,
    required MailboxState state,
    String? localPart,
    String? aliasDomain,
  }) async {
    final record = await resolve(domain, accountIndex: accountIndex);
    return upsert(record.copyWith(
      account: record.account.copyWith(
        mailbox: record.account.mailbox.copyWith(
          state: state,
          localPart: localPart,
          aliasDomain: aliasDomain,
        ),
      ),
    ));
  }

  /// Remembers the username the user actually signed up with.
  Future<SiteAdapterRecord> recordSignup(
    String domain, {
    int accountIndex = 0,
    required String handleUsed,
  }) async {
    final record = await resolve(domain, accountIndex: accountIndex);
    return upsert(record.copyWith(
      account: record.account.copyWith(registeredHandle: handleUsed),
    ));
  }

  Future<void> forget(String domain, {int accountIndex = 0}) async {
    final all = await _store.readAll();
    all.removeWhere(
      (r) => r.domain == domain && r.accountIndex == accountIndex,
    );
    await _store.writeAll(all);
  }

  Future<void> clearAll() => _store.clear();
}
