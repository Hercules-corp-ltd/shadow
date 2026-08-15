import 'package:flutter/foundation.dart';

import '../models/domain.dart';
import '../services/domain_service.dart';

class DomainsProvider with ChangeNotifier {
  final DomainService _service = DomainService();

  List<BlindDomain> _myDomains = const [];
  List<BlindDomain> _searchResults = const [];
  BlindDomain? _active;
  bool _isLoading = false;
  String? _error;

  List<BlindDomain> get myDomains => _myDomains;
  List<BlindDomain> get searchResults => _searchResults;
  BlindDomain? get active => _active;
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

  Future<BlindDomain?> load(String domain) async {
    _active = await _service.get(domain);
    notifyListeners();
    return _active;
  }

  Future<BlindDomain> register({
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
