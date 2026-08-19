class Site {
  final String domain;
  final String programAddress;
  final String ownerPubkey;
  final String contentCid;
  final String? title;
  final String? description;
  final String? thumbnailCid;
  final String deployVersion;

  /// Null when the server did not say.
  ///
  /// This used to fall back to `DateTime.now()`, so a response with the field
  /// missing produced a site that claimed it had been deployed this second,
  /// and the resolve screen printed that as fact next to the real content
  /// address. An absent date is not today's date.
  final DateTime? lastDeployedAt;
  final int visitCount;

  const Site({
    required this.domain,
    required this.programAddress,
    required this.ownerPubkey,
    required this.contentCid,
    this.title,
    this.description,
    this.thumbnailCid,
    this.deployVersion = 'v1',
    this.lastDeployedAt,
    this.visitCount = 0,
  });

  factory Site.fromJson(Map<String, dynamic> json) => Site(
        domain: json['domain'] ?? '',
        programAddress: json['program_address'] ?? '',
        ownerPubkey: json['owner_pubkey'] ?? '',
        contentCid: json['content_cid'] ?? '',
        title: json['title'],
        description: json['description'],
        thumbnailCid: json['thumbnail_cid'],
        deployVersion: json['deploy_version'] ?? 'v1',
        lastDeployedAt:
            DateTime.tryParse(json['last_deployed_at']?.toString() ?? ''),
        visitCount: (json['visit_count'] ?? 0) as int,
      );
}
