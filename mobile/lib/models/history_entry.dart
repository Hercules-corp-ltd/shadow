class HistoryEntry {
  final String id;
  final String domain;
  final String? programAddress;
  final String? title;
  final String? faviconUrl;
  final DateTime visitedAt;
  final int timeSpentSeconds;

  const HistoryEntry({
    required this.id,
    required this.domain,
    this.programAddress,
    this.title,
    this.faviconUrl,
    required this.visitedAt,
    this.timeSpentSeconds = 0,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      domain: json['domain'] ?? '',
      programAddress: json['program_address'],
      title: json['title'],
      faviconUrl: json['favicon_url'],
      visitedAt: DateTime.tryParse(json['visited_at']?.toString() ?? '') ??
          DateTime.now(),
      timeSpentSeconds: (json['time_spent_seconds'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'domain': domain,
        'program_address': programAddress,
        'title': title,
        'favicon_url': faviconUrl,
        'visited_at': visitedAt.toIso8601String(),
        'time_spent_seconds': timeSpentSeconds,
      };
}
