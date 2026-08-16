import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import '../services/history_service.dart';

class HistoryProvider with ChangeNotifier {
  final HistoryService _service = HistoryService();

  List<HistoryEntry> _entries = const [];
  bool _isLoading = false;
  String? _error;
  String _range = 'all';
  String _query = '';

  List<HistoryEntry> get entries => _entries
      .where((e) =>
          _query.isEmpty ||
          e.domain.toLowerCase().contains(_query.toLowerCase()) ||
          (e.title ?? '').toLowerCase().contains(_query.toLowerCase()))
      .toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get range => _range;

  Future<void> load({String range = 'all'}) async {
    _isLoading = true;
    _range = range;
    _error = null;
    notifyListeners();
    try {
      _entries = await _service.list(range: range);
    } catch (e) {
      _error = e.toString();
      _entries = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  /// Clears history. [range] of null or 'all' clears everything.
  ///
  /// The range must be threaded all the way through: the clear screen's picker
  /// used to stop at local state, so every choice erased the lot.
  Future<void> clear({String? range}) async {
    await _service.clear(range: range);
    if (range == null || range == 'all') {
      _entries = const [];
    } else {
      await load();
      return;
    }
    notifyListeners();
  }
}
