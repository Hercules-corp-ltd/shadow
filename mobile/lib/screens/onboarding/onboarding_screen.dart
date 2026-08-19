import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_spacing.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/shadow_button.dart';

class _OnboardingSlide {
  final String god;
  final String title;
  final String subtitle;
  final String description;
  final String asset;

  const _OnboardingSlide({
    required this.god,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.asset,
  });
}

/// The four things Shadow actually does, in the order they happen to you.
///
/// ## Why this copy was rewritten
///
/// The first four screens of the app described a different product. Ares
/// promised "Sign-In-With-Solana — no passwords, no servers, no breach";
/// Shadow does not implement SIWS at all, and its identity system is the
/// opposite shape (a derived password per site). Athena promised an index of
/// every Shadow site; there is no index. Hermes promised that every URL
/// becomes "a deterministic on-chain token" reachable "forever"; it does not.
///
/// Those are security claims, on the first screens a new user sees, in a
/// privacy product. Getting them wrong is worse than saying nothing — a user
/// who believes the Ares slide would reasonably conclude that a site breach
/// cannot expose anything of theirs, and act accordingly.
///
/// Everything below is something the app does today and something this repo
/// has a test or a measurement for. Nothing here describes the mail server
/// running on a real domain, per-site storage partitioning, or outbound mail,
/// because none of those are shipped.
const _slides = <_OnboardingSlide>[
  _OnboardingSlide(
    god: 'ZEUS',
    title: 'One phrase',
    subtitle: 'Everything comes from twelve words',
    description:
        'Your wallet and every account Shadow makes for you are computed from '
        'a single recovery phrase. Nothing derived is kept on this phone — it '
        'is worked out again each time you unlock, and your words rebuild all '
        'of it on any device.',
    asset: 'assets/gods/Zeus - Onboarding.svg',
  ),
  _OnboardingSlide(
    god: 'ATHENA',
    title: 'A different you on every site',
    subtitle: 'Nothing worth stealing in a breach',
    description:
        'Each site gets its own password and its own username, worked out '
        'from your phrase rather than stored anywhere. A site that loses its '
        'database loses a password that opens nothing else you own.',
    asset: 'assets/gods/Athena - Onboarding.svg',
  ),
  _OnboardingSlide(
    god: 'HERMES',
    title: 'An address per site',
    subtitle: 'And you can burn one without losing the rest',
    description:
        'Sign-ups get an address that belongs to that site alone, arriving in '
        'a mailbox only your phrase can open. When one starts drawing spam, '
        'replace it — the site you sold it to is the only one affected.',
    asset: 'assets/gods/Hermes - Onboarding.svg',
  ),
  _OnboardingSlide(
    god: 'ARES',
    title: 'Nothing follows you out',
    subtitle: 'Trackers stopped before they load',
    description:
        'Known trackers are blocked at the request, not hidden after the '
        'fact, and third-party cookies never reach the page. Both are '
        'measured on a real device rather than assumed.',
    asset: 'assets/gods/Ares - Onboarding.svg',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  Future<void> _complete() async {
    // Through the provider, not straight at SharedPreferences: the router
    // reads this synchronously on every redirect, so the in-memory copy has
    // to move at the same time as the stored one.
    await context.read<WalletProvider>().markOnboardingComplete();
    if (!mounted) return;
    context.go('/wallet/choose');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GridBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _index == 0
                          ? () => context.go('/welcome')
                          : () => _controller.previousPage(
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeInOut,
                              ),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _complete,
                      child: Text(
                        'Skip',
                        style: ShadowTypography.button
                            .copyWith(color: ShadowColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _SlideContent(slide: _slides[i]),
                ),
              ),
              _buildDots(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ShadowSpacing.pagePadding,
                  vertical: 24,
                ),
                child: ShadowButton(
                  label: isLast ? 'Get Started' : 'Next',
                  trailing: Icons.arrow_forward_rounded,
                  size: ShadowButtonSize.lg,
                  onPressed: () {
                    if (isLast) {
                      _complete();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < _slides.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _index == i ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _index == i ? ShadowColors.primary : ShadowColors.edge,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: ShadowSpacing.pagePadding),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: SvgPicture.asset(
              slide.asset,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            slide.god,
            style: ShadowTypography.label.copyWith(
              color: ShadowColors.primary,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: ShadowTypography.displayMd,
          ),
          const SizedBox(height: 8),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: ShadowTypography.bodyLg.copyWith(
              color: ShadowColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: ShadowTypography.bodySm,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
