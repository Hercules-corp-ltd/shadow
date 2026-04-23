import 'api_client.dart';

class PortfolioSnapshot {
  final double solBalance;
  final double solUsd;
  final double tokensUsd;
  final double nftsUsd;
  final double totalUsd;

  const PortfolioSnapshot({
    required this.solBalance,
    required this.solUsd,
    required this.tokensUsd,
    required this.nftsUsd,
    required this.totalUsd,
  });

  factory PortfolioSnapshot.fromJson(Map<String, dynamic> json) =>
      PortfolioSnapshot(
        solBalance: (json['sol_balance'] ?? 0).toDouble(),
        solUsd: (json['sol_usd'] ?? 0).toDouble(),
        tokensUsd: (json['tokens_usd'] ?? 0).toDouble(),
        nftsUsd: (json['nfts_usd'] ?? 0).toDouble(),
        totalUsd: (json['total_usd'] ?? 0).toDouble(),
      );
}

class PortfolioService {
  final ApiClient _api = ApiClient.instance;

  Future<PortfolioSnapshot> snapshot(String wallet) async {
    final res = await _api
        .get<Map<String, dynamic>>('/portfolio', query: {'wallet': wallet});
    return PortfolioSnapshot.fromJson(res.data ?? {});
  }
}
