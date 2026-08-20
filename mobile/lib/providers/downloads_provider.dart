import 'package:flutter/foundation.dart';

import '../models/download.dart';
import '../services/downloads_service.dart';

class DownloadsProvider with ChangeNotifier {
  final DownloadsService _service = DownloadsService();

  List<Download> _items = const [];
  bool _isLoading = false;
  String? _error;

  List<Download> get items => _items;
  bool get isLoading => _isLoading;

  /// Why the last load failed. Same reasoning as every other list provider:
  /// a failed read must not render as an empty account.
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _service.list();
    } catch (e) {
      _items = const [];
      _error = 'Could not read your downloads from this device.';
      assert(() {
        debugPrint('downloads load failed: $e');
        return true;
      }());
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
