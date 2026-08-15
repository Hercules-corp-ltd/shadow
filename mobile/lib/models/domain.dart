class BlindDomain {
  final String domain;
  final String programAddress;
  final String ownerPubkey;
  final bool isVerified;
  final int? trustScore;
  final DateTime registeredAt;
  final DateTime? expiresAt;
  final Map<String, dynamic> metadata;
  final List<DnsRecord> dnsRecords;

  const BlindDomain({
    required this.domain,
    required this.programAddress,
    required this.ownerPubkey,
    this.isVerified = false,
    this.trustScore,
    required this.registeredAt,
    this.expiresAt,
    this.metadata = const {},
    this.dnsRecords = const [],
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory BlindDomain.fromJson(Map<String, dynamic> json) => BlindDomain(
        domain: json['domain'] ?? '',
        programAddress: json['program_address'] ?? '',
        ownerPubkey: json['owner_pubkey'] ?? '',
        isVerified: json['is_verified'] ?? false,
        trustScore: json['trust_score'] as int?,
        registeredAt:
            DateTime.tryParse(json['registered_at']?.toString() ?? '') ??
                DateTime.now(),
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.tryParse(json['expires_at'].toString()),
        metadata: Map<String, dynamic>.from(json['metadata'] ?? const {}),
        dnsRecords: (json['dns_records'] as List? ?? const [])
            .map((e) => DnsRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class DnsRecord {
  final String id;
  final String type; // A, AAAA, CNAME, TXT, MX
  final String name;
  final String value;
  final int ttl;

  const DnsRecord({
    required this.id,
    required this.type,
    required this.name,
    required this.value,
    this.ttl = 3600,
  });

  factory DnsRecord.fromJson(Map<String, dynamic> json) => DnsRecord(
        id: (json['id'] ?? '').toString(),
        type: json['type'] ?? 'A',
        name: json['name'] ?? '@',
        value: json['value'] ?? '',
        ttl: (json['ttl'] ?? 3600) as int,
      );
}
