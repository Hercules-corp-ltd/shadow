import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:flutter/services.dart';

import '../../browser/autofill.dart';
import '../../browser/code_fill_script.dart';
import '../../browser/storage_isolation.dart';
import '../../mail/code_extraction.dart';
import '../../browser/tracker_blocking.dart';
import '../../identity/site_identity.dart';
import '../../providers/browser_provider.dart';
import '../../mail/poll_schedule.dart';
import '../../models/site_adapter_record.dart';
import '../../providers/identity_provider.dart';
import '../../providers/mailbox_provider.dart';
import '../../providers/site_adapter_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_spacing.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/browser_bottom_bar.dart';
import '../../widgets/shadow_button.dart';

/// The actual browser. Renders live web content and drives it from the
/// existing bottom chrome, which until now was decorative.
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final browser = context.read<BrowserProvider>();
      final target = widget.initialUrl;
      if (target != null && target.trim().isNotEmpty) {
        browser.openInNewTab(target);
      } else if (!browser.hasTabs) {
        browser.addBlankTab();
      }
    });
  }

  Future<void> _promptForUrl(BuildContext context) async {
    final browser = context.read<BrowserProvider>();

    // The sheet owns its own TextEditingController. Creating one here and
    // disposing it when showModalBottomSheet returns crashes the app: the
    // route is still animating out, its TextField still depends on the
    // controller, and Flutter asserts '_dependents.isEmpty'.
    final input = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShadowColors.surfaceElevated,
      builder: (_) => _UrlPromptSheet(
        initialValue: browser.activeTab?.url?.toString() ?? '',
      ),
    );

    if (input == null || input.trim().isEmpty) return;
    if (!context.mounted) return;

    if (!await browser.open(input)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That address uses a scheme Shadow will not open.'),
        ),
      );
    }
  }

  /// Shows what would be filled, then fills only if the user says so.
  ///
  /// The preview is not ceremony. These credentials are what the account
  /// becomes, and the user needs to see the address that mail will arrive at
  /// before it is committed to a signup form.
  Future<void> _fillIdentity(BuildContext context) async {
    final browser = context.read<BrowserProvider>();
    final identityProvider = context.read<IdentityProvider>();
    final tab = browser.activeTab;
    final pageUrl = tab?.url;

    // Ask the one policy, in its one order, before deriving anything. Doing
    // the checks by hand here used to put them in a different order to
    // Autofill's own, so an http page got all the way to the preview — the
    // password was rendered on screen and only then refused.
    final refusal = Autofill.refusalFor(
      pageUrl: pageUrl,
      identityUnlocked: identityProvider.isUnlocked,
    );
    if (refusal != null) {
      _toast(context, AutofillResult.refused(refusal).message);
      return;
    }

    // The adapter carries this site's rotation counters and its password
    // policy. Until now every caller passed the defaults, so a site that had
    // forced a reset kept being handed the pre-reset password.
    final adapters = context.read<SiteAdapterProvider>();
    final record = await adapters.resolve(pageUrl!.host);
    if (!context.mounted) return;

    final SiteIdentity? identity = identityProvider.identityFor(
      pageUrl.host,
      accountIndex: record.accountIndex,
      passwordEpoch: record.account.passwordEpoch,
      aliasEpoch: record.account.aliasEpoch,
      policy: record.policy.passwordPolicy,
    );
    if (identity == null) {
      _toast(context, 'Could not derive an identity for ${pageUrl.host}.');
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: ShadowColors.surfaceElevated,
      isScrollControlled: true,
      builder: (sheetContext) => _FillPreview(identity: identity),
    );
    if (confirmed != true || !context.mounted) return;

    // Confirming is the consent moment for minting a mailbox, and it has to
    // happen before the fill rather than after: plenty of sites validate an
    // address on blur and send mail before anything is submitted.
    final mailbox = context.read<MailboxProvider>();
    final keys = identityProvider.mailboxKeysFor(
      pageUrl.host,
      accountIndex: record.accountIndex,
      aliasEpoch: record.account.aliasEpoch,
    );

    RegistrationOutcome? registration;
    if (keys != null) {
      registration = await mailbox.ensureRegistered(
        keys: keys,
        domain: identity.registrableDomain,
        aliasDomain: identityProvider.aliasDomain ?? '',
        accountIndex: record.accountIndex,
      );
    }
    if (!context.mounted) return;

    final result = await Autofill.fill(
      controller: tab!.controller,
      pageUrl: pageUrl,
      identity: identity,
      // A signup form needs a mailbox that works. Filling one that does not
      // produces an account whose reset link goes nowhere — unrecoverable,
      // with no error at any point. A login form needs no such thing: the
      // mailbox was claimed when the account was created.
      skipEmail: registration != null && !registration.succeeded,
    );
    if (!context.mounted) return;

    if (result.filledEmail == 0 &&
        result.passwordFieldsSeen >= 2 &&
        registration != null &&
        !registration.succeeded) {
      _toast(
        context,
        'Filled the password and username, but not the address: '
        '${registration.detail} A code sent there would not arrive.',
      );
    } else {
      _toast(context, result.message);
    }

    // Remember what was actually used, so the UI shows that rather than a
    // freshly derived stranger after the next password rotation.
    if (result.filledHandle > 0) {
      await adapters.recordSignup(
        identity.registrableDomain,
        handleUsed: identity.handle,
        accountIndex: record.accountIndex,
      );
    }
    if (record.account.mode == SiteMode.off && result.totalFilled > 0) {
      await adapters.setMode(
        identity.registrableDomain,
        SiteMode.masked,
        accountIndex: record.accountIndex,
      );
    }

    // The browser just watched a form get filled, which is the only reason
    // it ever has to expect mail. Nothing polls on a schedule of its own.
    if (keys != null &&
        result.filledEmail > 0 &&
        (registration?.succeeded ?? false)) {
      mailbox.watch(
        keys: keys,
        domain: identity.registrableDomain,
        trigger: PollSchedule.triggerForFill(
          passwordFieldsSeen: result.passwordFieldsSeen,
        ),
        accountIndex: record.accountIndex,
      );
    }
  }

  /// Types an arrived code into the page, on an explicit tap and never
  /// otherwise.
  ///
  /// A code arriving is a *server-timed* event. Letting something the server
  /// chose the moment of write into a page unprompted is the line between a
  /// credential manager and an agent, and it is the same line the credential
  /// fill refuses to cross.
  Future<void> _fillCode(BuildContext context, OneTimeCode code) async {
    final browser = context.read<BrowserProvider>();
    final mailbox = context.read<MailboxProvider>();
    final tab = browser.activeTab;
    final domain = mailbox.foundForDomain;

    if (tab == null || domain == null) return;

    // Re-checked here as well as inside the injected script. The page can
    // navigate between the code arriving and the user tapping.
    if (!CodeFillScript.mayOffer(pageUrl: tab.url, mailboxDomain: domain)) {
      _toast(
        context,
        'That code is for $domain. Shadow will not type it into another site.',
      );
      return;
    }

    final raw = await tab.controller.runJavaScriptReturningResult(
      CodeFillScript.build(code: code.value, expectedDomain: domain),
    );
    if (!context.mounted) return;

    // Report what happened rather than what was attempted. The script can
    // find no code field at all, and saying "filled" when nothing was would
    // send the user looking for a value that is not on the page.
    final filled = CodeFillScript.filledCount(raw);
    if (filled == 0) {
      _toast(
        context,
        'No code field found on this page. The code is ${code.value} — '
        'tap Copy to take it yourself.',
      );
      return;
    }

    mailbox.clearFound();
    _toast(context, 'Filled the code. Press the button yourself.');
  }

  /// Opens a magic link, on an explicit tap, in an ordinary tab.
  ///
  /// Never prefetched, HEAD-ed or unfurled on the way — many are single-use,
  /// and any request at all burns the link and locks the user out of the
  /// account they were trying to reach.
  Future<void> _openMagicLink(BuildContext context, MagicLink link) async {
    final browser = context.read<BrowserProvider>();
    final mailbox = context.read<MailboxProvider>();
    final expected = mailbox.foundForDomain;

    if (expected != null &&
        link.host != expected &&
        !link.host.endsWith('.$expected')) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: ShadowColors.surfaceElevated,
          title: Text('This link leaves $expected',
              style: ShadowTypography.h3),
          content: Text(
            'The mail was for $expected, but this link goes to ${link.host}.\n\n'
            'That is what a phishing link looks like. Shadow can tell because '
            'it knows which site this mailbox belongs to.',
            style: ShadowTypography.bodySm,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !context.mounted) return;
    }

    mailbox.clearFound();
    await browser.openInNewTab(link.url.toString());
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final tab = browser.activeTab;

    return Scaffold(
      backgroundColor: ShadowColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(tab: tab, onFill: () => _fillIdentity(context)),
            if (tab != null && tab.isLoading)
              LinearProgressIndicator(
                value: tab.progress / 100,
                minHeight: 2,
                backgroundColor: ShadowColors.surface,
                color: ShadowColors.primary,
              ),
            if (tab?.blockedNavigation != null)
              _BlockedBanner(
                url: tab!.blockedNavigation!,
                onDismiss: browser.dismissBlockedNotice,
              ),
            _CodeBanner(
              onFillCode: (code) => _fillCode(context, code),
              onOpenLink: (link) => _openMagicLink(context, link),
            ),
            Expanded(
              child: tab == null
                  ? const SizedBox.shrink()
                  : tab.isBlank
                      ? _StartPage(onGo: () => _promptForUrl(context))
                      : WebViewWidget(
                          key: ValueKey<int>(tab.id),
                          controller: tab.controller,
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BrowserBottomBar(
        tabs: [
          for (final t in browser.tabs)
            BrowserTab(title: t.title, url: t.displayUrl),
        ],
        activeIndex: browser.activeIndex,
        currentUrl: tab?.displayUrl ?? 'New tab',
        isSecure: tab?.isSecure ?? false,
        onTapUrl: () => _promptForUrl(context),
        onSelectTab: browser.selectTab,
        onCloseTab: browser.closeTab,
        onAddTab: browser.addBlankTab,
        onBack: (tab?.canGoBack ?? false) ? browser.back : null,
        onForward: (tab?.canGoForward ?? false) ? browser.forward : null,
        onRefresh: (tab?.isBlank ?? true) ? null : browser.reload,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.tab, required this.onFill});

  final BrowserTabModel? tab;
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    final unlocked = context.watch<IdentityProvider>().isUnlocked;
    final onPage = tab != null && !(tab?.isBlank ?? true);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: ShadowColors.textSecondary,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              tab?.title ?? 'Browser',
              style: ShadowTypography.h4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              TrackerBlocking.state == BlockingState.active
                  ? Icons.shield_rounded
                  : Icons.shield_outlined,
              size: 20,
            ),
            color: switch (TrackerBlocking.state) {
              BlockingState.active => ShadowColors.success,
              BlockingState.failed => ShadowColors.error,
              _ => ShadowColors.textDisabled,
            },
            tooltip: TrackerBlocking.statusLabel,
            // Both facts, together, because the shield is where someone
            // looks to find out what protection they actually have — and
            // storage isolation is the half that is still partial.
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${TrackerBlocking.statusLabel}\n'
                  '${StorageIsolationPolicy.current.label}',
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.fingerprint_rounded, size: 22),
            color: unlocked && onPage
                ? ShadowColors.primary
                : ShadowColors.textDisabled,
            tooltip: 'Fill my identity for this site',
            onPressed: onPage ? onFill : null,
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded, size: 20),
            color: ShadowColors.textSecondary,
            tooltip: 'Clear cookies and site data',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await context.read<BrowserProvider>().clearBrowsingData();
              messenger.showSnackBar(
                const SnackBar(content: Text('Cookies and site data cleared')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Confirmation sheet shown before anything is written into a page.
class _FillPreview extends StatelessWidget {
  const _FillPreview({required this.identity});

  final SiteIdentity identity;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fill ${identity.registrableDomain}',
                style: ShadowTypography.h3),
            const SizedBox(height: 6),
            Text(
              'This identity exists only for this domain. A lookalike site '
              'would get a different one, so filling on the wrong page cannot '
              'leak the right credentials.',
              style: ShadowTypography.bodySm,
            ),
            const SizedBox(height: 18),
            _PreviewRow(label: 'Email', value: identity.email),
            const SizedBox(height: 12),
            _PreviewRow(label: 'Username', value: identity.handle),
            const SizedBox(height: 12),
            _PreviewRow(
              label: 'Password',
              value: '${'•' * 12}  (${identity.password.length} characters)',
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ShadowColors.surface,
                borderRadius: BorderRadius.circular(ShadowRadius.sm),
                border: Border.all(color: ShadowColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pan_tool_rounded,
                      size: 16, color: ShadowColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Shadow fills the fields and stops. You press the '
                      'sign-up button yourself.',
                      style: ShadowTypography.caption,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ShadowButton(
              label: 'Fill the form',
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
            ShadowButton(
              label: 'Cancel',
              variant: ShadowButtonVariant.ghost,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: ShadowTypography.caption.copyWith(
                letterSpacing: 1.2, color: ShadowColors.textTertiary)),
        const SizedBox(height: 4),
        Text(value, style: ShadowTypography.mono),
      ],
    );
  }
}

class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner({required this.url, required this.onDismiss});

  final String url;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: ShadowColors.warning.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, size: 16, color: ShadowColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Blocked a link to $url',
              style: ShadowTypography.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: Text('Dismiss', style: ShadowTypography.label),
          ),
        ],
      ),
    );
  }
}

