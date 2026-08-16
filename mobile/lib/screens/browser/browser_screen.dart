import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../browser/autofill.dart';
import '../../browser/tracker_blocking.dart';
import '../../identity/site_identity.dart';
import '../../providers/browser_provider.dart';
import '../../providers/identity_provider.dart';
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
    final controller =
        TextEditingController(text: browser.activeTab?.url?.toString() ?? '');

    final input = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ShadowColors.surfaceElevated,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
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
              controller: controller,
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
              onSubmitted: (value) => Navigator.pop(sheetContext, value),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
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

    if (tab == null || pageUrl == null || pageUrl.host.isEmpty) {
      _toast(context, 'Open a site before filling.');
      return;
    }
    if (!identityProvider.isUnlocked) {
      _toast(context, 'Unlock your identity first, then try again.');
      return;
    }

    final SiteIdentity? identity = identityProvider.identityFor(pageUrl.host);
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

    final result = await Autofill.fill(
      controller: tab.controller,
      pageUrl: pageUrl,
      identity: identity,
    );
    if (!context.mounted) return;
    _toast(context, result.message);
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
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(TrackerBlocking.statusLabel)),
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
