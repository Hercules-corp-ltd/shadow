class BlindExtension {
  final String id;
  final String name;
  final String author;
  final String version;
  final String description;
  final String? iconUrl;
  final bool enabled;
  final List<String> permissions;
  final DateTime installedAt;

  const BlindExtension({
    required this.id,
    required this.name,
    required this.author,
    required this.version,
    required this.description,
    this.iconUrl,
    this.enabled = true,
    this.permissions = const [],
    required this.installedAt,
  });

  factory BlindExtension.fromJson(Map<String, dynamic> json) =>
      BlindExtension(
        id: (json['id'] ?? '').toString(),
        name: json['name'] ?? '',
        author: json['author'] ?? 'Unknown',
        version: json['version'] ?? '1.0.0',
        description: json['description'] ?? '',
        iconUrl: json['icon_url'],
        enabled: json['enabled'] ?? true,
        permissions: List<String>.from(json['permissions'] ?? const []),
        installedAt:
            DateTime.tryParse(json['installed_at']?.toString() ?? '') ??
                DateTime.now(),
      );

  BlindExtension copyWith({bool? enabled}) => BlindExtension(
        id: id,
        name: name,
        author: author,
        version: version,
        description: description,
        iconUrl: iconUrl,
        enabled: enabled ?? this.enabled,
        permissions: permissions,
        installedAt: installedAt,
      );
}
