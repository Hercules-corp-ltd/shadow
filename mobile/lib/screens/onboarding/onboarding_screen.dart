import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/blind_colors.dart';
import '../../theme/blind_spacing.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/blind_button.dart';

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

const _slides = <_OnboardingSlide>[
  _OnboardingSlide(
    god: 'ZEUS',
    title: 'Divine Power',
    subtitle: 'Harness the king of gods',
    description:
        'Zeus powers your wallet with ironclad encryption and lightning-fast keypair generation on the Solana network.',
    asset: 'assets/gods/Zeus - Onboarding.svg',
  ),
  _OnboardingSlide(
    god: 'HERMES',
    title: 'Messenger of the Web',
    subtitle: 'Links resolved at light speed',
    description:
        'Hermes turns every URL into a deterministic on-chain token. Your content is reachable by anyone, anywhere, forever.',
    asset: 'assets/gods/Hermes - Onboarding.svg',
  ),
  _OnboardingSlide(
    god: 'ARES',
    title: 'Guardian of Access',
    subtitle: 'Passwordless authentication',
    description:
        'Ares defends every login with Sign-In-With-Solana. Sign a challenge with your key — no passwords, no servers, no breach.',
    asset: 'assets/gods/Ares - Onboarding.svg',
  ),
  _OnboardingSlide(
    god: 'ATHENA',
    title: 'Wisdom of the Web',
    subtitle: 'Search across the pantheon',
    description:
        'Athena indexes every Blind site so you can discover decentralized content instantly — powered by on-chain metadata.',
    asset: 'assets/gods/Athena - Onboarding.svg',
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('blind_onboarding_complete_v1', true);
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
      backgroundColor: BlindColors.background,
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
                        style: BlindTypography.button
                            .copyWith(color: BlindColors.textSecondary),
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
                  horizontal: BlindSpacing.pagePadding,
                  vertical: 24,
                ),
                child: BlindButton(
                  label: isLast ? 'Get Started' : 'Next',
                  trailing: Icons.arrow_forward_rounded,
                  size: BlindButtonSize.lg,
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
              color: _index == i
                  ? BlindColors.primary
                  : BlindColors.border,
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
      padding: const EdgeInsets.symmetric(horizontal: BlindSpacing.pagePadding),
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
            style: BlindTypography.label.copyWith(
              color: BlindColors.primary,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: BlindTypography.displayMd,
          ),
          const SizedBox(height: 8),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: BlindTypography.bodyLg.copyWith(
              color: BlindColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: BlindTypography.bodySm,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
