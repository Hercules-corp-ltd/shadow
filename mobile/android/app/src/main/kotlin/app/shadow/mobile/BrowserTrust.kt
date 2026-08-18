package app.shadow.mobile

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri

/**
 * Whether the app asking to be filled is a browser Shadow will answer.
 *
 * ## Why this gate exists at all
 *
 * An autofill request arrives with a view structure and a package name. For a
 * browser, that structure carries the web address of the page on screen, and
 * that address is what Shadow derives an identity from. Believe the wrong app
 * about what page it is showing and Shadow types one site's password into
 * another site's form — silently, at the moment somebody is trying to log in.
 *
 * ## What this actually proves, and what it does not
 *
 * Two things are checked: the package is on a list shipped in this file, and
 * the same package really does handle `http` links on this device.
 *
 * Certificates are **not** pinned. Doing that means shipping the signing hash
 * of every browser on the list and keeping it current, and a hash that is
 * wrong or stale refuses the real browser while still looking like security.
 * Rather than carry numbers that cannot be verified here, this leans on the
 * one guarantee the platform does give: package names are unique per device.
 * For a hostile app to be `com.android.chrome`, Chrome has to come off the
 * phone first — a louder, different attack than quietly mis-attributing a
 * page, and one this feature was never going to stop on its own.
 *
 * Native apps are refused outright, by omission: nothing here maps a package
 * to a website. The honest way to do that is Digital Asset Links, and until
 * that exists a package name is evidence about who wrote an app, not about
 * who owns the site it claims to be.
 */
object BrowserTrust {

    /**
     * Browsers Shadow will take a web address from.
     *
     * Names only, and only ones with enough share to be worth the surface.
     * Adding a package here is a decision to believe it about what page a
     * person is looking at.
     */
    private val KNOWN_BROWSERS = setOf(
        "com.android.chrome",
        "com.chrome.beta",
        "com.chrome.dev",
        "org.mozilla.firefox",
        "org.mozilla.firefox_beta",
        "org.mozilla.focus",
        "com.microsoft.emmx",
        "com.brave.browser",
        "com.opera.browser",
        "com.opera.mini.native",
        "com.sec.android.app.sbrowser",
        "com.duckduckgo.mobile.android",
        "com.vivaldi.browser",
        "com.kiwibrowser.browser",
        "org.torproject.torbrowser",
        // Shadow itself. Its own WebView fills through the Dart path rather
        // than through here, but a request arriving from this package is not
        // a reason to refuse.
        "app.shadow.mobile",
    )

    fun isRecognisedBrowser(context: Context, packageName: String?): Boolean {
        if (packageName.isNullOrEmpty()) return false
        if (packageName !in KNOWN_BROWSERS) return false
        return handlesWebLinks(context, packageName)
    }

    /**
     * Whether [packageName] is registered to open http links.
     *
     * A second, weaker check that costs nothing. It does not stop a
     * determined impersonator — any app may declare the intent filter — but
     * it does catch a name on the list that is no longer a browser on this
     * device.
     */
    private fun handlesWebLinks(context: Context, packageName: String): Boolean {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
            .addCategory(Intent.CATEGORY_BROWSABLE)
            .setPackage(packageName)
        return try {
            context.packageManager
                .queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
                .isNotEmpty()
        } catch (_: Exception) {
            false
        }
    }
}
