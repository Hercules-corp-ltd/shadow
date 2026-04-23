class Bookmark {
  final String id;
  final String domain;
  final String? programAddress;
  final String? title;
  final String? description;
  final String? folder;
  final List<String> tags;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.domain,
    this.programAddress,
    this.title,
    this.description,
    this.folder,
    this.tags = const [],
    required this.createdAt,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        domain: json['domain'] ?? '',
        programAddress: json['program_address'],
        title: json['title'],
        description: json['description'],
        folder: json['folder'],
        tags: List<String>.from(json['tags'] ?? const []),
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '') ??
                DateTime.now(),
      );
}
