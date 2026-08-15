import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_client.dart';

/// Poseidon / decentralized storage — uploads bytes to IPFS/Arweave through
/// the Shadow backend and retrieves content by CID.
class StorageService {
  final ApiClient _api = ApiClient.instance;

  /// Uploads raw bytes to the chosen backend. [kind] = "ipfs" | "arweave".
  Future<String> upload({
    required String fileName,
    required Uint8List bytes,
    String kind = 'ipfs',
    String? mimeType,
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'kind': kind,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: mimeType == null ? null : _parseMediaType(mimeType),
      ),
    });

    final res = await _api.raw.post<Map<String, dynamic>>(
      '/storage/upload',
      data: form,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );

    return res.data?['cid'] as String? ?? '';
  }

  Future<Uint8List> fetchCid(String cid) async {
    final res = await _api.raw.get<List<int>>(
      '/storage/$cid',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }

  static DioMediaType? _parseMediaType(String mimeType) {
    final parts = mimeType.split('/');
    if (parts.length != 2) return null;
    return DioMediaType(parts[0], parts[1]);
  }
}
