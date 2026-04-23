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

  DeployProject copyWith({
    String? name,
    ProjectFramework? framework,
    String? domain,
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
        domain: domain ?? this.domain,
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
