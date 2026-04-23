class TokenBalance {
  final String mintAddress;
  final String symbol;
  final String name;
  final int decimals;
  final String? imageUrl;
  final double balance;
  final double usdValue;

  const TokenBalance({
    required this.mintAddress,
    required this.symbol,
    required this.name,
    this.decimals = 9,
    this.imageUrl,
    this.balance = 0,
    this.usdValue = 0,
  });

  factory TokenBalance.fromJson(Map<String, dynamic> json) => TokenBalance(
        mintAddress: json['mint_address'] ?? json['mint'] ?? '',
        symbol: json['symbol'] ?? '',
        name: json['name'] ?? json['symbol'] ?? '',
        decimals: (json['decimals'] ?? 9) as int,
        imageUrl: json['image_url'] ?? json['logo_uri'],
        balance: (json['balance'] ?? 0).toDouble(),
        usdValue: (json['usd_value'] ?? 0).toDouble(),
      );
}
