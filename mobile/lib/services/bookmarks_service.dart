import '../models/bookmark.dart';
import 'api_client.dart';

class BookmarksService {
  final ApiClient _api = ApiClient.instance;

  Future<List<Bookmark>> list({String? folder}) async {
    final res = await _api.get<List<dynamic>>(
      '/bookmarks',
      query: folder == null ? null : {'q': folder},
    );
    return (res.data ?? [])
        .map((e) => Bookmark.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> add({
    required String domain,
    String? programAddress,
    String? title,
    String? description,
    String? folder,
    List<String> tags = const [],
  }) async {
    await _api.post<void>('/bookmarks', data: {
      'domain': domain,
      'program_address': programAddress,
      'title': title,
      'description': description,
      'folder': folder,
      'tags': tags,
    });
  }

  Future<void> remove(String domain) async {
    await _api.delete<void>('/bookmarks/$domain');
  }

  Future<void> clearAll() async {
    await _api.delete<void>('/bookmarks');
  }
}
