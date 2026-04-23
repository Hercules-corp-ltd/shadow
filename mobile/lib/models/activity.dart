enum ActivityKind { deploy, purchase, domainRegister, transfer, siteVisit, info }

class ActivityEntry {
  final String id;
  final ActivityKind kind;
  final String title;
  final String? subtitle;
  final DateTime timestamp;
  final String? status;
  final String? relatedDomain;
  final String? relatedTx;

  const ActivityEntry({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    required this.timestamp,
    this.status,
    this.relatedDomain,
    this.relatedTx,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
        id: (json['id'] ?? '').toString(),
        kind: ActivityKind.values.firstWhere(
          (k) => k.name == (json['kind']?.toString() ?? ''),
          orElse: () => ActivityKind.info,
        ),
        title: json['title'] ?? '',
        subtitle: json['subtitle'],
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        status: json['status'],
        relatedDomain: json['related_domain'],
        relatedTx: json['related_tx'],
      );
}
