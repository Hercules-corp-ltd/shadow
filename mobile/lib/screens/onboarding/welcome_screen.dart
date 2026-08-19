import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_spacing.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/shadow_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _skipToWallet(BuildContext context) async {
    // Same as onboarding: the flag is only worth writing if the router can
    // see it, and the router cannot await.
    await context.read<WalletProvider>().markOnboardingComplete();
    if (!context.mounted) return;
    context.go('/wallet/choose');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Scrollable with a floor, rather than a bare Column.
      //
      // This screen overflowed by 142 pixels on a 360x640 phone — the two
      // Spacers cannot give back space that is not there, so "Begin Your
      // Journey" and "Skip for now" were both pushed off the bottom. On a
      // small handset the first screen of the app had no way forward. It is a
      // widget test that found it, because once a wallet exists the router
      // sends /welcome to /home and nobody opens this again.
      //
      // On a tall screen the ConstrainedBox floor keeps the Spacers doing
      // their job, so the composition is unchanged where it already fitted.
      body: GridBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ShadowSpacing.pagePadding,
                      vertical: 32,
                    ),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        // The real mark, which has shipped in the bundle the whole
                        // time. This was a solid white disc with the letter "S" set
                        // in it — a placeholder for a logo that already existed, on
                        // the first screen anyone ever sees, and the only pure-white
                        // object in an app that is otherwise black.
                        Image.asset(
                          'assets/brand/shadow-mark.png',
                          width: 132,
                          height: 132,
                          filterQuality: FilterQuality.medium,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'WELCOME\nTO\nSHADOW',
                          textAlign: TextAlign.center,
                          style: ShadowTypography.displayLg.copyWith(
                            fontSize: 44,
                            letterSpacing: 4,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'A browser worthy of the gods',
                          textAlign: TextAlign.center,
                          style: ShadowTypography.bodyLg,
                        ),
                        const SizedBox(height: 12),
                        // "Olympus" appeared nowhere else in the product —
                        // not the mark, not the masthead, not a route, not the
                        // package name — so the first screen introduced the
                        // app under a name it does not have. "Divine speed"
                        // was a performance claim nothing here measures.
                        Text(
                          'One phrase. A different you on every site.\n'
                          'Nothing derived is kept on this device.',
                          textAlign: TextAlign.center,
                          style: ShadowTypography.bodySm,
                        ),
                        const Spacer(flex: 3),
                        ShadowButton(
                          label: 'Begin Your Journey',
                          onPressed: () => context.go('/onboarding'),
                          size: ShadowButtonSize.lg,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => _skipToWallet(context),
                          child: Text(
                            'Skip for now',
                            style: ShadowTypography.button.copyWith(
                              color: ShadowColors.textSecondary,
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
