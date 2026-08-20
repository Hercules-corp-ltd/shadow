import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/domain.dart';
import '../services/domain_service.dart';
import '../services/fetch_outcome.dart';

class DomainsProvider with ChangeNotifier {
  final DomainService _service = DomainService();

  List<ShadowDomain> _myDomains = const [];
  List<ShadowDomain> _searchResults = const [];
  ShadowDomain? _active;
  String? _activeError;
  bool _isLoading = false;
  String? _error;

  List<ShadowDomain> get myDomains => _myDomains;
  List<ShadowDomain> get searchResults => _searchResults;
  ShadowDomain? get active => _active;

  /// Why [active] is null, when it is null because something went wrong.
  String? get activeError => _activeError;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMine(String wallet) async {
    _isLoading = true;
    notifyListeners();
    try {
      _myDomains = await _service.ownerDomains(wallet);
    } catch (e) {
      _error = e.toString();
      _myDomains = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// The last query passed to [search].
  ///
  /// The results screen labels its failure action "Try again"; without this
  /// it had nothing to try, and used to pop the screen instead.
  String get lastQuery => _lastQuery;
  String _lastQuery = '';

  Future<void> search(String query) async {
    _lastQuery = query;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _searchResults = await _service.search(query);
    } catch (e) {
      _searchResults = const [];
      _error = e is DioException
          ? describeDioFailure(e)
          : 'Could not search domains';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads one domain, recording why it failed if it did.
  ///
  /// Callers must check [activeError] before treating a null [_active] as
  /// "still loading" — that conflation is what left the details screen
  /// spinning forever on any error.
  Future<FetchOutcome<ShadowDomain>> load(String domain) async {
    final outcome = await _service.get(domain);
    switch (outcome) {
      case FetchSuccess(value: final d):
        _active = d;
        _activeError = null;
      case FetchNotFound():
        _active = null;
        _activeError = 'No domain registered as "$domain"';
      case FetchUnreachable(reason: final reason):
        _active = null;
        _activeError = reason;
    }
    notifyListeners();
    return outcome;
  }

  Future<ShadowDomain> register({
    required String domain,
    required String programAddress,
    required String ownerPubkey,
    int years = 1,
  }) async {
    final d = await _service.register(
      domain: domain,
      programAddress: programAddress,
      ownerPubkey: ownerPubkey,
      years: years,
    );
    _myDomains = [d, ..._myDomains];
    _active = d;
    notifyListeners();
    return d;
  }

  Future<void> renew(String domain, {int years = 1}) async {
    await _service.renew(domain: domain, years: years);
  }

  Future<void> transfer(String domain, String toPubkey) async {
    await _service.transfer(domain: domain, toPubkey: toPubkey);
    _myDomains = _myDomains.where((d) => d.domain != domain).toList();
    notifyListeners();
  }
}
