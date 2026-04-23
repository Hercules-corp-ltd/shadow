import '../models/activity.dart';
import 'api_client.dart';

class ActivityService {
  final ApiClient _api = ApiClient.instance;

  Future<List<ActivityEntry>> recent({int limit = 25}) async {
    final res =
        await _api.get<List<dynamic>>('/activity', query: {'limit': limit});
    return (res.data ?? [])
        .map((e) => ActivityEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ActivityEntry>> logs({int limit = 100, String? level}) async {
    final res = await _api.get<List<dynamic>>(
      '/activity/logs',
      query: {'limit': limit, if (level != null) 'level': level},
    );
    return (res.data ?? [])
        .map((e) => ActivityEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
