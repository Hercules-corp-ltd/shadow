import '../models/download.dart';
import 'local_store.dart';

/// The download list, kept on the device.
///
/// Every route this used — list, pause, resume, delete, clear — was absent
/// from the backend, so the screen was a permanent empty state. A download
/// list is device state in any browser: the file is on this phone, and a
/// server has no way to know anything useful about it.
class DownloadsService {
  static const _store = LocalStore<Download>(
    key: 'shadow_downloads_v1',
    encode: _encode,
    decode: Download.fromJson,
  );

  static Map<String, dynamic> _encode(Download d) => d.toJson();

  Future<List<Download>> list() async {
    final all = await _store.readAll();
    return all..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<void> add(Download download) async {
    final all = await _store.readAll();
    await _store.writeAll([...all, download]);
  }

  /// Records a status change — used by pause and resume.
  Future<void> setStatus(String id, DownloadStatus status) async {
    final all = await _store.readAll();
    await _store.writeAll([
      for (final d in all)
        if (d.id == id)
          Download(
            id: d.id,
            fileName: d.fileName,
            mimeType: d.mimeType,
            sizeBytes: d.sizeBytes,
            bytesReceived: d.bytesReceived,
            sourceDomain: d.sourceDomain,
            startedAt: d.startedAt,
            completedAt: d.completedAt,
            status: status,
            type: d.type,
            localPath: d.localPath,
          )
        else
          d,
    ]);
  }

  Future<void> remove(String id) async {
    final all = await _store.readAll();
    await _store.writeAll(all.where((d) => d.id != id).toList());
  }

  Future<void> clearAll() => _store.clear();
}
