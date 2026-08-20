import 'package:flutter/foundation.dart';

import '../models/activity.dart';
import '../services/activity_service.dart';

class ActivityProvider with ChangeNotifier {
  final ActivityService _service = ActivityService();

  List<ActivityEntry> _recent = const [];
  List<ActivityEntry> _logs = const [];
  bool _isLoading = false;
  String? _error;

  List<ActivityEntry> get recent => _recent;
  List<ActivityEntry> get logs => _logs;
  bool get isLoading => _isLoading;

  /// Why the last load failed.
  ///
  /// Both methods used to swallow the exception into an empty list with no
  /// error anywhere, so a failed read of the local store rendered as "no
  /// activity yet" — a statement about the user's account made by a read that
  /// did not happen. Every other list provider in the app carries this.
  String? get error => _error;

  Future<void> loadRecent() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _recent = await _service.recent();
    } catch (e) {
      _recent = const [];
      _error = 'Could not read your activity from this device.';
      assert(() {
        debugPrint('loadRecent failed: $e');
        return true;
      }());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLogs({String? level}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _logs = await _service.logs(level: level);
    } catch (e) {
      _logs = const [];
      _error = 'Could not read the activity log from this device.';
      assert(() {
        debugPrint('loadLogs failed: $e');
        return true;
      }());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
