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
/// **Android**: also real, since `TrackerBlockingBridge.kt`. There is no
/// WebKit rule list, but `WebViewFlutterAndroidExternalApi` hands Kotlin the
/// underlying `WebView` — the exact counterpart of the call the iOS bridge
/// makes — and `shouldInterceptRequest` sees every subresource before it goes
/// out. The plugin's own `WebViewClient` is wrapped rather than replaced, so
/// every navigation callback still reaches Dart.
///
/// Reading that client back needs Android 8, so on 7 the bridge reports
/// unsupported instead of guessing. Both platforms send the same 58 domains,
/// emitted from one list in one build-tool run so they cannot drift apart.
///
/// What this is still not: JavaScript that patches `fetch` and
/// `XMLHttpRequest`. That shortcut fails open — the preload scanner
/// dispatches requests for scripts and images in the raw HTML before any
/// injected code can run — so it demos perfectly and protects nobody.
class TrackerBlocking {
  TrackerBlocking._();

  static const MethodChannel _channel =
      MethodChannel('shadow/tracker_blocking');

  static const String _rulesAsset = 'assets/blocklist/trackers.json';
  static const String _metaAsset = 'assets/blocklist/trackers.meta.json';

  /// The same rules as plain domains, for Android's request interception.
  /// WKContentRuleList JSON means nothing to Android's WebView.
  static const String _domainsAsset = 'assets/blocklist/trackers.domains.json';

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

  /// Both platforms are attempted now. Android may still come back
  /// unsupported at run time on Android 7 — that is the bridge's answer to
  /// give, not a guess to make from here.
  static bool get isSupported => Platform.isIOS || Platform.isAndroid;

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
      final meta = jsonDecode(await rootBundle.loadString(_metaAsset))
          as Map<String, dynamic>;

      // The identifier carries the rules' content hash, so a changed list
      // compiles under a new identifier and an unchanged one hits the
      // on-disk cache instead of recompiling every launch.
      final hash = meta['contentHash'] as String? ?? 'unknown';
      _identifier = 'shadow-trackers-$hash';

      final args = <String, Object?>{
        'identifier': _identifier,
        'webViewId': webViewId,
      };

      if (Platform.isAndroid) {
        final parsed = jsonDecode(await rootBundle.loadString(_domainsAsset));
        if (parsed is! Map) {
          throw const FormatException('Domain list is not a JSON object');
        }
        final entries = parsed['domains'];
        if (entries is! List || entries.isEmpty) {
          throw const FormatException('Domain list is empty');
        }
        // Cross-check the two assets against each other. They are emitted in
        // one run from one array, so a mismatch means someone regenerated
        // half of it — and a stale domain list is a blocker that looks
        // healthy while missing whatever was added.
        if (parsed['contentHash'] != hash) {
          throw const FormatException(
            'Domain list and rule list are from different builds',
          );
        }
        _ruleCount = entries.length;
        args['domains'] = <String>[
          for (final entry in entries)
            if (entry is Map && entry['domain'] is String)
              entry['domain'] as String,
        ];
      } else {
        final rules = await rootBundle.loadString(_rulesAsset);
        final decoded = jsonDecode(rules);
        if (decoded is! List || decoded.isEmpty) {
          throw const FormatException('Blocklist is empty or not a JSON array');
        }
        _ruleCount = decoded.length;
        args['rules'] = rules;
      }

      await _channel.invokeMethod<Map<Object?, Object?>>('install', args);

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
            ? 'Needs Android 8 or later'
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
