package app.shadow.mobile

import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.view.KeyEvent
import android.webkit.ClientCertRequest
import android.webkit.HttpAuthHandler
import android.webkit.SslErrorHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.net.http.SslError
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import java.io.ByteArrayInputStream
import java.util.Locale

/**
 * Tracker blocking for Android, at the request level.
 *
 * The iOS side compiles the same rules into a WKContentRuleList and lets
 * WebKit drop matching requests inside its own network stack. Android has no
 * equivalent, and `webview_flutter` exposes no interception from Dart — which
 * is why this was honestly reported as unsupported until now.
 *
 * It is reachable from Kotlin though. `WebViewFlutterAndroidExternalApi` is
 * the plugin's own supported, documented way for another plugin to obtain the
 * underlying `WebView`, and it is the exact counterpart of the
 * `FWFWebViewFlutterWKWebViewExternalAPI` call the iOS bridge already makes.
 * With the WebView in hand, `shouldInterceptRequest` gives every subresource
 * request before it goes out.
 *
 * ## Why not JavaScript
 *
 * Patching `fetch` and `XMLHttpRequest` from an injected script is the usual
 * shortcut and it fails open. The preload scanner dispatches requests for
 * scripts and images found in the raw HTML before any injected code runs, so
 * the trackers that matter most are already in flight. It demos perfectly and
 * protects nobody, which is the worst combination available.
 *
 * ## Why the client is wrapped rather than replaced
 *
 * `webview_flutter` installs its own `WebViewClient`, and that client is what
 * drives every navigation callback the Dart side depends on — page started,
 * page finished, URL loading, SSL errors. Replacing it would silently break
 * the address bar, the progress indicator and the scheme allow-list. So the
 * plugin's client is read back, kept, and every method delegated to it. Only
 * `shouldInterceptRequest`, which the plugin does not implement, is ours.
 *
 * Reading it back needs `WebView.getWebViewClient`, which is API 26. Below
 * that this reports unsupported rather than guessing, because a blocker that
 * quietly does nothing is worse than one that says it is absent.
 */
class TrackerBlockingBridge(private val engine: FlutterEngine) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "shadow/tracker_blocking"

        /** An empty 200, which is how a blocked subresource is refused. */
        private fun blockedResponse(): WebResourceResponse =
            WebResourceResponse(
                "text/plain",
                "utf-8",
                ByteArrayInputStream(ByteArray(0)),
            )
    }

    private var blockedDomains: Set<String> = emptySet()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "install" -> install(call, result)
            "remove" -> remove(call, result)
            // Housekeeping for the iOS on-disk rule-list cache. Android
            // compiles nothing and stores nothing, so there is nothing stale
            // to sweep — succeed quietly rather than making the Dart side
            // branch on platform for a no-op.
            "purgeExcept" -> result.success(emptyList<String>())
            "thirdPartyCookies" -> thirdPartyCookies(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * Turns third-party cookies off, and reports what is actually true after.
     *
     * The Dart-side doc for `setAcceptThirdPartyCookies` says it defaults to
     * false. That is the platform default for a modern target SDK, not a
     * guarantee about this WebView, and "we assume the default is what we
     * want" is how a privacy claim quietly stops being true. So it is set
     * explicitly and then read back — the value returned is measured, not
     * asserted, and the UI can say it without hedging.
     *
     * This is the storage isolation that is actually reachable here. A real
     * per-site partition needs separate WebView profiles, which the plugin
     * does not expose; blocking third-party cookies is what stops a tracker
     * embedded on one site reading what it set on another, which is the part
     * that matters.
     */
    private fun thirdPartyCookies(call: MethodCall, result: MethodChannel.Result) {
        val webViewId = call.argument<Number>("webViewId")?.toLong()
        if (webViewId == null) {
            result.error("no-webview-id", "webViewId is required", null)
            return
        }
        val webView = WebViewFlutterAndroidExternalApi.getWebView(engine, webViewId)
        if (webView == null) {
            result.error("no-webview", "No WebView with identifier $webViewId", null)
            return
        }

        val cookies = android.webkit.CookieManager.getInstance()
        cookies.setAcceptThirdPartyCookies(webView, false)
        result.success(
            mapOf(
                "acceptsThirdParty" to cookies.acceptThirdPartyCookies(webView),
                "acceptsAny" to cookies.acceptCookie(),
            ),
        )
    }

    private fun install(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error(
                "unsupported",
                "Reading back the existing WebViewClient needs Android 8. " +
                    "Blocking is off rather than pretending.",
                null,
            )
            return
        }

        @Suppress("UNCHECKED_CAST")
        val domains = call.argument<List<String>>("domains")
        val webViewId = call.argument<Number>("webViewId")?.toLong()

        if (domains == null || domains.isEmpty()) {
            result.error("empty-list", "No domains to block", null)
            return
        }
        if (webViewId == null) {
            result.error("no-webview-id", "webViewId is required", null)
            return
        }

        val webView = WebViewFlutterAndroidExternalApi.getWebView(engine, webViewId)
        if (webView == null) {
            result.error(
                "no-webview",
                "No WebView with identifier $webViewId",
                null,
            )
            return
        }

        blockedDomains = domains.map { it.lowercase(Locale.ROOT) }.toSet()

        val existing = webView.webViewClient
        if (existing is BlockingWebViewClient) {
            // Already wrapped. Swap the list rather than nesting a second
            // wrapper, which would double every delegated callback.
            existing.blocked = blockedDomains
        } else {
            webView.webViewClient = BlockingWebViewClient(existing, blockedDomains)
        }

        result.success(mapOf("blocking" to true, "count" to blockedDomains.size))
    }

    private fun remove(call: MethodCall, result: MethodChannel.Result) {
        val webViewId = call.argument<Number>("webViewId")?.toLong()
        if (webViewId == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(false)
            return
        }
        val webView = WebViewFlutterAndroidExternalApi.getWebView(engine, webViewId)
        val current = webView?.webViewClient
        if (current is BlockingWebViewClient) {
            webView.webViewClient = current.delegate
            result.success(true)
        } else {
            result.success(false)
        }
    }
}

