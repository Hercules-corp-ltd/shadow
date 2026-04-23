enum DownloadStatus { queued, downloading, complete, failed, paused }

enum DownloadType { document, image, video, audio, code, archive, other }

class Download {
  final String id;
  final String fileName;
  final String? mimeType;
  final int sizeBytes;
  final int bytesReceived;
  final String sourceDomain;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DownloadStatus status;
  final DownloadType type;
  final String? localPath;

  const Download({
    required this.id,
    required this.fileName,
    this.mimeType,
    required this.sizeBytes,
    this.bytesReceived = 0,
    required this.sourceDomain,
    required this.startedAt,
    this.completedAt,
    this.status = DownloadStatus.queued,
    this.type = DownloadType.other,
    this.localPath,
  });

  double get progress => sizeBytes == 0 ? 0 : bytesReceived / sizeBytes;

  factory Download.fromJson(Map<String, dynamic> json) => Download(
        id: (json['id'] ?? '').toString(),
        fileName: json['file_name'] ?? '',
        mimeType: json['mime_type'],
        sizeBytes: (json['size_bytes'] ?? 0) as int,
        bytesReceived: (json['bytes_received'] ?? 0) as int,
        sourceDomain: json['source_domain'] ?? '',
        startedAt: DateTime.tryParse(json['started_at']?.toString() ?? '') ??
            DateTime.now(),
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.tryParse(json['completed_at'].toString()),
        status: _parseStatus(json['status']),
        type: _parseType(json['type']),
        localPath: json['local_path'],
      );

  static DownloadStatus _parseStatus(dynamic v) {
    return DownloadStatus.values.firstWhere(
      (s) => s.name == (v?.toString() ?? ''),
      orElse: () => DownloadStatus.queued,
    );
  }

  static DownloadType _parseType(dynamic v) {
    return DownloadType.values.firstWhere(
      (s) => s.name == (v?.toString() ?? ''),
      orElse: () => DownloadType.other,
    );
  }
}
