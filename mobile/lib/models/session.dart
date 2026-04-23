class BrowsingSession {
  final String id;
  final String walletAddress;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int tabCount;
  final bool isActive;

  const BrowsingSession({
    required this.id,
    required this.walletAddress,
    required this.startedAt,
    this.endedAt,
    this.tabCount = 1,
    this.isActive = true,
  });

  factory BrowsingSession.fromJson(Map<String, dynamic> json) =>
      BrowsingSession(
        id: (json['id'] ?? json['session_id'] ?? '').toString(),
        walletAddress: json['wallet_address'] ?? '',
        startedAt: DateTime.tryParse(json['started_at']?.toString() ?? '') ??
            DateTime.now(),
        endedAt: json['ended_at'] == null
            ? null
            : DateTime.tryParse(json['ended_at'].toString()),
        tabCount: (json['tab_count'] ?? 1) as int,
        isActive: json['is_active'] ?? false,
      );
}
