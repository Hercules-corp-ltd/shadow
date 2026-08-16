// Hidden: the solana package exports its own TokenBalance, which is a
// different thing from ours (a balance snapshot inside a transaction meta,
// not a wallet holding).
import 'package:solana/dto.dart' hide TokenBalance;
import 'package:solana/solana.dart';

import '../models/nft.dart';
import '../models/token_balance.dart';

/// Token holdings, read straight from Solana.
///
/// This used to call `/tokens/balances`, `/nfts` and `/tokens/transfer` on our
/// own backend. None of the three existed — but even had they, proxying chain
/// data through a private server is the wrong shape for this product. The data
/// is public, the chain is the authority, and a middleman that learns which
/// wallet is asking about what is precisely what a privacy browser exists to
/// avoid.
///
/// ## Why there are no dollar values
///
/// RPC returns balances, not prices. There is no honest way to derive a USD
/// figure from this data, so [TokenBalance.usdValue] stays zero and the UI
/// shows amounts rather than invented valuations. The old backend did invent
/// them: `plutus.rs` cached a hardcoded SOL price of 100.0 as though it had
/// been fetched. Real pricing needs an oracle, and that is a separate decision
/// carrying its own privacy cost — asking a price API about your holdings
/// tells it what you hold.
class TokensService {
  TokensService({required this.rpcUrl});

  /// Comes from `ShadowSettings.rpcUrl`, a setting that until now nothing read.
  final String rpcUrl;

  RpcClient get _rpc => RpcClient(rpcUrl);

  /// Native SOL balance, in SOL.
  Future<double> solBalance(String wallet) async {
    final result = await _rpc.getBalance(wallet);
    return result.value / lamportsPerSol;
  }

  /// Every SPL token account the wallet holds with a non-zero balance.
  ///
  /// Queries both the classic Token program and Token-2022, because a wallet
  /// holding only Token-2022 assets would otherwise look empty.
  ///
  /// Symbol and name are left as the mint address on purpose. Human names live
  /// in Metaplex metadata accounts, not in the token account, and fetching
  /// them is a further round of lookups per mint. Showing the mint is honest;
  /// inventing "UNKNOWN" and caching it — which the old backend did — is not.
  Future<List<TokenBalance>> balances(String wallet) async {
    final out = <TokenBalance>[];

    for (final programId in const [
      TokenProgram.programId,
      Token2022Program.programId,
    ]) {
      final accounts = await _rpc.getTokenAccountsByOwner(
        wallet,
        TokenAccountsFilter.byProgramId(programId),
        encoding: Encoding.jsonParsed,
      );

      for (final account in accounts.value) {
        final info = _tokenAccountInfo(account);
        if (info == null) continue;

        final amount = info.tokenAmount;
        final ui = double.tryParse(amount.uiAmountString ?? '') ?? 0;
        if (ui == 0) continue; // closed or empty accounts are noise

        out.add(TokenBalance(
          mintAddress: info.mint,
          symbol: _shortMint(info.mint),
          name: info.mint,
          decimals: amount.decimals,
          balance: ui,
        ));
      }
    }

    out.sort((a, b) => b.balance.compareTo(a.balance));
    return out;
  }

  /// NFTs are not read yet.
  ///
  /// Doing it properly means fetching Metaplex metadata for every zero-decimal,
  /// supply-one mint a wallet holds — a real feature, not a line of code. This
  /// returns empty as a placeholder, and the screen must say "not implemented"
  /// rather than "you have no NFTs". Those are different claims.
  Future<List<Nft>> nfts(String wallet) async => const [];

  /// Narrows a jsonParsed account to SPL token-account info, or null.
  static SplTokenAccountDataInfo? _tokenAccountInfo(ProgramAccount account) {
    final data = account.account.data;

    final parsed = switch (data) {
      ParsedSplTokenProgramAccountData(:final parsed) => parsed,
      ParsedSplToken2022ProgramAccountData(:final parsed) => parsed,
      _ => null,
    };

    // A mint account can also come back from this filter; only holdings count.
    return parsed is TokenAccountData ? parsed.info : null;
  }

  static String _shortMint(String mint) => mint.length <= 8
      ? mint
      : '${mint.substring(0, 4)}...${mint.substring(mint.length - 4)}';
}
