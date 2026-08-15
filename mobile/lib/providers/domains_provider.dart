import 'package:flutter/foundation.dart';

import '../models/domain.dart';
import '../services/domain_service.dart';

class DomainsProvider with ChangeNotifier {
  final DomainService _service = DomainService();

  List<ShadowDomain> _myDomains = const [];
  List<ShadowDomain> _searchResults = const [];
  ShadowDomain? _active;
  bool _isLoading = false;
  String? _error;

  List<ShadowDomain> get myDomains => _myDomains;
  List<ShadowDomain> get searchResults => _searchResults;
  ShadowDomain? get active => _active;
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

  Future<void> search(String query) async {
    _isLoading = true;
    notifyListeners();
    try {
      _searchResults = await _service.search(query);
    } catch (_) {
      _searchResults = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ShadowDomain?> load(String domain) async {
    _active = await _service.get(domain);
    notifyListeners();
    return _active;
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
