enum TxStatus { pending, confirmed, failed }

enum TxType { send, receive, swap, buy, deploy, register, renew, unknown }

class ShadowTransaction {
  final String signature;
  final TxType type;
  final TxStatus status;
  final double amount;
  final String symbol;
  final String? counterparty;
  final String? memo;
  final DateTime timestamp;
  final double? feeSol;

  const ShadowTransaction({
    required this.signature,
    required this.type,
    required this.status,
    required this.amount,
    required this.symbol,
    this.counterparty,
    this.memo,
    required this.timestamp,
    this.feeSol,
  });

  factory ShadowTransaction.fromJson(Map<String, dynamic> json) =>
      ShadowTransaction(
        signature: json['signature'] ?? '',
        type: TxType.values.firstWhere(
          (e) => e.name == (json['type']?.toString() ?? ''),
          orElse: () => TxType.unknown,
        ),
        status: TxStatus.values.firstWhere(
          (e) => e.name == (json['status']?.toString() ?? ''),
          orElse: () => TxStatus.pending,
        ),
        amount: (json['amount'] ?? 0).toDouble(),
        symbol: json['symbol'] ?? 'SOL',
        counterparty: json['counterparty'],
        memo: json['memo'],
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        feeSol: (json['fee_sol'] as num?)?.toDouble(),
      );
}
