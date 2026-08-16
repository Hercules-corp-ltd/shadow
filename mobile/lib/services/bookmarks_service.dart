import '../models/bookmark.dart';
import 'local_store.dart';

/// Bookmarks, kept on the device.
///
/// Previously these went to `/bookmarks` on the backend, and even the routes
/// that existed 400'd: the handler bound a `SearchQuery` whose `q` field was a
/// required String, while the client sent none. Bookmarks also could not be
/// cleared, because `DELETE /bookmarks` was never registered.
///
/// None of that is worth fixing, because a browser's bookmarks do not belong
/// on a server at all — least of all this one's.
class BookmarksService {
  static const _store = LocalStore<Bookmark>(
    key: 'shadow_bookmarks_v1',
    encode: _encode,
    decode: Bookmark.fromJson,
  );

  static Map<String, dynamic> _encode(Bookmark b) => b.toJson();

  Future<List<Bookmark>> list({String? folder}) async {
    final all = await _store.readAll();
    final filtered =
        folder == null ? all : all.where((b) => b.folder == folder).toList();
    return filtered..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<Bookmark> add({
    required String domain,
    String? programAddress,
    String? title,
    String? description,
    String? folder,
    List<String> tags = const [],
  }) async {
    final all = await _store.readAll();

    // Re-bookmarking a domain updates it rather than duplicating it, which is
    // what every browser does and what the previous POST-only API could not.
    final existing = all.indexWhere((b) => b.domain == domain);
    final bookmark = Bookmark(
      id: existing >= 0
          ? all[existing].id
          : DateTime.now().microsecondsSinceEpoch.toString(),
      domain: domain,
      programAddress: programAddress,
      title: title,
      description: description,
      folder: folder,
      tags: tags,
      createdAt: existing >= 0 ? all[existing].createdAt : DateTime.now(),
    );

    final next = List<Bookmark>.from(all);
    if (existing >= 0) {
      next[existing] = bookmark;
    } else {
      next.add(bookmark);
    }
    await _store.writeAll(next);
    return bookmark;
  }

  Future<void> remove(String domain) async {
    final all = await _store.readAll();
    await _store.writeAll(all.where((b) => b.domain != domain).toList());
  }

  Future<void> clearAll() => _store.clear();
}
