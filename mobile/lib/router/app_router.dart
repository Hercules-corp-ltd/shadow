import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/identity_provider.dart';
import '../providers/wallet_provider.dart';
import '../screens/browser/browser_screen.dart';
import '../widgets/threshold_transition.dart';
import '../screens/identity/identity_screen.dart';
import '../screens/identity/identity_backup_screen.dart';
import '../screens/identity/identity_phrase_screen.dart';
import '../screens/identity/site_detail_screen.dart';
import '../screens/identity/public_address_screen.dart';
import '../screens/identity/site_list_screen.dart';
import '../screens/activity/activity_logs_screen.dart';
import '../screens/activity/activity_screen.dart';
import '../screens/bookmarks/bookmarks_clear_screen.dart';
import '../screens/bookmarks/bookmarks_screen.dart';
import '../screens/deploy/deploy_choose_config_screen.dart';
import '../screens/deploy/deploy_config_screen.dart';
import '../screens/deploy/deploy_deployed_screen.dart';
import '../screens/deploy/deploy_download_config_screen.dart';
import '../screens/deploy/deploy_files_added_screen.dart';
import '../screens/deploy/deploy_progress_screen.dart';
import '../screens/deploy/deploy_select_project_screen.dart';
import '../screens/deploy/deploy_upload_screen.dart';
import '../screens/domains/domain_details_screen.dart';
import '../screens/domains/domain_dns_screen.dart';
import '../screens/domains/domain_find_screen.dart';
import '../screens/domains/domain_register_screen.dart';
import '../screens/domains/domain_renew_screen.dart';
import '../screens/domains/domain_results_screen.dart';
import '../screens/domains/domain_settings_screen.dart';
import '../screens/domains/domain_transfer_screen.dart';
import '../screens/downloads/downloads_clear_screen.dart';
import '../screens/downloads/downloads_screen.dart';
import '../screens/extensions/extensions_clear_screen.dart';
import '../screens/extensions/extensions_screen.dart';
import '../screens/history/history_clear_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/onboarding/welcome_screen.dart';
import '../screens/resolve/resolve_failed_screen.dart';
import '../screens/resolve/resolve_input_screen.dart';
import '../screens/resolve/resolve_resolving_screen.dart';
import '../screens/resolve/resolve_result_screen.dart';
import '../screens/settings/settings_advanced_screen.dart';
import '../screens/settings/settings_general_screen.dart';
import '../screens/settings/settings_network_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/settings_security_screen.dart';
import '../screens/settings/settings_storage_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/tokens/site_token_details_screen.dart';
import '../screens/tokens/site_token_screen.dart';
import '../screens/wallet/wallet_choose_screen.dart';
import '../screens/wallet/wallet_delete_screen.dart';
import '../screens/wallet/wallet_import_screen.dart';
import '../screens/wallet/wallet_lock_screen.dart';
import '../screens/wallet/wallet_locked_screen.dart';
import '../screens/wallet/wallet_receive_screen.dart';
import '../screens/wallet/wallet_send_screen.dart';
import '../screens/wallet/wallet_swap_screen.dart';
import '../screens/wallet/wallet_view_screen.dart';

class AppRouter {
  AppRouter._();

