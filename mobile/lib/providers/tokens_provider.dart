import 'package:flutter/foundation.dart';

import '../models/nft.dart';
import '../models/token_balance.dart';
import '../services/portfolio_service.dart';
import '../services/tokens_service.dart';

/// Holdings for the connected wallet, read from Solana.
///
/// Takes the RPC URL rather than assuming one, so the network setting the user
/// picks actually governs where this reads from. Previously the setting
/// existed and nothing consulted it.
class TokensProvider with ChangeNotifier {
  TokensProvider({required String rpcUrl}) : _rpcUrl = rpcUrl;

  String _rpcUrl;

  List<TokenBalance> _tokens = const [];
  List<Nft> _nfts = const [];
  PortfolioSnapshot? _portfolio;
  bool _isLoading = false;
  String? _error;

  List<TokenBalance> get tokens => _tokens;
  List<Nft> get nfts => _nfts;
  PortfolioSnapshot? get portfolio => _portfolio;
  bool get isLoading => _isLoading;

  /// Why the last load failed. Screens must show this rather than an empty
  /// state — an unreachable RPC is not the same as an empty wallet, and the
  /// old code rendered both as "No tokens yet".
  String? get error => _error;

  /// Points subsequent reads at a different cluster.
  void setRpcUrl(String url) {
    if (url == _rpcUrl) return;
    _rpcUrl = url;
    _tokens = const [];
    _nfts = const [];
    _portfolio = null;
    notifyListeners();
  }

  Future<void> load(String wallet) async {
    if (wallet.isEmpty) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tokens = TokensService(rpcUrl: _rpcUrl);
      // Sequential rather than Future.wait: the old version failed all three
      // together, so one bad call wiped balances, NFTs and portfolio alike.
      _tokens = await tokens.balances(wallet);
      _nfts = await tokens.nfts(wallet);
      _portfolio = await PortfolioService(rpcUrl: _rpcUrl).snapshot(wallet);
    } catch (e) {
      _error = 'Could not reach the Solana RPC at $_rpcUrl';
      _tokens = const [];
      _nfts = const [];
      _portfolio = null;
      assert(() {
        debugPrint('Token load failed: $e');
        return true;
      }());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
