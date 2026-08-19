import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_typography.dart';
import '../widgets/grid_background.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The Android and iOS launch screens now paint this same mark on black,
    // so the handover from the OS splash to the first Flutter frame should be
    // the same image in the same place rather than a cut to a different one.
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final mark = Image.asset(
      'assets/brand/shadow-mark.png',
      width: 112,
      height: 112,
      filterQuality: FilterQuality.medium,
    );

    final wordmark = Text('SHADOW',
        style: ShadowTypography.displayLg.copyWith(letterSpacing: 6));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GridBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The breathing loop is skipped outright when the platform asks
              // for reduced motion — a slow repeating scale is exactly what
              // that switch exists to stop, and it ran forever here because
              // nothing after the splash ever cancels it.
              if (still)
                mark
              else
                mark
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fadeIn(duration: 600.ms)
                    .scale(duration: 1600.ms, begin: const Offset(0.98, 0.98)),
              const SizedBox(height: 24),
              if (still)
                wordmark
              else
                wordmark.animate().fadeIn(delay: 200.ms, duration: 600.ms),
              const SizedBox(height: 16),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ShadowColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
