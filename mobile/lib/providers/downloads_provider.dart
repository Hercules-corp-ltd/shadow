import 'package:flutter/foundation.dart';

import '../models/download.dart';
import '../services/downloads_service.dart';

class DownloadsProvider with ChangeNotifier {
  final DownloadsService _service = DownloadsService();

  List<Download> _items = const [];
  bool _isLoading = false;

  List<Download> get items => _items;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _service.list();
    } catch (_) {
      _items = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    _items = const [];
    notifyListeners();
  }

  Future<void> pause(String id) async {
    await _service.setStatus(id, DownloadStatus.paused);
    await load();
  }

  Future<void> resume(String id) async {
    await _service.setStatus(id, DownloadStatus.downloading);
    await load();
  }

  Future<void> cancel(String id) async {
    await _service.remove(id);
    _items = _items.where((d) => d.id != id).toList();
    notifyListeners();
  }
}
