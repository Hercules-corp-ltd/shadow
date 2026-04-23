class SiteToken {
  final String mintAddress;
  final String name;
  final String symbol;
  final int decimals;
  final double totalSupply;
  final String? imageUrl;
  final String? domain;
  final double currentPrice;
  final double priceChange24h;
  final int holderCount;

  const SiteToken({
    required this.mintAddress,
    required this.name,
    required this.symbol,
    this.decimals = 9,
    this.totalSupply = 0,
    this.imageUrl,
    this.domain,
    this.currentPrice = 0,
    this.priceChange24h = 0,
    this.holderCount = 0,
  });

  factory SiteToken.fromJson(Map<String, dynamic> json) => SiteToken(
        mintAddress: json['mint_address'] ?? '',
        name: json['name'] ?? '',
        symbol: json['symbol'] ?? '',
        decimals: (json['decimals'] ?? 9) as int,
        totalSupply: (json['total_supply'] ?? 0).toDouble(),
        imageUrl: json['image_url'],
        domain: json['domain'],
        currentPrice: (json['current_price'] ?? 0).toDouble(),
        priceChange24h: (json['price_change_24h'] ?? 0).toDouble(),
        holderCount: (json['holder_count'] ?? 0) as int,
      );
}
