import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsService _service = SettingsService();

  ShadowSettings _settings = const ShadowSettings();
  bool _isLoaded = false;

  ShadowSettings get settings => _settings;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    _settings = await _service.load();
    _isLoaded = true;
    _applyApiBaseUrl();
    notifyListeners();
  }

  Future<void> update(ShadowSettings next) async {
    _settings = next;
    await _service.save(next);
    _applyApiBaseUrl();
    notifyListeners();
  }

  /// Pushes the configured API address into the HTTP client.
  ///
  /// `ApiClient.overrideBaseUrl` existed from the beginning and was never
  /// called from anywhere, so the client was permanently pinned to the
  /// compiled-in default — which is `localhost`, i.e. nothing at all from a
  /// real device or an emulator.
  void _applyApiBaseUrl() {
    final configured = _settings.apiBaseUrl.trim();
    ApiClient.overrideBaseUrl(
      configured.isEmpty ? ShadowConstants.defaultApiUrl : configured,
    );
  }

  /// Where the mail service lives, resolved.
  ///
  /// Read rather than pushed, unlike the API address. `MailboxApi` is
  /// constructed per use with no global instance, precisely so there is no
  /// shared client that could accumulate a shared header.
  String get mailBaseUrl {
    final configured = _settings.mailBaseUrl.trim();
    return configured.isEmpty ? ShadowConstants.defaultMailUrl : configured;
  }
}
