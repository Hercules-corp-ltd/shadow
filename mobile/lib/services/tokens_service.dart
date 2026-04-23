import '../models/nft.dart';
import '../models/token_balance.dart';
import 'api_client.dart';

class TokensService {
  final ApiClient _api = ApiClient.instance;

  Future<List<TokenBalance>> balances(String wallet) async {
    final res =
        await _api.get<List<dynamic>>('/tokens/balances', query: {'wallet': wallet});
    return (res.data ?? [])
        .map((e) => TokenBalance.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Nft>> nfts(String wallet) async {
    final res = await _api.get<List<dynamic>>('/nfts', query: {'wallet': wallet});
    return (res.data ?? [])
        .map((e) => Nft.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> createTransfer({
    required String fromWallet,
    required String toWallet,
    required String mintAddress,
    required double amount,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/tokens/transfer',
      data: {
        'from': fromWallet,
        'to': toWallet,
        'mint': mintAddress,
        'amount': amount,
      },
    );
    return res.data ?? const {};
  }
}
