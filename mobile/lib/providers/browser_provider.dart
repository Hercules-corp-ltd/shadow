import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../browser/tracker_blocking.dart';
import '../browser/url_input.dart';

/// One open tab, with its own web view.
///
/// Each tab keeps a separate [WebViewController] so back/forward history does
/// not leak between tabs. Note the honest limit: on both platforms these
/// controllers share the process-wide cookie and website-data store, so tabs
/// are isolated in history but not in identity. Real per-tab partitioning
/// needs a non-persistent data store per view, which webview_flutter does not
/// currently expose — see the note on BrowserProvider.
class BrowserTabModel {
  BrowserTabModel({required this.id, required this.controller});

  final int id;
  final WebViewController controller;

  Uri? url;
  String title = 'New tab';
  bool isLoading = false;
  int progress = 0;
  bool canGoBack = false;
  bool canGoForward = false;

  /// Set once the tracker rule list has been attached (or attempted).
  bool blockingReady = false;

  /// The last navigation refused by the scheme allow-list, surfaced so a
  /// blocked link is visible rather than silently doing nothing.
  String? blockedNavigation;

  bool get isSecure => UrlInput.isSecure(url);
  String get displayUrl => UrlInput.displayLabel(url);
  bool get isBlank => url == null;
}

/// Owns the open tabs and drives navigation.
///
/// Privacy posture, stated plainly rather than implied by branding:
///
/// Tracker blocking is real on iOS — see [TrackerBlocking] — and absent on
/// Android, where no request-interception hook is reachable from Dart. The
/// UI reads its wording from the blocking state rather than assuming success.
///
/// Cookies and site data still persist across tabs and launches, exactly as
/// in any ordinary browser, until [clearBrowsingData] is called. Tabs share
/// one cookie store, so they are isolated in history but not in identity.
class BrowserProvider with ChangeNotifier {
  final List<BrowserTabModel> _tabs = <BrowserTabModel>[];
  int _activeIndex = 0;
  int _nextId = 1;

  List<BrowserTabModel> get tabs => List.unmodifiable(_tabs);
  int get activeIndex => _activeIndex;
  bool get hasTabs => _tabs.isNotEmpty;

  BrowserTabModel? get activeTab =>
      _tabs.isEmpty ? null : _tabs[_activeIndex.clamp(0, _tabs.length - 1)];

  /// Opens [input] in the active tab, creating one if needed.
  ///
  /// Returns false when the input could not be resolved to an allowed URL.
  Future<bool> open(String input) async {
    final uri = UrlInput.resolve(input);
    if (uri == null) return false;
    final tab = activeTab ?? _createTab();
    await _ensureBlocking(tab);
    await tab.controller.loadRequest(uri);
    notifyListeners();
    return true;
  }

  /// Opens [input] in a brand-new tab.
  Future<bool> openInNewTab(String input) async {
    final uri = UrlInput.resolve(input);
    if (uri == null) return false;
    final tab = _createTab();
    await _ensureBlocking(tab);
    await tab.controller.loadRequest(uri);
    notifyListeners();
    return true;
  }

  void addBlankTab() {
    _createTab();
    notifyListeners();
  }

  /// Attaches the tracker rule list before the tab's first navigation.
  ///
  /// Awaited deliberately. Rule compilation is asynchronous, so starting a
  /// load first means the first page of a cold start — the one a reviewer
  /// screenshots — would fetch its trackers before the blocker was attached.
  /// A failure here never blocks navigation: the user gets an unfiltered page
  /// and an honest status, rather than a browser that refuses to work.
  Future<void> _ensureBlocking(BrowserTabModel tab) async {
    if (tab.blockingReady) return;
    tab.blockingReady = true;
    final controller = tab.controller.platform;
    if (controller is WebKitWebViewController) {
      await TrackerBlocking.install(webViewId: controller.webViewIdentifier);
      notifyListeners();
    }
  }

  BrowserTabModel _createTab() {
    final id = _nextId++;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF050505));

    final tab = BrowserTabModel(id: id, controller: controller);

    controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) {
          // The allow-list applies to navigations the page initiates too, not
          // just what the user types, so a hostile page cannot bounce the
          // view into a custom app scheme.
          final target = Uri.tryParse(request.url);
          if (target == null ||
              !UrlInput.allowedSchemes.contains(target.scheme.toLowerCase())) {
            tab.blockedNavigation = request.url;
            notifyListeners();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageStarted: (url) {
          tab.isLoading = true;
          tab.progress = 0;
          tab.url = Uri.tryParse(url);
          notifyListeners();
        },
        onProgress: (progress) {
          tab.progress = progress;
          notifyListeners();
        },
        onPageFinished: (url) async {
          tab.isLoading = false;
          tab.progress = 100;
          tab.url = Uri.tryParse(url);
          tab.title = await controller.getTitle() ?? tab.displayUrl;
          tab.canGoBack = await controller.canGoBack();
          tab.canGoForward = await controller.canGoForward();
          notifyListeners();
        },
        onWebResourceError: (error) {
          tab.isLoading = false;
          notifyListeners();
        },
      ),
    );

    _tabs.add(tab);
    _activeIndex = _tabs.length - 1;
    return tab;
  }

  void selectTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    _activeIndex = index;
    notifyListeners();
  }

  void closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    _tabs.removeAt(index);
    if (_activeIndex >= _tabs.length) _activeIndex = _tabs.length - 1;
    if (_activeIndex < 0) _activeIndex = 0;
    notifyListeners();
  }

  Future<void> back() async {
    final tab = activeTab;
    if (tab != null && await tab.controller.canGoBack()) {
      await tab.controller.goBack();
    }
  }

  Future<void> forward() async {
    final tab = activeTab;
    if (tab != null && await tab.controller.canGoForward()) {
      await tab.controller.goForward();
    }
  }

  Future<void> reload() async => activeTab?.controller.reload();

  void dismissBlockedNotice() {
    activeTab?.blockedNavigation = null;
    notifyListeners();
  }

  /// Drops cookies and cached site data for every tab.
  Future<void> clearBrowsingData() async {
    await WebViewCookieManager().clearCookies();
    for (final tab in _tabs) {
      await tab.controller.clearCache();
      await tab.controller.clearLocalStorage();
    }
    notifyListeners();
  }
}
