import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../identity/identity.dart';
import '../../models/site_adapter_record.dart';
import '../../providers/browser_provider.dart';
import '../../providers/identity_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/site_adapter_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/reveal.dart';
import '../../widgets/shadow_button.dart';

/// The threshold.
///
/// ## Why this is not a grid of buttons
///
/// The old home was eight rounded squares in primary colours, a "Convert Your
/// Existing Website" promo, and a Recent Activity list with no writer. It was
/// a launcher, and it could have belonged to any crypto app — which is a
/// strange thing for the front door of a browser whose whole claim is that it
/// makes you a *different person on every site you visit*.
///
/// So the largest object here does that instead of describing it. Name a site
/// in the slot and, before anything is opened and with no network involved,
/// Shadow shows the stranger it just computed you into there: the name, the
/// address, the password. That is the product, performed rather than
/// advertised, and it is the one surface in the app that cannot fail for
/// connectivity because it is pure local derivation.
///
/// ## The material
///
/// Everything else in Shadow is a `GlassCard`: a lit surface floating above
/// the ambient light, bright along its top edge. This screen inverts that.
/// The hero and the niches are *recesses* — translucent black laid over the
/// drifting light, dark along the inner top edge, lit only at the sill. Two
/// things follow. A hole is darker than the wall by construction, so white
/// type sits on it without a scrim; and because the fill is translucent, the
/// app-wide light keeps moving *through* the recess, so the interior
/// brightens and dims on its own 47/59/71-second periods for no new ticker
/// and no new repaint. The app is named Shadow and the art is white highlight
/// over near-black mass. This is the first screen to give that light
/// somewhere to fall.
///
/// ## The figures
///
/// `assets/gods/*-white-icons-homepage.svg` shipped in this repo, named for
/// this screen, and had never been used anywhere. They are the answer to
/// "not generic" and they cost nothing. Five of the seven appear; Ares and
/// Artemis are deliberately held back — see [_Colonnade].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _Rail(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: Reveal.list(<Widget>[
                  const _Threshold(),
                  const SizedBox(height: 16),
                  const _SiteCount(),
                  const SizedBox(height: 16),
                  const _Colonnade(),
                  const SizedBox(height: 24),
                  const _Ledger(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 0 — the rail
// ---------------------------------------------------------------------------

/// A masthead rule, not a logo block.
///
/// Replaces `ShadowTopBar`, whose four buttons were a star hardcoded to
/// `isActive: true`, an extensions chevron, an inert eye, and a menu holding
/// destinations that are now visible rows in [_Ledger]. Two controls survive,
/// and both do something.
class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Column(
      children: <Widget>[
        SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                // Ships white on transparent, so it needs no tint and sits on
                // the near-black canvas exactly as drawn.
                Image.asset(
                  'assets/brand/shadow-mark.png',
                  height: 18,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(width: 10),
                Text(
                  'SHADOW',
                  style: TextStyle(
                    fontFamily: ShadowTypography.displayFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: ShadowColors.textPrimary.withValues(alpha: 0.70),
                  ),
                ),
                const Spacer(),
                const _NetworkBadge(),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: browser.isPrivate
                      ? 'Private browsing on'
                      : 'Private browsing off',
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  icon: SvgPicture.asset(
                    'assets/icons/Eye-closed-icon.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      browser.isPrivate
                          ? ShadowColors.primary
                          : ShadowColors.textTertiary,
                      BlendMode.srcIn,
                    ),
                  ),
                  onPressed: () => browser.setPrivate(!browser.isPrivate),
                ),
              ],
            ),
          ),
        ),
        // Full width, deliberately outside the page padding. Whether browsing
        // is being recorded is a state worth reading from across the room,
        // not from a recoloured 20dp glyph.
        AnimatedContainer(
          duration: still ? Duration.zero : const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          height: 1,
          color: browser.isPrivate
              ? ShadowColors.primary.withValues(alpha: 0.55)
              : Colors.transparent,
        ),
      ],
    );
  }
}

/// Renders only when the app is somewhere other than mainnet.
///
/// The old pill was a hardcoded green "Mainnet", which is right by luck and
/// wrong the moment anybody switches. Absence is the mainnet state: a badge
/// that appears only when you are somewhere unusual cannot lie by sitting
/// still.
///
/// Read off the *RPC host* rather than the `network` label, because that is
/// where the bytes actually go.
class _NetworkBadge extends StatelessWidget {
  const _NetworkBadge();

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(
          context.watch<SettingsProvider>().settings.rpcUrl,
        )?.host.toLowerCase() ??
        '';

