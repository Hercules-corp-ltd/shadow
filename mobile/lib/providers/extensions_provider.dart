import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/extension.dart';
import '../services/extensions_service.dart';
import '../services/fetch_outcome.dart';

class ExtensionsProvider with ChangeNotifier {
  final ExtensionsService _service = ExtensionsService();

  List<ShadowExtension> _items = const [];
  bool _isLoading = false;
  String? _error;

  List<ShadowExtension> get items => _items;
  bool get isLoading => _isLoading;

  /// Non-null when the last operation failed. Screens must render this
  /// instead of an empty state, or a dead backend looks like no extensions.
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _service.listInstalled();
    } catch (e) {
      _items = const [];
      _error = e is DioException
          ? describeDioFailure(e)
          : 'Could not load extensions';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Flips an extension on or off.
  ///
  /// The optimistic update is reverted if the call fails. Previously it was
  /// not: the switch animated, the failure was swallowed, and nothing ever put
  /// it back — so the control sat in a state it had never actually reached.
  /// A toggle that shows "on" while the thing is off is worse than one that
  /// refuses to move.
  Future<void> toggle(String id, bool value) async {
    final previous = _items;
    _items = _items
        .map((e) => e.id == id ? e.copyWith(enabled: value) : e)
        .toList();
    _error = null;
    notifyListeners();

    try {
      await _service.toggle(id, value);
    } catch (e) {
      _items = previous;
      _error = e is DioException
          ? describeDioFailure(e)
          : 'Could not change that setting';
      notifyListeners();
    }
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
