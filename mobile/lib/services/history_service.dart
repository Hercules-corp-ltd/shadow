import '../models/history_entry.dart';
import 'api_client.dart';

class HistoryService {
  final ApiClient _api = ApiClient.instance;

  Future<List<HistoryEntry>> list({int limit = 50, String? range}) async {
    final res = await _api.get<List<dynamic>>(
      '/history',
      query: {'limit': limit, if (range != null) 'range': range},
    );
    return (res.data ?? [])
        .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> record({
    required String domain,
    String? programAddress,
    String? title,
    int timeSpentSeconds = 0,
  }) async {
    await _api.post<void>('/history', data: {
      'domain': domain,
      'program_address': programAddress,
      'title': title,
      'time_spent_seconds': timeSpentSeconds,
    });
  }

  Future<void> clear() async {
    await _api.delete<void>('/history');
  }
}
