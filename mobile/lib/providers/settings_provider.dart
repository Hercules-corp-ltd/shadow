import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsService _service = SettingsService();

  ShadowSettings _settings = const ShadowSettings();
  bool _isLoaded = false;

  ShadowSettings get settings => _settings;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    _settings = await _service.load();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> update(ShadowSettings next) async {
    _settings = next;
    await _service.save(next);
    notifyListeners();
  }
}
