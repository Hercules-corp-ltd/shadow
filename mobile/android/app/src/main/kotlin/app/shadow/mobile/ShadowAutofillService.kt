package app.shadow.mobile

import android.app.PendingIntent
import android.app.assist.AssistStructure
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.view.View
import android.view.autofill.AutofillId
import android.widget.RemoteViews
import androidx.annotation.RequiresApi

/**
 * Shadow, offered to the rest of the phone.
 *
 * ## What this service is allowed to know
 *
 * Nothing derived. The branch key every credential comes from lives in memory
 * in the Flutter isolate and is wiped on lock, and it is never handed to this
 * process — so this service cannot produce a password even for a page it is
 * certain about. That is deliberate, and it is why every dataset here is an
 * authentication stub: the response says "Shadow can fill this", and the real
 * values are only ever built after [AutofillUnlockActivity] has an unlocked
 * identity in front of it.
 *
 * The alternative — keeping a derived key somewhere this service could read —
 * would put the whole identity behind whatever protects a background service,
 * which is nothing.
 *
 * ## What it refuses
 *
 * Everything that is not a recognised browser, and every page it cannot pin
 * to exactly one site. See [BrowserTrust] and `fill_target.dart`; the rules
 * live in Dart because that is where they can be tested, and this class only
 * gathers what they need.
 */
@RequiresApi(Build.VERSION_CODES.O)
class ShadowAutofillService : AutofillService() {

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback,
    ) {
        val structure = request.fillContexts.lastOrNull()?.structure
        if (structure == null) {
            callback.onSuccess(null)
            return
        }

        val parsed = parse(structure)
        val packageName = structure.activityComponent?.packageName

        // Refusals answer with null rather than with a dataset that explains
        // itself. An autofill popup is not a place to argue: it appears over
        // whatever the person is doing, and a row that cannot fill anything
        // is a row that trains them to dismiss Shadow without reading it.
        if (!BrowserTrust.isRecognisedBrowser(this, packageName)) {
            callback.onSuccess(null)
            return
        }
        if (parsed.fillable.isEmpty() || parsed.webDomains.isEmpty()) {
            callback.onSuccess(null)
            return
        }

        val unlock = Intent(this, AutofillUnlockActivity::class.java).apply {
            putStringArrayListExtra(EXTRA_WEB_DOMAINS, ArrayList(parsed.webDomains))
            putExtra(EXTRA_PACKAGE, packageName)
            putParcelableArrayListExtra(EXTRA_IDS, ArrayList(parsed.fillable.map { it.id }))
            putStringArrayListExtra(EXTRA_KINDS, ArrayList(parsed.fillable.map { it.kind.name }))
        }

        val pending = PendingIntent.getActivity(
            this,
            REQUEST_CODE,
            unlock,
            // Mutable because the platform writes the assist structure and the
            // client state into this intent before it launches.
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )

        val presentation = RemoteViews(packageName2(), android.R.layout.simple_list_item_1).apply {
            setTextViewText(android.R.id.text1, "Shadow — unlock to fill")
        }

        val response = FillResponse.Builder()
            .setAuthentication(
                parsed.fillable.map { it.id }.toTypedArray(),
                pending.intentSender,
                presentation,
            )
            .build()

        callback.onSuccess(response)
    }

    /**
     * Shadow does not learn credentials from other apps.
     *
     * Saving means storing a password somebody else's form produced, and
     * Shadow has nowhere to put one: every credential here is derived from
     * the recovery phrase, and a value that cannot be derived cannot be
     * regenerated on another device from the words alone. Accepting saves
     * would quietly turn this into a password vault with a second, weaker
     * storage story bolted to the side.
     */
    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        callback.onFailure(null)
    }

    private fun packageName2(): String = applicationContext.packageName

    // ---- structure walking -------------------------------------------------

    enum class FieldKind { USERNAME, PASSWORD, EMAIL }

    data class Field(val id: AutofillId, val kind: FieldKind)

    data class Parsed(
        val fillable: List<Field>,
        val webDomains: List<String>,
    )

    private fun parse(structure: AssistStructure): Parsed {
        val fields = mutableListOf<Field>()
        val domains = linkedSetOf<String>()

        for (i in 0 until structure.windowNodeCount) {
            walk(structure.getWindowNodeAt(i).rootViewNode, fields, domains)
        }
        return Parsed(fields, domains.toList())
    }

    private fun walk(
        node: AssistStructure.ViewNode,
        fields: MutableList<Field>,
        domains: MutableSet<String>,
    ) {
        node.webDomain?.takeIf { it.isNotBlank() }?.let { domains.add(it) }

        val id = node.autofillId
        if (id != null && node.autofillType == View.AUTOFILL_TYPE_TEXT) {
            classify(node)?.let { fields.add(Field(id, it)) }
        }

        for (i in 0 until node.childCount) {
            walk(node.getChildAt(i), fields, domains)
        }
    }

    /**
     * What a field is for, from the strongest signal available.
     *
     * Autofill hints first, because a page that declares them is telling the
     * truth about its own form as far as anyone can. The HTML type is next.
     * Free-text guessing from ids and labels is deliberately shallow: a
     * mis-read field types a password into something visible, and the cost of
     * missing a field is that a person types it themselves.
     */
    private fun classify(node: AssistStructure.ViewNode): FieldKind? {
        val hints = node.autofillHints?.map { it.lowercase() } ?: emptyList()
        when {
            hints.any { it.contains("password") } -> return FieldKind.PASSWORD
            hints.any { it.contains("emailaddress") || it == "email" } ->
                return FieldKind.EMAIL
            hints.any { it.contains("username") } -> return FieldKind.USERNAME
        }

        val html = node.htmlInfo
        if (html?.tag == "input") {
            when (html.attributes?.firstOrNull { it.first == "type" }?.second?.lowercase()) {
                "password" -> return FieldKind.PASSWORD
                "email" -> return FieldKind.EMAIL
            }
        }

        val haystack = listOfNotNull(
            node.idEntry,
            node.hint,
            node.contentDescription?.toString(),
        ).joinToString(" ").lowercase()

        return when {
            haystack.contains("password") || haystack.contains("passwd") ->
                FieldKind.PASSWORD
            haystack.contains("email") -> FieldKind.EMAIL
            haystack.contains("username") || haystack.contains("user_name") ->
                FieldKind.USERNAME
            else -> null
        }
    }

    companion object {
        const val EXTRA_WEB_DOMAINS = "app.shadow.autofill.WEB_DOMAINS"
        const val EXTRA_PACKAGE = "app.shadow.autofill.PACKAGE"
        const val EXTRA_IDS = "app.shadow.autofill.IDS"
        const val EXTRA_KINDS = "app.shadow.autofill.KINDS"
        private const val REQUEST_CODE = 8021
    }
}
