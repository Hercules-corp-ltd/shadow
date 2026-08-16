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

  /// Clears history, optionally limited to a time range.
  ///
  /// [range] is required to be forwarded. The clear screen offers a range
  /// picker whose value was previously written to local state and never read,
  /// so choosing "Today" silently erased everything — a data-loss bug that no
  /// test would have caught, because the call itself succeeded.
  Future<void> clear({String? range}) async {
    await _api.delete<void>(
      '/history',
      data: {if (range != null && range != 'all') 'range': range},
    );
  }
}
