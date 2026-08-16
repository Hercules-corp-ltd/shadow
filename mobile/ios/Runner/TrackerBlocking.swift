import Flutter
import UIKit
import WebKit
import webview_flutter_wkwebview

/// Installs a compiled WKContentRuleList into the WKWebView that
/// webview_flutter created.
///
/// ## Why this exists rather than a package
///
/// webview_flutter has no content-blocking API and cannot be extended from
/// Dart: the WKWebViewConfiguration is built inside the plugin and never
/// surfaced. The alternative package that does expose blocking is effectively
/// unmaintained — its last release predates several Xcode versions and it has
/// an open compile failure on current toolchains — and its Android blocker
/// issues an HTTP HEAD request to every subresource before deciding to block
/// it, which contacts the tracker it claims to be blocking. Neither is
/// acceptable for a privacy product, so this reaches the real WKWebView
/// through the plugin's documented external API instead. That API follows the
/// Dart package's breaking-change conventions; nothing else native here does.
///
/// ## What this actually gives you
///
/// WKContentRuleList is the same mechanism Safari content blockers use.
/// Matching happens inside WebKit's network stack, in the content process,
/// before the request leaves the device. There is no Dart round-trip per
/// request and no JavaScript involved, so it cannot be raced by a page or
/// defeated by a preload scanner.
///
/// It blocks network requests to listed third-party hosts. It does not stop
/// first-party fingerprinting, CNAME-cloaked trackers resolving to first-party
/// subdomains, or server-side tagging. "Blocks known third-party tracker
/// domains" is defensible; "blocks tracking" is not.
///
/// ## Deliberately no blocked-request counter
///
/// WebKit exposes no public API telling an app that a request was blocked.
/// The notify action reports only through private WKNavigationDelegate SPI,
/// which risks App Store rejection and which WebKit's own source notes is not
/// wired for the network-process path. Any "N trackers blocked" figure would
/// therefore be private API, a guess, or invented — so this returns rule
/// counts and installation state, and never a block count.
public final class TrackerBlocking: NSObject {
  private static let channelName = "shadow/tracker_blocking"

  /// Errors are surfaced to Dart rather than printed. A blocker that fails
  /// silently while the settings screen reads "on" is worse than no blocker,
  /// because the user changes their behaviour on the strength of it.
  private enum Failure: String {
    case webViewMissing = "webview_missing"
    case compileFailed = "compile_failed"
    case listMissing = "list_missing"
    case badArguments = "bad_arguments"
    case storeUnavailable = "store_unavailable"
  }

  public static func register(with registry: FlutterPluginRegistry, messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "install":
        install(call: call, registry: registry, result: result)
      case "remove":
        remove(call: call, registry: registry, result: result)
      case "purgeExcept":
        purgeExcept(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Install

  private static func install(
    call: FlutterMethodCall, registry: FlutterPluginRegistry, result: @escaping FlutterResult
  ) {
    guard
      let args = call.arguments as? [String: Any],
      let identifier = args["identifier"] as? String,
      let rules = args["rules"] as? String,
      let webViewId = (args["webViewId"] as? NSNumber)?.int64Value
    else {
      result(error(.badArguments, "install needs identifier, rules and webViewId"))
      return
    }

    guard let store = WKContentRuleListStore.default() else {
      result(error(.storeUnavailable, "WKContentRuleListStore is unavailable"))
      return
    }

    // Look the list up before compiling. Compilation is expensive enough that
    // repeating it per tab, or per launch, is a visible stall — and the store
    // persists across launches, so a cache hit is the normal path after first
    // run. The identifier carries a content hash, so changing the rules
    // changes the identifier and the cache misses exactly when it should.
    store.lookUpContentRuleList(forIdentifier: identifier) { existing, _ in
      if let existing = existing {
        attach(existing, webViewId: webViewId, registry: registry, identifier: identifier,
               compiled: false, result: result)
        return
      }

      store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: rules) {
        compiled, compileError in
        if let compileError = compileError {
          // WebKit fails a rule list atomically: one malformed rule means the
          // whole list is rejected, so this is never a partial outcome.
          result(error(.compileFailed, compileError.localizedDescription))
          return
        }
        guard let compiled = compiled else {
          result(error(.compileFailed, "compileContentRuleList returned no list and no error"))
          return
        }
        attach(compiled, webViewId: webViewId, registry: registry, identifier: identifier,
               compiled: true, result: result)
      }
    }
  }

  private static func attach(
    _ list: WKContentRuleList, webViewId: Int64, registry: FlutterPluginRegistry,
    identifier: String, compiled: Bool, result: @escaping FlutterResult
  ) {
    // WebKit callbacks can arrive off the main thread; touching a web view
    // from one is undefined behaviour.
    DispatchQueue.main.async {
      guard
        let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
          forIdentifier: webViewId, withPluginRegistry: registry)
      else {
        // The identifier is only valid while that controller lives, so a tab
        // closed mid-compile lands here. Not fatal, but the caller must know
        // the list did not attach.
        result(error(.webViewMissing, "No WKWebView for identifier \(webViewId)"))
        return
      }

      let controller = webView.configuration.userContentController
      // Replace rather than accumulate: re-installing after a rules change
      // would otherwise leave the previous list attached alongside the new one.
      controller.removeAllContentRuleLists()
      controller.add(list)

      result([
        "identifier": identifier,
        "compiled": compiled,
      ])
    }
  }

  // MARK: - Remove

  private static func remove(
    call: FlutterMethodCall, registry: FlutterPluginRegistry, result: @escaping FlutterResult
  ) {
    guard
      let args = call.arguments as? [String: Any],
      let webViewId = (args["webViewId"] as? NSNumber)?.int64Value
    else {
      result(error(.badArguments, "remove needs webViewId"))
      return
    }
    DispatchQueue.main.async {
      guard
        let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
          forIdentifier: webViewId, withPluginRegistry: registry)
      else {
        result(error(.webViewMissing, "No WKWebView for identifier \(webViewId)"))
        return
      }
      webView.configuration.userContentController.removeAllContentRuleLists()
      result(true)
    }
  }

  // MARK: - Housekeeping

  /// Drops every compiled list except [keep].
  ///
  /// The store is on-disk and survives launches, so without this each rules
  /// update would leave its predecessor behind for good.
  private static func purgeExcept(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let keep = args["identifier"] as? String
    else {
      result(error(.badArguments, "purgeExcept needs identifier"))
      return
    }
    guard let store = WKContentRuleListStore.default() else {
      result(error(.storeUnavailable, "WKContentRuleListStore is unavailable"))
      return
    }

    store.getAvailableContentRuleListIdentifiers { identifiers in
      let stale = (identifiers ?? []).filter { $0 != keep }
      let group = DispatchGroup()
      for identifier in stale {
        group.enter()
        store.removeContentRuleList(forIdentifier: identifier) { _ in group.leave() }
      }
      group.notify(queue: .main) { result(stale) }
    }
  }

  private static func error(_ failure: Failure, _ message: String) -> FlutterError {
    FlutterError(code: failure.rawValue, message: message, details: nil)
  }
}
