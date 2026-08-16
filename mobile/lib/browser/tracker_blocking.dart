import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Where tracker blocking actually stands, per platform.
///
/// Modelled as a state rather than a bool on purpose. A switch labelled
/// "Tracker blocking" that is on while nothing is blocked is the failure this
/// type exists to make impossible to ship: every state below is something the
/// UI can say truthfully.
enum BlockingState {
  /// Not attempted yet.
  idle,

  /// Compiling or attaching.
  installing,

  /// A rule list is compiled and attached to the current web view.
  active,

  /// This platform has no blocking implementation at all.
  unsupported,

  /// Installation was attempted and failed. [TrackerBlocking.lastError] says why.
  failed,
}

/// Installs the bundled tracker rules into the platform web view.
///
/// ## Platform reality, stated up front
///
/// **iOS**: real. Rules compile to a WKContentRuleList — the same mechanism
/// Safari content blockers use — and WebKit drops matching requests inside its
/// own network stack before they leave the device.
///
/// **Android**: nothing. WKContentRuleList is WebKit-only, and webview_flutter
/// exposes no request interception on Android, so there is no honest way to
/// block from Dart. The state reports [BlockingState.unsupported] and the UI
/// must say so plainly rather than showing a switch that does nothing. This is
/// a real gap, not a rounding error, and it should not be papered over with
/// JavaScript that patches fetch and XHR: the preload scanner dispatches
/// requests for scripts and images in the raw HTML before any injected code
/// can run, so that approach fails open and fails silently — the worst
/// combination, because it demos perfectly and protects nobody.
class TrackerBlocking {
  TrackerBlocking._();

  static const MethodChannel _channel =
      MethodChannel('shadow/tracker_blocking');

  static const String _rulesAsset = 'assets/blocklist/trackers.json';
  static const String _metaAsset = 'assets/blocklist/trackers.meta.json';

  static BlockingState _state = BlockingState.idle;
  static String? _lastError;
  static int _ruleCount = 0;
  static String? _identifier;

  static BlockingState get state => _state;
  static String? get lastError => _lastError;

  /// How many rules are in the bundled list. Note this is a rule count, not a
  /// count of requests blocked — see the class docs on why the latter cannot
  /// be reported honestly.
  static int get ruleCount => _ruleCount;

  static bool get isSupported => Platform.isIOS;

  /// Loads the bundled rules and installs them into the web view identified by
  /// [webViewId].
  ///
  /// Call this and await it BEFORE the first page loads. Compilation is async,
  /// and a page that starts loading first is a page loaded unfiltered.
  static Future<BlockingState> install({required int webViewId}) async {
    if (!isSupported) {
      _state = BlockingState.unsupported;
      return _state;
    }

    _state = BlockingState.installing;
    try {
      final rules = await rootBundle.loadString(_rulesAsset);
      final meta = jsonDecode(await rootBundle.loadString(_metaAsset))
          as Map<String, dynamic>;

      final decoded = jsonDecode(rules);
      if (decoded is! List || decoded.isEmpty) {
        throw const FormatException('Blocklist is empty or not a JSON array');
      }
      _ruleCount = decoded.length;

      // The identifier carries the rules' content hash, so a changed list
      // compiles under a new identifier and an unchanged one hits the
      // on-disk cache instead of recompiling every launch.
      final hash = meta['contentHash'] as String? ?? 'unknown';
      _identifier = 'shadow-trackers-$hash';

      await _channel.invokeMethod<Map<Object?, Object?>>('install', {
        'identifier': _identifier,
        'rules': rules,
        'webViewId': webViewId,
      });

      // Old lists persist on disk across launches, so sweep them once the new
      // one is safely installed.
      unawaited(_purgeStale());

      _state = BlockingState.active;
      _lastError = null;
    } on PlatformException catch (e) {
      _state = BlockingState.failed;
      _lastError = '${e.code}: ${e.message ?? 'unknown error'}';
      assert(() {
        debugPrint('Tracker blocking failed to install — $_lastError');
        return true;
      }());
    } on FormatException catch (e) {
      _state = BlockingState.failed;
      _lastError = 'Blocklist is malformed: ${e.message}';
    } catch (e) {
      _state = BlockingState.failed;
      _lastError = e.toString();
    }
    return _state;
  }

  static Future<void> _purgeStale() async {
    final identifier = _identifier;
    if (identifier == null) return;
    try {
      await _channel.invokeMethod<List<Object?>>(
        'purgeExcept',
        {'identifier': identifier},
      );
    } on PlatformException {
      // Housekeeping only — a stale list left on disk costs a little space
      // and blocks nothing extra, so it must never fail an install.
    }
  }

  /// Detaches the rule list from [webViewId].
  static Future<void> remove({required int webViewId}) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('remove', {'webViewId': webViewId});
      _state = BlockingState.idle;
    } on PlatformException catch (e) {
      _lastError = e.message;
    }
  }

  /// One line, true on every platform, for the settings screen.
  static String get statusLabel {
    switch (_state) {
      case BlockingState.active:
        return 'Blocking $_ruleCount known tracker domains';
      case BlockingState.installing:
        return 'Preparing the blocklist…';
      case BlockingState.unsupported:
        return Platform.isAndroid
            ? 'Not available on Android yet — see Settings for why'
            : 'Not available on this platform';
      case BlockingState.failed:
        return 'Not blocking — ${_lastError ?? 'installation failed'}';
      case BlockingState.idle:
        return 'Not started';
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _state = BlockingState.idle;
    _lastError = null;
    _ruleCount = 0;
    _identifier = null;
  }
}
