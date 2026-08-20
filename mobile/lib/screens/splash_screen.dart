import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_typography.dart';
import '../widgets/grid_background.dart';

/// Says something when boot does not finish.
///
/// The router holds the user on the splash for exactly as long as
/// WalletProvider reports isLoading, and _bootstrap has no catch — so a throw
/// in there leaves isLoading true for ever. The screen showed a spinner and
/// nothing else, identically, whether boot was in progress or dead.
class _SlowBootNotice extends StatefulWidget {
  const _SlowBootNotice();

  @override
  State<_SlowBootNotice> createState() => _SlowBootNoticeState();
}

class _SlowBootNoticeState extends State<_SlowBootNotice> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    // Long enough that a cold start on a slow phone never sees it.
    _timer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_slow) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        'This is taking longer than it should. If it does not move, close '
        'Shadow and open it again — your wallet and phrase are untouched.',
        textAlign: TextAlign.center,
        style: ShadowTypography.bodySm,
      ),
    );
  }
}

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
              // The router pins the user here for as long as the wallet
              // provider reports isLoading, and this screen had no way to say
              // anything but "working". If bootstrap throws, isLoading is
              // never cleared and the spinner turns for ever with no text, no
              // retry, and no way out. After ten seconds it says so.
              const SizedBox(height: 20),
              const _SlowBootNotice(),
            ],
          ),
        ),
      ),
    );
  }
}
