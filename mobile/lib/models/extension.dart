class ShadowExtension {
  final String id;
  final String name;
  final String author;
  final String version;
  final String description;
  final String? iconUrl;
  final bool enabled;
  final List<String> permissions;
  final DateTime installedAt;

  const ShadowExtension({
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

  factory ShadowExtension.fromJson(Map<String, dynamic> json) =>
      ShadowExtension(
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

  ShadowExtension copyWith({bool? enabled}) => ShadowExtension(
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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'author': author,
        'version': version,
        'description': description,
        'icon_url': iconUrl,
        'enabled': enabled,
        'permissions': permissions,
        'installed_at': installedAt.toIso8601String(),
      };
}
