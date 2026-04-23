import '../models/extension.dart';
import 'api_client.dart';

class ExtensionsService {
  final ApiClient _api = ApiClient.instance;

  Future<List<ShadowExtension>> listInstalled() async {
    final res = await _api.get<List<dynamic>>('/extensions');
    return (res.data ?? [])
        .map((e) => ShadowExtension.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> toggle(String id, bool enabled) async {
    await _api.post<void>('/extensions/$id/toggle', data: {'enabled': enabled});
  }

  Future<void> uninstall(String id) async {
    await _api.delete<void>('/extensions/$id');
  }

  Future<void> clearAll() async {
    await _api.delete<void>('/extensions');
  }
}
