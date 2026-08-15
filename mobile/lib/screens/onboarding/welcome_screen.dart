import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/blind_colors.dart';
import '../../theme/blind_spacing.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/blind_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _skipToWallet(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('blind_onboarding_complete_v1', true);
    if (!context.mounted) return;
    context.go('/wallet/choose');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlindColors.background,
      body: GridBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BlindSpacing.pagePadding,
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
                    style: BlindTypography.displayXL.copyWith(
                      color: Colors.black,
                      fontSize: 72,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'WELCOME\nTO\nSHADOW',
                  textAlign: TextAlign.center,
                  style: BlindTypography.displayLg.copyWith(
                    fontSize: 44,
                    letterSpacing: 4,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'A browser worth of the gods',
                  textAlign: TextAlign.center,
                  style: BlindTypography.bodyLg,
                ),
                const SizedBox(height: 12),
                Text(
                  'Experience divine speed, wisdom, and power in your\n'
                  'browsing journey. Let us guide you through the\n'
                  'features that make Olympus extraordinary.',
                  textAlign: TextAlign.center,
                  style: BlindTypography.bodySm,
                ),
                const Spacer(flex: 3),
                BlindButton(
                  label: 'Begin Your Journey',
                  onPressed: () => context.go('/onboarding'),
                  size: BlindButtonSize.lg,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => _skipToWallet(context),
                  child: Text(
                    'Skip for now',
                    style: BlindTypography.button.copyWith(
                      color: BlindColors.textSecondary,
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
