package app.shadow.mobile

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import android.service.autofill.Dataset
import android.service.autofill.FillResponse
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The screen a fill goes through, and the only place values are made.
 *
 * ## Why a whole activity, and why it runs Flutter
 *
 * [ShadowAutofillService] cannot derive anything: the branch key lives in the
 * Flutter isolate and is wiped on lock, so a background service has no way to
 * turn a domain into a password. Nor should it — a service that could would
 * be an identity sitting behind no lock at all.
 *
 * So the response the service returns is an authentication stub, and this is
 * what it authenticates into. It hosts Flutter for one reason: the derivation
 * is BIP-39 to HKDF to a per-site password, alias and username, it is already
 * written and tested in Dart, and a second implementation in Kotlin would be
 * a second thing to keep in step. When those two drift, the failure is not a
 * crash — it is a password that used to work and now does not, for an account
 * the user can no longer get into.
 *
 * ## What leaves this activity
 *
 * A Dataset, handed to the platform, which types it into the requesting app's
 * fields. Nothing is written down, and nothing about the request is kept: the
 * site is not recorded as visited, because the user did not visit it here.
 */
@RequiresApi(Build.VERSION_CODES.O)
class AutofillUnlockActivity : FlutterActivity() {

    private var ids: List<AutofillId> = emptyList()
    private var kinds: List<String> = emptyList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        @Suppress("DEPRECATION")
        ids = intent.getParcelableArrayListExtra<AutofillId>(
            ShadowAutofillService.EXTRA_IDS,
        ) ?: emptyList()
        kinds = intent.getStringArrayListExtra(
            ShadowAutofillService.EXTRA_KINDS,
        ) ?: emptyList()

        // If the user backs out, the platform must hear a refusal rather than
        // a half-answer. Set now, overwritten only on a completed fill.
        setResult(Activity.RESULT_CANCELED)
    }

    override fun getInitialRoute(): String = "/autofill"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Dart asks what it is being asked to fill. The platform is the
            // authority on this, never the page.
            "request" -> result.success(
                mapOf(
                    "package" to intent.getStringExtra(ShadowAutofillService.EXTRA_PACKAGE),
                    "webDomains" to (
                        intent.getStringArrayListExtra(
                            ShadowAutofillService.EXTRA_WEB_DOMAINS,
                        ) ?: arrayListOf<String>()
                        ),
                    "kinds" to kinds,
                    "browserTrusted" to BrowserTrust.isRecognisedBrowser(
                        this,
                        intent.getStringExtra(ShadowAutofillService.EXTRA_PACKAGE),
                    ),
                )
            )

            // Dart has an unlocked identity and has derived for the domain it
            // was allowed to derive for.
            "fill" -> {
                @Suppress("UNCHECKED_CAST")
                val values = call.arguments as? Map<String, String>
                if (values == null) {
                    result.error("bad-arguments", "Expected a map of values", null)
                    return
                }
                finishWith(values)
                result.success(true)
            }

            "cancel" -> {
                setResult(Activity.RESULT_CANCELED)
                finish()
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    private fun finishWith(values: Map<String, String>) {
        val presentation = RemoteViews(packageName, android.R.layout.simple_list_item_1)
            .apply { setTextViewText(android.R.id.text1, "Shadow") }

        val dataset = Dataset.Builder(presentation)
        var filled = 0

        ids.forEachIndexed { index, id ->
            val kind = kinds.getOrNull(index) ?: return@forEachIndexed
            val value = values[kind] ?: return@forEachIndexed
            dataset.setValue(id, AutofillValue.forText(value))
            filled++
        }

        if (filled == 0) {
            setResult(Activity.RESULT_CANCELED)
            finish()
            return
        }

        val reply = Intent().apply {
            putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, dataset.build())
        }
        setResult(Activity.RESULT_OK, reply)
        finish()
    }

    companion object {
        const val CHANNEL = "app.shadow/autofill"
    }
}