/**
 * The plugin's client, plus request blocking.
 *
 * Every override here exists to forward. Missing one does not fail loudly —
 * it silently stops a callback the Dart side is waiting on, so the page hangs
 * at "loading" or the address bar never updates. The list mirrors what
 * `webview_flutter`'s own client implements.
 */
private class BlockingWebViewClient(
    val delegate: WebViewClient,
    @Volatile var blocked: Set<String>,
) : WebViewClient() {

    /**
     * The page's own host, captured on the UI thread.
     *
     * `shouldInterceptRequest` runs on a background thread where touching
     * `view.url` is not allowed, and the third-party check needs to know
     * whose page this is.
     */
    @Volatile
    private var pageHost: String? = null

    override fun shouldInterceptRequest(
        view: WebView,
        request: WebResourceRequest,
    ): WebResourceResponse? {
        val host = request.url?.host?.lowercase(Locale.ROOT)
        if (host != null && shouldBlock(host)) return blockedResponseFor()
        return delegate.shouldInterceptRequest(view, request)
    }

    private fun blockedResponseFor(): WebResourceResponse =
        WebResourceResponse("text/plain", "utf-8", ByteArrayInputStream(ByteArray(0)))

    private fun shouldBlock(host: String): Boolean {
        // Third-party only, matching what the EasyPrivacy rules were scoped
        // to. A first-party request to one of these means the user went there
        // deliberately, and blocking it breaks the site they asked for.
        val page = pageHost
        if (page != null && registrable(page) == registrable(host)) return false

        if (blocked.contains(host)) return true
        // Subdomains, with a dot so that "criteo.com.evil.test" cannot match.
        return blocked.any { host.endsWith(".$it") }
    }

    /** Last two labels. Crude, and it only has to decide "same site or not". */
    private fun registrable(host: String): String {
        val parts = host.split('.')
        return if (parts.size < 2) host else parts.takeLast(2).joinToString(".")
    }

    override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
        pageHost = Uri.parse(url).host?.lowercase(Locale.ROOT)
        delegate.onPageStarted(view, url, favicon)
    }

    override fun onPageFinished(view: WebView, url: String) =
        delegate.onPageFinished(view, url)

    override fun onPageCommitVisible(view: WebView, url: String) =
        delegate.onPageCommitVisible(view, url)

    override fun shouldOverrideUrlLoading(
        view: WebView,
        request: WebResourceRequest,
    ): Boolean = delegate.shouldOverrideUrlLoading(view, request)

    @Deprecated("Kept for API < 24 parity with the delegate", ReplaceWith(""))
    @Suppress("DEPRECATION")
    override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean =
        delegate.shouldOverrideUrlLoading(view, url)

    override fun onReceivedError(
        view: WebView,
        request: WebResourceRequest,
        error: WebResourceError,
    ) = delegate.onReceivedError(view, request, error)

    @Deprecated("Kept for API < 23 parity with the delegate", ReplaceWith(""))
    @Suppress("DEPRECATION")
    override fun onReceivedError(
        view: WebView,
        errorCode: Int,
        description: String?,
        failingUrl: String?,
    ) = delegate.onReceivedError(view, errorCode, description, failingUrl)

    override fun onReceivedHttpError(
        view: WebView,
        request: WebResourceRequest,
        errorResponse: WebResourceResponse,
    ) = delegate.onReceivedHttpError(view, request, errorResponse)

    override fun onReceivedSslError(
        view: WebView,
        handler: SslErrorHandler,
        error: SslError,
    ) = delegate.onReceivedSslError(view, handler, error)

    override fun onReceivedHttpAuthRequest(
        view: WebView,
        handler: HttpAuthHandler,
        host: String?,
        realm: String?,
    ) = delegate.onReceivedHttpAuthRequest(view, handler, host, realm)

    override fun onReceivedClientCertRequest(
        view: WebView,
        request: ClientCertRequest,
    ) = delegate.onReceivedClientCertRequest(view, request)

    override fun onReceivedLoginRequest(
        view: WebView,
        realm: String?,
        account: String?,
        args: String?,
    ) = delegate.onReceivedLoginRequest(view, realm, account, args)

    override fun doUpdateVisitedHistory(
        view: WebView,
        url: String?,
        isReload: Boolean,
    ) = delegate.doUpdateVisitedHistory(view, url, isReload)

    override fun onLoadResource(view: WebView, url: String?) =
        delegate.onLoadResource(view, url)

    override fun onFormResubmission(
        view: WebView,
        dontResend: android.os.Message?,
        resend: android.os.Message?,
    ) = delegate.onFormResubmission(view, dontResend, resend)

    override fun onScaleChanged(view: WebView, oldScale: Float, newScale: Float) =
        delegate.onScaleChanged(view, oldScale, newScale)

    override fun onUnhandledKeyEvent(view: WebView, event: KeyEvent?) =
        delegate.onUnhandledKeyEvent(view, event)
}
