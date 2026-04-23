import '../models/download.dart';
import 'api_client.dart';

class DownloadsService {
  final ApiClient _api = ApiClient.instance;

  Future<List<Download>> list() async {
    final res = await _api.get<List<dynamic>>('/downloads');
    return (res.data ?? [])
        .map((e) => Download.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> pause(String id) async =>
      _api.post<void>('/downloads/$id/pause');

  Future<void> resume(String id) async =>
      _api.post<void>('/downloads/$id/resume');

  Future<void> cancel(String id) async =>
      _api.delete<void>('/downloads/$id');

  Future<void> clearAll() async => _api.delete<void>('/downloads');
}
