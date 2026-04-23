import 'package:flutter/foundation.dart';

import '../models/activity.dart';
import '../services/activity_service.dart';

class ActivityProvider with ChangeNotifier {
  final ActivityService _service = ActivityService();

  List<ActivityEntry> _recent = const [];
  List<ActivityEntry> _logs = const [];
  bool _isLoading = false;

  List<ActivityEntry> get recent => _recent;
  List<ActivityEntry> get logs => _logs;
  bool get isLoading => _isLoading;

  Future<void> loadRecent() async {
    _isLoading = true;
    notifyListeners();
    try {
      _recent = await _service.recent();
    } catch (_) {
      _recent = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLogs({String? level}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _logs = await _service.logs(level: level);
    } catch (_) {
      _logs = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