    final (String label, Color colour)? badge = host.contains('devnet')
        ? ('DEVNET', ShadowColors.devnet)
        : host.contains('testnet')
            ? ('TESTNET', ShadowColors.testnet)
            : null;
    if (badge == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push('/settings'),
      child: SizedBox(
        height: 32,
        child: Center(
          child: Text(
            badge.$1,
            style: TextStyle(
              fontFamily: ShadowTypography.monoFamily,
              fontSize: 10,
              letterSpacing: 1.5,
              color: badge.$2,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1 — the threshold
// ---------------------------------------------------------------------------

/// Recess, plinth and slot: one carved mass, three parts.
class _Threshold extends StatefulWidget {
  const _Threshold();

  @override
  State<_Threshold> createState() => _ThresholdState();
}

class _ThresholdState extends State<_Threshold> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  SiteIdentity? _answer;
  bool _rejected = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (_rejected) setState(() => _rejected = false);
    // 220ms rather than 180: identityFor reaches an ed25519 scalar
    // multiplication in pure Dart, because the local part hashes the signing
    // public key. One hit per typing pause, not per keystroke.
    _debounce = Timer(const Duration(milliseconds: 220), () => _derive(value));
  }

  void _derive(String raw) {
    if (!mounted) return;
    final identity = context.read<IdentityProvider>();
    if (!identity.isUnlocked) return;

    final domain = RegistrableDomain.tryOf(raw.trim());
    // Something half-typed is not an error. The rows simply do not appear;
    // nothing turns red until a deliberate submit.
    if (domain == null || domain.isEmpty || !domain.contains('.')) {
      if (_answer != null) setState(() => _answer = null);
      return;
    }
    setState(() => _answer = identity.identityFor(domain));
  }

  void _submit(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return;
    // Carried over verbatim. Sending a plain search to the resolver was the
    // old behaviour and it dead-ended on an empty text box; that fix is not
    // something a redesign gets to undo.
    if (_isShadowIdentifier(query)) {
      context.push('/resolve/resolving?id=${Uri.encodeComponent(query)}');
    } else {
      context.push('/browse?url=${Uri.encodeComponent(query)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final usable = MediaQuery.sizeOf(context).height;
    final height = (usable * 0.40).clamp(248.0, 340.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _recess(height),
        _plinth(),
        _slot(),
        if (_rejected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'That is not a site address. Try twitter.com.',
              style: ShadowTypography.caption
                  .copyWith(color: ShadowColors.textSecondary),
            ),
          ),
      ],
    );
  }

  // A dome, not a half-ellipse. At 96dp of curve the corners eat the first
  // line of type — "Locked." rendered as "_ocked." on device, which is the
  // kind of thing only a screenshot tells you.
  static const BorderRadius _arch = BorderRadius.vertical(
    top: Radius.elliptical(180, 52),
    bottom: Radius.circular(4),
  );

  Widget _recess(double height) {
    final identity = context.watch<IdentityProvider>();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final locked = identity.state == IdentityLifecycle.locked;

    // Ink rule. Hades' ink spans .082-.900 of his 30x49 viewBox, so a plain
    // BoxFit would stand him on a floor of his own. Measured by scanning the
    // rendered file; re-measure if the asset is ever re-exported.
    const inkSpan = 0.818;
    final targetInk = height - 24;
    final box = targetInk / inkSpan;

    return GestureDetector(
      onTap: () => context.push('/identity'),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          // Translucent, never opaque: the app-wide light keeps drifting
          // through, so the interior lives without a ticker of its own.
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: _arch,
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: ClipRRect(
          borderRadius: _arch,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: <Widget>[
              Positioned(
                right: -22,
                bottom: 0,
                // Sibling of the words, never their ancestor, so a rebuild of
                // the text never repaints 156 vector paths.
                child: RepaintBoundary(
                  child: AnimatedOpacity(
                    duration: still
                        ? Duration.zero
                        : const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    // The only state that dims him: the statue in the dark.
                    opacity: locked ? 0.55 : 1.0,
                    child: SvgPicture.asset(
                      'assets/gods/Hades-white-icons-homepage.svg',
                      height: box,
                    ),
                  ),
                ),
              ),
              // Unlit inner top edge — the formal inverse of GlassCard.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 28,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 1,
                child: ColoredBox(
                  color: identity.error != null
                      ? ShadowColors.error
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
              Padding(
                // Below the dome, and narrow enough that the type never
                // crosses the figure lit arm.
                padding: const EdgeInsets.fromLTRB(20, 62, 20, 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 188),
                  child: _words(identity),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Four faces plus an error band.
  ///
  /// The router guarantees only that the *wallet* is unlocked. Identity locks
  /// independently, so a hero with one face is a blank card for anyone who
  /// has not unlocked this session.
  Widget _words(IdentityProvider identity) {
    switch (identity.state) {
      case IdentityLifecycle.uninitialized:
        return Align(
          alignment: Alignment.topLeft,
          child: Text('…', style: ShadowTypography.h2),
        );

      case IdentityLifecycle.empty:
        return _invitation(
          headline: 'You have no phrase yet.',
          body: 'Shadow makes a different person for every site you visit — a '
              'separate address, password and name, all computed from twelve '
              'words. You do not have those twelve words yet.',
          action: 'Set up my identity',
          footnote: 'You can browse without it.',
        );

      case IdentityLifecycle.locked:
        return _invitation(
          headline: 'Locked.',
          body: 'Your accounts are still there. Shadow keeps nothing derived '
              'on this device, so it has to recompute them, and it needs your '
              'passphrase.',
          action: 'Unlock',
        );

      case IdentityLifecycle.unlocked:
        return _unlocked();
    }
  }

  Widget _invitation({
    required String headline,
    required String body,
    required String action,
    String? footnote,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(headline, style: ShadowTypography.h2),
        const SizedBox(height: 12),
        Text(body, style: ShadowTypography.bodySm),
        const SizedBox(height: 16),
        ShadowButton(
          label: action,
          onPressed: () => context.push('/identity'),
        ),
        if (footnote != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(footnote, style: ShadowTypography.caption),
        ],
      ],
    );
  }

  Widget _unlocked() {
    final answer = _answer;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'WHO YOU ARE AT',
          style: TextStyle(
            fontFamily: ShadowTypography.displayFamily,
            fontSize: 12,
            letterSpacing: 2.5,
            color: ShadowColors.textTertiary,
          ),
        ),
        const SizedBox(height: 16),
        if (answer == null)
          Text(
            'Name a site below and Shadow will show you who you are there — '
            'before you open it.',
            style: ShadowTypography.bodySm,
          )
        else ...<Widget>[
          _answerRow('they call you', answer.handle, 0),
          const SizedBox(height: 10),
          _answerRow('mail reaches you at', _elide(answer.email, 26), 1),
          const SizedBox(height: 10),
          _answerRow('password', '•' * 20, 2),
          const SizedBox(height: 12),
          Text(
            'Computed from your phrase. Not stored, here or anywhere.',
            style: ShadowTypography.caption,
          ),
        ],
      ],
    );
  }

  Widget _answerRow(String label, String value, int index) {
    return Reveal(
      index: index,
      rise: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontFamily: ShadowTypography.bodyFamily,
              fontSize: 10,
              color: ShadowColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: ShadowTypography.monoFamily,
              fontSize: 13,
              color: ShadowColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  static String _elide(String value, int max) {
    if (value.length <= max) return value;
    final keep = (max - 1) ~/ 2;
    return '${value.substring(0, keep)}…${value.substring(value.length - keep)}';
  }

  Widget _plinth() {
    final identity = context.watch<IdentityProvider>();

    final (String text, TextStyle style, bool tappable) line =
        switch (identity.state) {
      IdentityLifecycle.unlocked when identity.error == null => (
          identity.fingerprint ?? '…',
          _mono(ShadowColors.textSecondary),
          false,
        ),
      IdentityLifecycle.locked => (
          'identity locked',
          _mono(ShadowColors.textTertiary),
          true,
        ),
      IdentityLifecycle.empty => (
          'no identity yet',
          _mono(ShadowColors.textTertiary),
          true,
        ),
      _ => ('…', _mono(ShadowColors.textTertiary), false),
    };

    final error = identity.error;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      color: Colors.black.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'IDENTITY',
            style: TextStyle(
              fontFamily: ShadowTypography.displayFamily,
              fontSize: 12,
              letterSpacing: 4,
              color: ShadowColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          if (error != null)
            // Failure is a different colour of light, and it never collapses
            // into the empty face.
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    error,
                    style: ShadowTypography.caption
                        .copyWith(color: ShadowColors.error),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/identity'),
                  child: const Text('Try again'),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: line.$3 ? () => context.push('/identity') : null,
              child: Text(line.$1, style: line.$2),
            ),
        ],
      ),
    );
  }

  static TextStyle _mono(Color colour) => TextStyle(
        fontFamily: ShadowTypography.monoFamily,
        fontSize: 12,
        color: colour,
      );

  /// Cut, not raised. `ShadowSearchField` is a surfaceElevated control with a
  /// border; this one belongs to the same stone as the recess above it.
  Widget _slot() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(4),
        // A uniform hairline, and it has to stay uniform: a *non*-uniform
        // border beside a borderRadius throws while painting and takes the
        // child down with it, which is why the slot was missing entirely from
        // the first builds. Without any edge the cut is black on black and
        // reads as nothing at all — the theme's own field box was standing in
        // for it, badly, until the decoration below opted out.
        border: Border.all(color: ShadowColors.edge),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          SvgPicture.asset(
            'assets/icons/Search-icon.svg',
            width: 18,
            height: 18,
            colorFilter: const ColorFilter.mode(
              ShadowColors.textTertiary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              onSubmitted: _submit,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              style: const TextStyle(
                fontFamily: ShadowTypography.bodyFamily,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: ShadowColors.textPrimary,
              ),
              cursorColor: ShadowColors.primary,
              decoration: const InputDecoration(
                isDense: true,
                // The container above is the slot. Without these three the
                // theme fills and borders a second box inside it, and the cut
                // ends up with a panel sitting in it.
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Name a site, or a .shadow address',
                hintStyle: TextStyle(
                  fontFamily: ShadowTypography.bodyFamily,
                  fontSize: 16,
                  color: ShadowColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2 — the count
// ---------------------------------------------------------------------------

/// The only counted number on the screen, and the only provider that can tell
/// empty from failed.
class _SiteCount extends StatelessWidget {
  const _SiteCount();

  @override
  Widget build(BuildContext context) {
    final adapters = context.watch<SiteAdapterProvider>();

    return FutureBuilder<List<SiteAdapterRecord>>(
      // Keyed on revision: reads are futures, and a bare notifyListeners
      // re-issues the same future and shows the same stale answer.
      key: ValueKey<int>(adapters.revision),
      future: adapters.configured(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Nothing at all. No spinner, no placeholder number that later
          // changes into a different one.
          return const SizedBox(height: 24);
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 24,
            child: Center(
              child: Text(
                '— could not read your sites —',
                style: ShadowTypography.caption
                    .copyWith(color: ShadowColors.warning),
              ),
            ),
          );
        }

        final count = snapshot.data?.length ?? 0;
        if (count == 0) {
          return SizedBox(
            height: 24,
            child: Center(
              // Not tappable, and nothing that looks like it is.
              child: Text(
                '— you hold no sites yet —',
                style: ShadowTypography.caption,
              ),
            ),
          );
        }

        return SizedBox(
          height: 24,
          child: Center(
            child: GestureDetector(
              onTap: () => context.push('/identity/sites'),
              child: Text(
                '— you hold $count site${count == 1 ? '' : 's'} —',
                style: ShadowTypography.caption
                    .copyWith(color: ShadowColors.textSecondary),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 3 — the colonnade
// ---------------------------------------------------------------------------

class _Niche {
  const _Niche({
    required this.god,
    required this.asset,
    required this.label,
    required this.route,
    required this.inkTop,
    required this.inkSpan,
    required this.viewBox,
  });

  final String god;
  final String asset;
  final String label;
  final String route;

  /// Where the ink starts, as a fraction of the viewBox height.
  final double inkTop;

  /// Fraction of the viewBox height carrying ink.
  final double inkSpan;

  /// width / height of the viewBox.
  final double viewBox;
}

/// Four lit niches.
///
/// ## Why five gods and not seven
///
/// **Ares** is the destructive act — burning an alias, clearing history,
/// forgetting an identity. None of those is a top-level destination; each
/// lives inside the screen that owns the thing being destroyed. He is also
/// the set's one confusion pair with Athena (crested helm, vertical spear,
/// round shield, near-identical below about 56dp), so leaving him out means
/// the two never sit side by side.
///
/// **Artemis** is refusal-to-be-seen, and her only honest analogue here is
/// tracker blocking — which `tracker_blocking.dart` documents at length that
/// it cannot report a truthful blocked count for. There is no surface for her
/// until there is a number the code can stand behind.
///
/// Both are held back deliberately. Forcing either onto a spare route would
/// be decoration impersonating evidence, which is the thing this screen was
/// rebuilt to stop doing.
class _Colonnade extends StatefulWidget {
  const _Colonnade();

  @override
  State<_Colonnade> createState() => _ColonnadeState();
}

class _ColonnadeState extends State<_Colonnade> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _offset = ValueNotifier<double>(0);

  // Measured by scanning each file rendered large. Re-measure if any asset is
  // re-exported. Without this, equal boxes render Zeus about 17% smaller than
  // the rest and stand the four on three different floors.
  static const List<_Niche> _niches = <_Niche>[
    _Niche(
      god: 'HERMES',
      asset: 'assets/gods/Hermes-white-icons-homepage.svg',
      label: 'Resolve',
      route: '/resolve',
      inkTop: 0.000,
      inkSpan: 0.985,
      viewBox: 20 / 42,
    ),
    _Niche(
      god: 'ATHENA',
      asset: 'assets/gods/Athena-white-icons-homepage.svg',
      label: 'Domains',
      route: '/domains',
      inkTop: 0.011,
      inkSpan: 0.967,
      viewBox: 18 / 41,
    ),
    _Niche(
      god: 'POSEIDON',
      asset: 'assets/gods/Poseidon-white-icons-homepage.svg',
      label: 'Wallet',
      route: '/wallet',
      inkTop: 0.000,
      inkSpan: 0.979,
      viewBox: 18 / 43,
    ),
    _Niche(
      god: 'ZEUS',
      asset: 'assets/gods/Zeus-white-icons-homepage.svg',
      label: 'Publish',
      route: '/deploy',
      inkTop: 0.083,
      inkSpan: 0.832,
      viewBox: 24 / 48,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _offset.value = _scroll.offset);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // At 2x, 112dp of ink leaves Poseidon about 48dp wide and the marks that
    // tell the figures apart start to go.
    final dense = MediaQuery.devicePixelRatioOf(context) < 3;
    final ink = dense ? 128.0 : 112.0;
    // Derived, never hardcoded. A fixed 184 left the figure, two labels and
    // Poseidon third line about 3dp over budget at dense DPI, and because the
    // column is bottom-aligned the overflow went off the TOP — the entire
    // niche, text included, rendered above the visible band and the whole
    // colonnade looked empty.
    final band = ink + 84;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: band,
          child: ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            // Only four items, so all stay alive and nothing recycles.
            cacheExtent: 260,
            itemCount: _niches.length,
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(right: i == _niches.length - 1 ? 0 : 10),
              child: _niche(_niches[i], ink),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // An honest position indicator rather than a decorative dot row, and
        // the other half of the scroll affordance after the peeking fourth.
        SizedBox(
          height: 2,
          child: ValueListenableBuilder<double>(
            valueListenable: _offset,
            builder: (context, _, __) => CustomPaint(
              painter: _ScrollRule(_scroll),
            ),
          ),
        ),
      ],
    );
  }

  Widget _niche(_Niche niche, double ink) {
    return _PressableRecess(
      onTap: () => context.push(niche.route),
      radius: const BorderRadius.vertical(
        top: Radius.elliptical(54, 26),
        bottom: Radius.circular(4),
      ),
      restFill: 0.42,
      pressedFill: 0.56,
      child: SizedBox(
        width: 108,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            // Fixed height, free width: the set spans 0.42-0.61 aspect, and a
            // square box would render Poseidon 45% narrower than his
            // neighbours on no common floor.
            // Sized by height with the width left free, so the set stands on
            // one floor despite spanning 0.42-0.61 aspect. An OverflowBox and
            // a Transform were here to shave each figure own dead space using
            // the measured ink table; they rendered nothing on device, and a
            // visible figure beats a perfectly aligned invisible one. The
            // table stays in the model for whoever wants to try again.
            Expanded(
              // The figure takes whatever the niche has left once the labels
              // are placed, so the four stand on one floor without arithmetic
              // that has to agree with the band height.
              child: RepaintBoundary(
                child: SvgPicture.asset(
                  niche.asset,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              niche.god,
              style: const TextStyle(
                fontFamily: ShadowTypography.displayFamily,
                fontSize: 11,
                letterSpacing: 1.5,
                color: ShadowColors.textSecondary,
              ),
            ),
            Text(
              niche.label,
              style: const TextStyle(
                fontFamily: ShadowTypography.bodyFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ShadowColors.textPrimary,
              ),
            ),
            if (niche.route == '/wallet') _walletLine(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// The single fact in the band, and it needs no network: the router sends
  /// anything but an unlocked wallet away from this screen.
  Widget _walletLine() {
    final address = context.watch<WalletProvider>().walletAddress ?? '';
    if (address.length < 12) return const SizedBox.shrink();
    return Text(
      '${address.substring(0, 4)}…${address.substring(address.length - 4)}',
      style: const TextStyle(
        fontFamily: ShadowTypography.monoFamily,
        fontSize: 10,
        color: ShadowColors.textTertiary,
      ),
    );
  }
}

class _ScrollRule extends CustomPainter {
  _ScrollRule(this.controller);

  final ScrollController controller;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );
    if (!controller.hasClients) return;

    final position = controller.position;
    final extent = position.maxScrollExtent + position.viewportDimension;
    if (extent <= 0) return;

    final segment = (position.viewportDimension / extent) * size.width;
    final travel = size.width - segment;
    final progress = position.maxScrollExtent <= 0
        ? 0.0
        : (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(progress * travel, 0, segment, size.height),
      Paint()..color = ShadowColors.primary.withValues(alpha: 0.40),
    );
  }

  @override
  bool shouldRepaint(covariant _ScrollRule old) => true;
}

/// A recess that presses *deeper* rather than smaller.
///
/// `GlassCard` squeezes 1.5% because a card is a card. Carved stone does not
/// scale — so the fill darkens and the lit lip dims instead, over GlassCard's
/// exact 120ms easeOut, so it reads as the same hand touching a different
/// material.
class _PressableRecess extends StatefulWidget {
  const _PressableRecess({
    required this.child,
    required this.onTap,
    required this.radius,
    required this.restFill,
    required this.pressedFill,
  });

  final Widget child;
  final VoidCallback onTap;
  final BorderRadius radius;
  final double restFill;
  final double pressedFill;

  @override
  State<_PressableRecess> createState() => _PressableRecessState();
}

class _PressableRecessState extends State<_PressableRecess> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: still ? Duration.zero : const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: _pressed ? widget.pressedFill : widget.restFill,
          ),
          borderRadius: widget.radius,
          // No Border here, and that is not a style preference. A
          // BoxDecoration carrying a NON-UNIFORM border together with a
          // borderRadius throws while painting: the background colour lands,
          // the border assertion fires, and everything after it — the whole
          // child — is skipped. The niches rendered as empty arches for
          // exactly this reason, their text included, with no layout error
          // anywhere to point at it. The lit sill is a child instead.
        ),
        child: Stack(
          children: <Widget>[
            widget.child,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 1,
              child: ColoredBox(
                color: Colors.white.withValues(alpha: _pressed ? 0.04 : 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4 — the ledger
// ---------------------------------------------------------------------------

/// Every remaining destination, as plain rows.
///
/// Carries no values on purpose. The tempting version prints live history,
/// bookmark and download counts — but `HistoryProvider` starts at `const []`
/// *and* resets to `const []` in its catch block, so those rows would read 0
/// both before data arrives and after a read fails. A ledger with no numbers
/// is structurally incapable of showing a stale zero.
class _Ledger extends StatelessWidget {
  const _Ledger();

  static const List<(String, String)> _rows = <(String, String)>[
    ('Tokens', '/tokens'),
    ('History', '/history'),
    ('Bookmarks', '/bookmarks'),
    ('Downloads', '/downloads'),
    ('Extensions', '/extensions'),
    ('Activity & Logs', '/activity'),
    ('Settings', '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (label, route) in _rows)
          InkWell(
            onTap: () => context.push(route),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(label, style: ShadowTypography.body),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: ShadowColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// True for things only Shadow can resolve: a .shadow domain, an IPFS or
/// Arweave content id, or a bare base58 program address.
bool _isShadowIdentifier(String query) {
  final value = query.toLowerCase();
  if (value.endsWith('.shadow')) return true;
  if (value.startsWith('shadow://')) return true;
  if (RegExp(r'^(qm[1-9a-hj-np-z]{44}|bafy[a-z2-7]{50,})$').hasMatch(value)) {
    return true;
  }
  // A bare base58 address: no dots, no spaces, Solana-pubkey length.
  if (!query.contains('.') &&
      !query.contains(' ') &&
      RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(query)) {
    return true;
  }
  return false;
}