  static GoRouter build(BuildContext bootCtx) {
    final wallet = Provider.of<WalletProvider>(bootCtx, listen: false);

    return GoRouter(
      initialLocation: '/',
      refreshListenable: wallet,
      redirect: (context, state) {
        final path = state.matchedLocation;
        final isBooting = wallet.isLoading;
        final onSplash = path == '/';
        final onOnboarding =
            path.startsWith('/onboarding') || path == '/welcome';
        final onWalletSetup = path == '/wallet/choose' ||
            path == '/wallet/import' ||
            path == '/wallet/locked';

        if (isBooting) {
          return onSplash ? null : '/';
        }

        if (wallet.state == WalletLifecycle.noWallet) {
          if (onOnboarding || onWalletSetup) return null;
          // `shadow_onboarding_complete_v1` was written by both onboarding
          // screens and read by nobody — grep found the setter, the getter,
          // and zero call sites. So "Skip for now" only navigated: quit
          // before finishing wallet setup and the tour was back, having been
          // explicitly dismissed. Reading it here is what the flag was for.
          return wallet.onboardingComplete ? '/wallet/choose' : '/welcome';
        }

        if (wallet.state == WalletLifecycle.locked) {
          if (onWalletSetup) return null;
          return '/wallet/locked';
        }

        // Unlocked — leave splash, onboarding, and the lock screen.
        if (onSplash || onOnboarding || path == '/wallet/locked') {
          return '/home';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
        GoRoute(
          path: '/browse',
          // The one route with a transition of its own. Home is built as a
          // threshold — an arch with a slot beneath it — so going to the web
          // is the moment the whole screen is arranged around, and a platform
          // slide would make the front door feel like a settings list.
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 620),
            // Leaving is shorter and plain. A door that closes as
            // theatrically as it opens is tiring by the third time.
            reverseTransitionDuration: const Duration(milliseconds: 260),
            child: BrowserScreen(initialUrl: state.uri.queryParameters['url']),
            transitionsBuilder: (context, animation, secondary, child) =>
                ThresholdTransition(animation: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/identity',
          builder: (_, __) => const IdentityScreen(),
        ),
        GoRoute(
          path: '/identity/backup',
          builder: (_, __) => const IdentityBackupScreen(),
        ),
        GoRoute(
          path: '/identity/public-address',
          builder: (_, __) => const PublicAddressScreen(),
        ),
        GoRoute(
          path: '/identity/sites',
          builder: (_, __) => const SiteListScreen(),
        ),
        GoRoute(
          // The domain is a path segment, so it arrives encoded — a bare
          // one would swallow the rest of the path on anything with a dot
          // and a slash in it.
          path: '/identity/sites/:domain',
          builder: (_, state) => SiteDetailScreen(
            domain: Uri.decodeComponent(state.pathParameters['domain'] ?? ''),
            accountIndex:
                int.tryParse(state.uri.queryParameters['account'] ?? '') ?? 0,
          ),
        ),
        GoRoute(
          path: '/identity/phrase',
          builder: (ctx, state) => IdentityPhraseScreen(
            phrase: state.extra as String? ?? '',
            // The alias domain is not in the phrase, so the backup screen has
            // to name it or the recovery promise is untrue.
            alsoRecord: ctx.read<IdentityProvider>().aliasDomain,
          ),
        ),
        GoRoute(
          path: '/wallet/phrase',
          builder: (_, state) => IdentityPhraseScreen(
            phrase: state.extra as String? ?? '',
            subtitle: 'Twelve words that restore this wallet and its funds',
            continueRoute: '/home',
          ),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingScreen(),
        ),

        // Wallet
        GoRoute(
          path: '/wallet/choose',
          builder: (_, __) => const WalletChooseScreen(),
        ),
        GoRoute(
          path: '/wallet/import',
          builder: (_, __) => const WalletImportScreen(),
        ),
        GoRoute(
          path: '/wallet/locked',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const WalletLockedScreen(),
          ),
        ),
        GoRoute(
          path: '/wallet',
          builder: (_, __) => const WalletViewScreen(),
          routes: [
            GoRoute(path: 'lock', builder: (_, __) => const WalletLockScreen()),
            GoRoute(
              path: 'delete',
              builder: (_, __) => const WalletDeleteScreen(),
            ),
            GoRoute(path: 'send', builder: (_, __) => const WalletSendScreen()),
            GoRoute(
              path: 'receive',
              builder: (_, __) => const WalletReceiveScreen(),
            ),
            GoRoute(path: 'swap', builder: (_, __) => const WalletSwapScreen()),
          ],
        ),

        // Home
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const HomeScreen(),
          ),
        ),

        // History
        GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
        GoRoute(
          path: '/history/clear',
          builder: (_, __) => const HistoryClearScreen(),
        ),

        // Bookmarks
        GoRoute(
          path: '/bookmarks',
          builder: (_, __) => const BookmarksScreen(),
        ),
        GoRoute(
          path: '/bookmarks/clear',
          builder: (_, __) => const BookmarksClearScreen(),
        ),

        // Downloads
        GoRoute(
          path: '/downloads',
          builder: (_, __) => const DownloadsScreen(),
        ),
        GoRoute(
          path: '/downloads/clear',
          builder: (_, __) => const DownloadsClearScreen(),
        ),

        // Extensions
        GoRoute(
          path: '/extensions',
          builder: (_, __) => const ExtensionsScreen(),
        ),
        GoRoute(
          path: '/extensions/clear',
          builder: (_, __) => const ExtensionsClearScreen(),
        ),

        // Deploy
        GoRoute(
          path: '/deploy',
          builder: (_, __) => const DeploySelectProjectScreen(),
          routes: [
            GoRoute(
              path: 'config',
              builder: (_, __) => const DeployConfigScreen(),
            ),
            GoRoute(
              path: 'download',
              builder: (_, __) => const DeployDownloadConfigScreen(),
            ),
            GoRoute(
              path: 'choose',
              builder: (_, __) => const DeployChooseConfigScreen(),
            ),
            GoRoute(
              path: 'upload',
              builder: (_, __) => const DeployUploadScreen(),
            ),
            GoRoute(
              path: 'files',
              builder: (_, __) => const DeployFilesAddedScreen(),
            ),
            GoRoute(
              path: 'progress',
              builder: (_, __) => const DeployProgressScreen(),
            ),
            GoRoute(
              path: 'deployed',
              builder: (_, __) => const DeployDeployedScreen(),
            ),
          ],
        ),

        // Domains
        GoRoute(
          path: '/domains',
          builder: (_, __) => const DomainFindScreen(),
          routes: [
            GoRoute(
              path: 'results',
              builder: (_, __) => const DomainResultsScreen(),
            ),
            GoRoute(
              path: 'register',
              builder: (_, __) => const DomainRegisterScreen(),
            ),
            GoRoute(
              path: ':domain',
              builder: (ctx, s) =>
                  DomainDetailsScreen(domain: s.pathParameters['domain']!),
              routes: [
                GoRoute(
                  path: 'dns',
                  builder: (ctx, s) =>
                      DomainDnsScreen(domain: s.pathParameters['domain']!),
                ),
                GoRoute(
                  path: 'settings',
                  builder: (ctx, s) =>
                      DomainSettingsScreen(domain: s.pathParameters['domain']!),
                ),
                GoRoute(
                  path: 'renew',
                  builder: (ctx, s) =>
                      DomainRenewScreen(domain: s.pathParameters['domain']!),
                ),
                GoRoute(
                  path: 'transfer',
                  builder: (ctx, s) =>
                      DomainTransferScreen(domain: s.pathParameters['domain']!),
                ),
              ],
            ),
          ],
        ),

        // Resolve
        GoRoute(
          path: '/resolve',
          builder: (_, __) => const ResolveInputScreen(),
          routes: [
            GoRoute(
              path: 'resolving',
              builder: (ctx, s) => ResolveResolvingScreen(
                  shadowId: s.uri.queryParameters['id'] ?? ''),
            ),
            GoRoute(
              path: 'result',
              builder: (ctx, s) => ResolveResultScreen(
                  shadowId: s.uri.queryParameters['id'] ?? ''),
            ),
            GoRoute(
              path: 'failed',
              builder: (ctx, s) => ResolveFailedScreen(
                shadowId: s.uri.queryParameters['id'] ?? '',
                reason: ResolveFailure.parse(s.uri.queryParameters['reason']),
                detail: s.uri.queryParameters['detail'],
              ),
            ),
          ],
        ),

        // Tokens
        GoRoute(path: '/tokens', builder: (_, __) => const SiteTokenScreen()),
        GoRoute(
          path: '/tokens/:mint',
          builder: (ctx, s) =>
              SiteTokenDetailsScreen(mint: s.pathParameters['mint']!),
        ),

        // Activity
        GoRoute(path: '/activity', builder: (_, __) => const ActivityScreen()),
        GoRoute(
          path: '/activity/logs',
          builder: (_, __) => const ActivityLogsScreen(),
        ),

        // Settings
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'general',
              builder: (_, __) => const SettingsGeneralScreen(),
            ),
            GoRoute(
              path: 'network',
              builder: (_, __) => const SettingsNetworkScreen(),
            ),
            GoRoute(
              path: 'storage',
              builder: (_, __) => const SettingsStorageScreen(),
            ),
            GoRoute(
              path: 'security',
              builder: (_, __) => const SettingsSecurityScreen(),
            ),
            GoRoute(
              path: 'advanced',
              builder: (_, __) => const SettingsAdvancedScreen(),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(child: Text('Route not found: ${state.uri}')),
      ),
    );
  }
}
