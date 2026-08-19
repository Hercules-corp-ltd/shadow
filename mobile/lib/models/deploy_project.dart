enum ProjectFramework { static_, react, vue, angular, next, nuxt, svelte }

enum DeployStatus { idle, uploading, uploaded, deploying, deployed, failed }

class DeployProject {
  final String id;
  final String name;
  final ProjectFramework framework;
  final String? domain;
  final List<DeployFile> files;
  final DeployStatus status;
  final double uploadProgress;
  final String? contentCid;
  final String? programAddress;
  final String? errorMessage;
  final DateTime createdAt;

  const DeployProject({
    required this.id,
    required this.name,
    this.framework = ProjectFramework.static_,
    this.domain,
    this.files = const [],
    this.status = DeployStatus.idle,
    this.uploadProgress = 0,
    this.contentCid,
    this.programAddress,
    this.errorMessage,
    required this.createdAt,
  });

  /// Note the [clearDomain] flag.
  ///
  /// `domain` is nullable *and* meaningful when null — "this deployment has
  /// no name" is a real state the config screen offers on purpose. With the
  /// usual `domain ?? this.domain` idiom there is no way to express it:
  /// passing null means "leave it alone", so a user who typed a domain, went
  /// forward, came back and cleared the field kept the old one and deployed
  /// under a name they had deliberately removed.
  DeployProject copyWith({
    String? name,
    ProjectFramework? framework,
    String? domain,
    bool clearDomain = false,
    List<DeployFile>? files,
    DeployStatus? status,
    double? uploadProgress,
    String? contentCid,
    String? programAddress,
    String? errorMessage,
  }) =>
      DeployProject(
        id: id,
        name: name ?? this.name,
        framework: framework ?? this.framework,
        domain: clearDomain ? null : (domain ?? this.domain),
        files: files ?? this.files,
        status: status ?? this.status,
        uploadProgress: uploadProgress ?? this.uploadProgress,
        contentCid: contentCid ?? this.contentCid,
        programAddress: programAddress ?? this.programAddress,
        errorMessage: errorMessage,
        createdAt: createdAt,
      );
}

class DeployFile {
  final String path;
  final int sizeBytes;
  final String? mimeType;
  final String? localPath;

  const DeployFile({
    required this.path,
    required this.sizeBytes,
    this.mimeType,
    this.localPath,
  });
}
