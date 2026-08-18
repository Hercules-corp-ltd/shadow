import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/browser_provider.dart';
import 'providers/identity_provider.dart';
import 'providers/mailbox_provider.dart';
import 'providers/site_adapter_provider.dart';
import 'providers/activity_provider.dart';
import 'providers/bookmarks_provider.dart';
import 'providers/deploy_provider.dart';
import 'providers/domains_provider.dart';
import 'providers/downloads_provider.dart';
import 'providers/extensions_provider.dart';
import 'providers/history_provider.dart';
import 'providers/public_address_provider.dart';
import 'providers/settings_provider.dart';
import 'services/settings_service.dart';
import 'providers/tokens_provider.dart';
import 'providers/wallet_provider.dart';
import 'router/app_router.dart';
import 'widgets/ambient_light.dart';
import 'theme/shadow_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(ShadowTheme.overlayStyle);
  runApp(const ShadowApp());
}

class ShadowApp extends StatelessWidget {
  const ShadowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..ensureLoaded()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => BookmarksProvider()),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ChangeNotifierProvider(create: (_) => ExtensionsProvider()),
        ChangeNotifierProvider(create: (_) => DomainsProvider()),
        // Proxy so the RPC URL in Settings genuinely governs where holdings
        // are read from. That setting existed for months with no consumer.
        ChangeNotifierProxyProvider<SettingsProvider, TokensProvider>(
          create: (_) => TokensProvider(rpcUrl: const ShadowSettings().rpcUrl),
          update: (_, settings, tokens) =>
              (tokens ?? TokensProvider(rpcUrl: settings.settings.rpcUrl))
                ..setRpcUrl(settings.settings.rpcUrl),
        ),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
        ChangeNotifierProvider(create: (_) => DeployProvider()),
        ChangeNotifierProvider(create: (_) => IdentityProvider()),
        ChangeNotifierProvider(create: (_) => SiteAdapterProvider()),
        // Reads the mail address rather than being handed it, so a change in
        // Settings takes effect on the next call with no wiring in between.
        // Deliberately not sharing ApiClient: its interceptor stamps
        // X-Shadow-Auth on everything, which would link every mailbox to one
        // account.
        ChangeNotifierProxyProvider<SettingsProvider, MailboxProvider>(
          create: (ctx) => MailboxProvider(
            mailBaseUrl: () =>
                ctx.read<SettingsProvider>().mailBaseUrl,
          ),
          update: (_, __, mailbox) => mailbox!,
        ),
        ChangeNotifierProxyProvider<SettingsProvider, PublicAddressProvider>(
          create: (ctx) => PublicAddressProvider(
            mailBaseUrl: () => ctx.read<SettingsProvider>().mailBaseUrl,
          ),
          update: (_, __, addresses) => addresses!,
        ),
        ChangeNotifierProvider(create: (_) => BrowserProvider()),
      ],
      child: Builder(
        builder: (ctx) {
          final router = AppRouter.build(ctx);
          return MaterialApp.router(
            title: 'Shadow Browser',
            debugShowCheckedModeBanner: false,
            theme: ShadowTheme.build(),
            routerConfig: router,
            // One light for the whole app, behind every route.
            //
            // Doing this per screen meant the seven that build their own
            // Scaffold — home, the lock screen, onboarding, the browser —
            // stayed flat black while the rest were lit, which reads as two
            // apps rather than one with depth. It also means the drift is
            // continuous across a navigation instead of restarting, so
            // moving between screens does not reset the room.
            builder: (context, child) => Stack(
              children: <Widget>[
                const Positioned.fill(child: AmbientLight()),
                if (child != null) child,
              ],
            ),
          );
        },
      ),
    );
  }
}
