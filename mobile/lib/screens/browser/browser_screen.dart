import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../providers/browser_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_spacing.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/browser_bottom_bar.dart';

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

    if (!browser.open(input)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That address uses a scheme Shadow will not open.'),
        ),
      );
    }
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
            _TopBar(tab: tab),
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
  const _TopBar({this.tab});

  final BrowserTabModel? tab;

  @override
  Widget build(BuildContext context) {
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
