import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/shadow_colors.dart';
import '../../theme/shadow_spacing.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/shadow_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _skipToWallet(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shadow_onboarding_complete_v1', true);
    if (!context.mounted) return;
    context.go('/wallet/choose');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShadowColors.background,
      body: GridBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ShadowSpacing.pagePadding,
              vertical: 32,
            ),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'S',
                    style: ShadowTypography.displayXL.copyWith(
                      color: Colors.black,
                      fontSize: 72,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
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
                  'A browser worth of the gods',
                  textAlign: TextAlign.center,
                  style: ShadowTypography.bodyLg,
                ),
                const SizedBox(height: 12),
                Text(
                  'Experience divine speed, wisdom, and power in your\n'
                  'browsing journey. Let us guide you through the\n'
                  'features that make Olympus extraordinary.',
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
    );
  }
}