/// Offers a code that has arrived, in Shadow's own chrome.
///
/// A banner rather than a modal or a notification: the user is mid-flow on
/// the page that is asking for the code, and interrupting them to hand it
/// over would be a worse version of going to fetch it themselves.
///
/// Nothing here happens without a tap. Nothing is copied to the clipboard
/// unless asked, because other apps read the clipboard.
class _CodeBanner extends StatelessWidget {
  const _CodeBanner({required this.onFillCode, required this.onOpenLink});

  final void Function(OneTimeCode code) onFillCode;
  final void Function(MagicLink link) onOpenLink;

  @override
  Widget build(BuildContext context) {
    final mailbox = context.watch<MailboxProvider>();
    final found = mailbox.found;
    final domain = mailbox.foundForDomain;
    if (found.isEmpty || domain == null) return const SizedBox.shrink();

    final code = found.whereType<OneTimeCode>().firstOrNull;
    final link = found.whereType<MagicLink>().firstOrNull;

    return Container(
      width: double.infinity,
      color: ShadowColors.primary.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: <Widget>[
          const Icon(Icons.mark_email_read_outlined,
              size: 16, color: ShadowColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              code != null
                  ? 'Code ${code.value} arrived for $domain'
                  : 'A sign-in link arrived for $domain',
              style: ShadowTypography.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (code != null) ...<Widget>[
            GestureDetector(
              onTap: () => Clipboard.setData(ClipboardData(text: code.value)),
              child: Text('Copy', style: ShadowTypography.label),
            ),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: () => onFillCode(code),
              child: Text('Fill', style: ShadowTypography.label),
            ),
          ] else if (link != null)
            GestureDetector(
              onTap: () => onOpenLink(link),
              child: Text('Open ${link.host}', style: ShadowTypography.label),
            ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: mailbox.clearFound,
            child: const Icon(Icons.close_rounded,
                size: 16, color: ShadowColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StartPage extends StatelessWidget {
  const _StartPage({required this.onGo});

  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ShadowSpacing.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SHADOW',
                style: ShadowTypography.displayMd.copyWith(letterSpacing: 6)),
            const SizedBox(height: 12),
            Text(
              'Search with DuckDuckGo, or type an address.',
              style: ShadowTypography.bodySm,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onGo,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text('Go to a site', style: ShadowTypography.button),
            ),
          ],
        ),
      ),
    );
  }
}

/// The address bar's input sheet.
///
/// Stateful so the controller's lifetime matches the sheet's own. See the
/// comment in _promptForUrl for why the previous inline version crashed.
class _UrlPromptSheet extends StatefulWidget {
  const _UrlPromptSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_UrlPromptSheet> createState() => _UrlPromptSheetState();
}

class _UrlPromptSheetState extends State<_UrlPromptSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Go to', style: ShadowTypography.h4),
          const SizedBox(height: 4),
          Text(
            'A web address, or anything else to search DuckDuckGo',
            style: ShadowTypography.caption,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            style: ShadowTypography.body,
            decoration: const InputDecoration(
              hintText: 'shadow.app or "how does hkdf work"',
              prefixIcon:
                  Icon(Icons.search_rounded, color: ShadowColors.textSecondary),
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
    );
  }
}
