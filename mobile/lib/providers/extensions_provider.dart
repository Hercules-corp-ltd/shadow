import 'package:flutter/foundation.dart';

import '../models/extension.dart';
import '../services/extensions_service.dart';

class ExtensionsProvider with ChangeNotifier {
  final ExtensionsService _service = ExtensionsService();

  List<BlindExtension> _items = const [];
  bool _isLoading = false;

  List<BlindExtension> get items => _items;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _service.listInstalled();
    } catch (_) {
      _items = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggle(String id, bool value) async {
    _items = _items
        .map((e) => e.id == id ? e.copyWith(enabled: value) : e)
        .toList();
    notifyListeners();
    try {
      await _service.toggle(id, value);
    } catch (_) {}
  }

  Future<void> uninstall(String id) async {
    await _service.uninstall(id);
    _items = _items.where((e) => e.id != id).toList();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    _items = const [];
    notifyListeners();
  }
}
