import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// How isolated one site's storage is from another's, measured.
class StorageIsolation {
  const StorageIsolation._({
    required this.thirdPartyCookiesBlocked,
    required this.perSitePartition,
    this.detail = '',
  });

  const StorageIsolation.unknown()
      : this._(thirdPartyCookiesBlocked: false, perSitePartition: false);

  /// A tracker embedded on two sites cannot read on one what it set on the
  /// other. The part of isolation that actually stops cross-site tracking.
  final bool thirdPartyCookiesBlocked;

  /// Each site gets its own storage area entirely.
  ///
  /// False everywhere, and honestly so. It needs a separate WebView profile
  /// per site — `ProfileStore` on Android, a non-persistent
  /// `WKWebsiteDataStore` on iOS — and `webview_flutter` exposes neither. The
  /// consequence is worth stating plainly rather than implying otherwise:
  /// tabs are separate in history but share one cookie jar, so two sites you
  /// are signed into at once are, to a determined observer with access to
  /// that jar, the same browser.
  final bool perSitePartition;

  final String detail;

  /// One line, true on every platform.
  String get label {
    if (perSitePartition) return 'Each site has its own storage';
    if (thirdPartyCookiesBlocked) {
      return 'Third-party cookies blocked; sites share one cookie store';
    }
    return 'Third-party cookies are allowed';
  }
}

/// Applies what storage isolation the platform actually permits.
///
/// Deliberately measures rather than assumes. Android's WebView defaults
/// third-party cookies off for a modern target SDK, which is easy to write
/// down as "we block them" and leave — right up until a platform default
/// changes and the claim silently becomes false. So the bridge sets it and
/// reads it back, and this reports what came back.
class StorageIsolationPolicy {
  StorageIsolationPolicy._();

  static const MethodChannel _channel =
      MethodChannel('shadow/tracker_blocking');

  static StorageIsolation _current = const StorageIsolation.unknown();
  static StorageIsolation get current => _current;

  static Future<StorageIsolation> apply({required int webViewId}) async {
    if (!Platform.isAndroid) {
      // iOS is not being claimed either way here yet. WKWebView's default is
      // to block third-party cookies under ITP, but this has not been
      // measured through the bridge the way Android now is, and an unmeasured
      // claim is the thing this class exists to avoid.
      _current = const StorageIsolation.unknown();
      return _current;
    }

    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'thirdPartyCookies',
        <String, Object?>{'webViewId': webViewId},
      );
      final accepts = result?['acceptsThirdParty'] as bool? ?? true;
      _current = StorageIsolation._(
        thirdPartyCookiesBlocked: !accepts,
        perSitePartition: false,
      );
    } on PlatformException catch (e) {
      _current = StorageIsolation._(
        thirdPartyCookiesBlocked: false,
        perSitePartition: false,
        detail: e.message ?? 'could not read the cookie policy',
      );
    }
    return _current;
  }
}
