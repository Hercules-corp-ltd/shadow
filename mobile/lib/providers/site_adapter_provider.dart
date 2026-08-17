import 'package:flutter/foundation.dart';

import '../models/site_adapter_record.dart';
import '../services/site_adapter_service.dart';

/// Per-site adapter records, for the widget tree.
///
/// A thin pass-through rather than a cache. The store is small, reads are
/// rare — once per fill — and holding a copy in memory would mean two places
/// that can disagree about which epoch a site is on. Getting that wrong
/// derives the wrong password.
class SiteAdapterProvider with ChangeNotifier {
  SiteAdapterProvider({SiteAdapterService? service})
      : _service = service ?? const SiteAdapterService();

  final SiteAdapterService _service;

  int _revision = 0;

  /// Bumped on every write.
  ///
  /// Reads are futures, so a list rebuilt by `notifyListeners` alone would
  /// re-issue the same future and show the same stale answer. Keying the
  /// builder on this makes a change elsewhere actually re-read.
  int get revision => _revision;

  void _changed() {
    _revision++;
    notifyListeners();
  }

  Future<SiteAdapterRecord> resolve(String host, {int accountIndex = 0}) =>
      _service.resolve(host, accountIndex: accountIndex);

  Future<List<SiteAdapterRecord>> configured() => _service.configured();

  Future<void> setMode(
    String domain,
    SiteMode mode, {
    int accountIndex = 0,
  }) async {
    await _service.setMode(domain, mode, accountIndex: accountIndex);
    _changed();
  }

  Future<void> recordSignup(
    String domain, {
    required String handleUsed,
    int accountIndex = 0,
  }) async {
    await _service.recordSignup(
      domain,
      handleUsed: handleUsed,
      accountIndex: accountIndex,
    );
    _changed();
  }

  /// Writes back an alias epoch recovered from the mail server.
  Future<SiteAdapterRecord> adoptRecoveredAliasEpoch(
    String domain, {
    required int aliasEpoch,
    int accountIndex = 0,
  }) async {
    final record = await _service.adoptRecoveredAliasEpoch(
      domain,
      aliasEpoch: aliasEpoch,
      accountIndex: accountIndex,
    );
    _changed();
    return record;
  }

  /// After a site forces a reset. Leaves the address alone.
  Future<void> rotatePassword(String domain, {int accountIndex = 0}) async {
    await _service.bumpPasswordEpoch(domain, accountIndex: accountIndex);
    _changed();
  }

  /// Step one of replacing a leaked address. Both mailboxes stay live until
  /// the user confirms the site has been updated.
  Future<void> beginAliasBurn(String domain, {int accountIndex = 0}) async {
    await _service.beginAliasBurn(domain, accountIndex: accountIndex);
    _changed();
  }

  Future<void> commitAliasBurn(String domain, {int accountIndex = 0}) async {
    await _service.commitAliasBurn(domain, accountIndex: accountIndex);
    _changed();
  }

  Future<void> abandonAliasBurn(String domain, {int accountIndex = 0}) async {
    await _service.abandonAliasBurn(domain, accountIndex: accountIndex);
    _changed();
  }

  /// Writes a record wholesale. Used by a restore.
  Future<void> upsert(SiteAdapterRecord record) async {
    await _service.upsert(record);
    _changed();
  }

  Future<void> forget(String domain, {int accountIndex = 0}) async {
    await _service.forget(domain, accountIndex: accountIndex);
    _changed();
  }
}
