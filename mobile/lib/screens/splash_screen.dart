import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_typography.dart';
import '../widgets/grid_background.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GridBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Center(
                  child: Text(
                    'S',
                    style: ShadowTypography.displayXL
                        .copyWith(fontSize: 56, color: Colors.white),
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fadeIn(duration: 600.ms)
                  .scale(duration: 1600.ms, begin: const Offset(0.98, 0.98)),
              const SizedBox(height: 24),
              Text('SHADOW',
                      style: ShadowTypography.displayLg
                          .copyWith(letterSpacing: 6))
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 600.ms),
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
