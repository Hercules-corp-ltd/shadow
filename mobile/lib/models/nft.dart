class Nft {
  final String mintAddress;
  final String name;
  final String? symbol;
  final String? imageUrl;
  final String? description;
  final String? collectionAddress;
  final String? collectionName;
  final Map<String, dynamic> attributes;

  const Nft({
    required this.mintAddress,
    required this.name,
    this.symbol,
    this.imageUrl,
    this.description,
    this.collectionAddress,
    this.collectionName,
    this.attributes = const {},
  });

  factory Nft.fromJson(Map<String, dynamic> json) => Nft(
        mintAddress: json['mint_address'] ?? json['mint'] ?? '',
        name: json['name'] ?? 'Unnamed',
        symbol: json['symbol'],
        imageUrl: json['image_url'] ?? json['image'],
        description: json['description'],
        collectionAddress: json['collection_address'],
        collectionName: json['collection_name'],
        attributes:
            Map<String, dynamic>.from(json['attributes'] ?? const {}),
      );
}
