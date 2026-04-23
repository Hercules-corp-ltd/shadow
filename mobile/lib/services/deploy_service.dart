import 'dart:typed_data';

import '../models/deploy_project.dart';
import 'api_client.dart';
import 'storage_service.dart';

/// Orchestrates the "Deploy Your Website" flow end-to-end: uploads files to
/// decentralized storage and registers the resulting CID on-chain via the
/// Rust backend.
class DeployService {
  final ApiClient _api = ApiClient.instance;
  final StorageService _storage = StorageService();

  Future<DeployProject> uploadProjectFiles(
    DeployProject project, {
    required Future<Uint8List> Function(DeployFile f) readFile,
    void Function(double progress)? onProgress,
  }) async {
    double doneBytes = 0;
    final totalBytes = project.files.fold<int>(0, (a, b) => a + b.sizeBytes);
    String? lastCid;

    for (final file in project.files) {
      final bytes = await readFile(file);
      lastCid = await _storage.upload(
        fileName: file.path,
        bytes: bytes,
        onProgress: (p) {
          if (totalBytes == 0) return;
          final overall = (doneBytes + p * file.sizeBytes) / totalBytes;
          onProgress?.call(overall);
        },
      );
      doneBytes += file.sizeBytes.toDouble();
    }

    return project.copyWith(
      status: DeployStatus.uploaded,
      contentCid: lastCid,
      uploadProgress: 1,
    );
  }

  Future<DeployProject> registerOnChain(DeployProject project) async {
    if (project.contentCid == null) {
      throw StateError('Project must be uploaded before registration.');
    }

    final res = await _api.post<Map<String, dynamic>>(
      '/deploy/register',
      data: {
        'project_name': project.name,
        'domain': project.domain,
        'content_cid': project.contentCid,
        'framework': project.framework.name,
      },
    );

    return project.copyWith(
      status: DeployStatus.deployed,
      programAddress: res.data?['program_address'] as String?,
    );
  }
}
