import 'package:flutter/foundation.dart';

import '../models/nft.dart';
import '../models/token_balance.dart';
import '../services/portfolio_service.dart';
import '../services/tokens_service.dart';

class TokensProvider with ChangeNotifier {
  final TokensService _service = TokensService();
  final PortfolioService _portfolioService = PortfolioService();

  List<TokenBalance> _tokens = const [];
  List<Nft> _nfts = const [];
  PortfolioSnapshot? _portfolio;
  bool _isLoading = false;

  List<TokenBalance> get tokens => _tokens;
  List<Nft> get nfts => _nfts;
  PortfolioSnapshot? get portfolio => _portfolio;
  bool get isLoading => _isLoading;

  Future<void> load(String wallet) async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.balances(wallet),
        _service.nfts(wallet),
        _portfolioService.snapshot(wallet),
      ]);
      _tokens = results[0] as List<TokenBalance>;
      _nfts = results[1] as List<Nft>;
      _portfolio = results[2] as PortfolioSnapshot;
    } catch (_) {
      _tokens = const [];
      _nfts = const [];
      _portfolio = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
