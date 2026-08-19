import 'package:flutter/foundation.dart';

import '../models/bookmark.dart';
import '../services/bookmarks_service.dart';

class BookmarksProvider with ChangeNotifier {
  final BookmarksService _service = BookmarksService();

  List<Bookmark> _bookmarks = const [];
  bool _isLoading = false;
  String? _error;
  String? _folder;
  String _query = '';

  List<Bookmark> get bookmarks => _bookmarks
      .where((b) =>
          _query.isEmpty ||
          b.domain.toLowerCase().contains(_query.toLowerCase()) ||
          (b.title ?? '').toLowerCase().contains(_query.toLowerCase()))
      .toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get folder => _folder;
  Set<String> get folders => _bookmarks.map((b) => b.folder ?? 'All').toSet();

  Future<void> load({String? folder}) async {
    _isLoading = true;
    _folder = folder;
    _error = null;
    notifyListeners();
    try {
      _bookmarks = await _service.list(folder: folder);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  Future<void> add({
    required String domain,
    String? programAddress,
    String? title,
    String? description,
    String? folder,
    List<String> tags = const [],
  }) async {
    await _service.add(
      domain: domain,
      programAddress: programAddress,
      title: title,
      description: description,
      folder: folder,
      tags: tags,
    );
    await load(folder: _folder);
  }

  Future<void> remove(String domain) async {
    await _service.remove(domain);
    _bookmarks = _bookmarks.where((b) => b.domain != domain).toList();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    _bookmarks = const [];
    notifyListeners();
  }
}
