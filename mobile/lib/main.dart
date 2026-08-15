import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/activity_provider.dart';
import 'providers/bookmarks_provider.dart';
import 'providers/deploy_provider.dart';
import 'providers/domains_provider.dart';
import 'providers/downloads_provider.dart';
import 'providers/extensions_provider.dart';
import 'providers/history_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/tokens_provider.dart';
import 'providers/wallet_provider.dart';
import 'router/app_router.dart';
import 'theme/blind_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(BlindTheme.overlayStyle);
  runApp(const BlindApp());
}

class BlindApp extends StatelessWidget {
  const BlindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => BookmarksProvider()),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ChangeNotifierProvider(create: (_) => ExtensionsProvider()),
        ChangeNotifierProvider(create: (_) => DomainsProvider()),
        ChangeNotifierProvider(create: (_) => TokensProvider()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
        ChangeNotifierProvider(create: (_) => DeployProvider()),
      ],
      child: Builder(
        builder: (ctx) {
          final router = AppRouter.build(ctx);
          return MaterialApp.router(
            title: 'Blind Browser',
            debugShowCheckedModeBanner: false,
            theme: BlindTheme.build(),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
