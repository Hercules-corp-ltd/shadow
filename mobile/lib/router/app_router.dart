import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/wallet_provider.dart';
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
        final onOnboarding = path.startsWith('/onboarding') ||
            path == '/welcome';
        final onWalletSetup = path == '/wallet/choose' ||
            path == '/wallet/import' ||
            path == '/wallet/locked';

        if (isBooting) {
          return onSplash ? null : '/';
        }

        if (wallet.state == WalletLifecycle.noWallet) {
          if (onOnboarding || onWalletSetup) return null;
          return '/welcome';
        }

        if (wallet.state == WalletLifecycle.locked) {
          if (onWalletSetup) return null;
          return '/wallet/locked';
        }

        // Unlocked — prevent staying on splash or onboarding.
        if (onSplash || onOnboarding) return '/home';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
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
          builder: (_, __) => const WalletLockedScreen(),
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
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),

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
                  shadowId: s.uri.queryParameters['id'] ?? ''),
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
