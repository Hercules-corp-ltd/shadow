import 'tokens_service.dart';

/// What a wallet holds.
///
/// Deliberately has no USD fields. The previous version carried solUsd,
/// tokensUsd, nftsUsd and totalUsd, all filled from a backend that made the
/// numbers up — `plutus.rs` cached a hardcoded SOL price of 100.0 as though it
/// had been fetched from somewhere. Showing a wrong balance in a wallet is
/// worse than showing none, so this reports what the chain actually says and
/// leaves valuation to a future decision about oracles.
class PortfolioSnapshot {
  const PortfolioSnapshot({
    required this.solBalance,
    required this.tokenCount,
  });

  /// Native SOL, in SOL rather than lamports.
  final double solBalance;

  /// Number of distinct SPL mints held with a non-zero balance.
  final int tokenCount;

  static const PortfolioSnapshot empty =
      PortfolioSnapshot(solBalance: 0, tokenCount: 0);
}

/// Reads holdings from Solana rather than from a backend that never had them.
class PortfolioService {
  PortfolioService({required this.rpcUrl});

  final String rpcUrl;

  Future<PortfolioSnapshot> snapshot(String wallet) async {
    final tokens = TokensService(rpcUrl: rpcUrl);
    final sol = await tokens.solBalance(wallet);
    final balances = await tokens.balances(wallet);
    return PortfolioSnapshot(
      solBalance: sol,
      tokenCount: balances.length,
    );
  }
}
