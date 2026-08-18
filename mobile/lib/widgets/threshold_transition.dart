import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';

/// Going through the door, rather than sliding a card over it.
///
/// ## Why this exists
///
/// A platform push says "here is another screen". Shadow's home screen is
/// built as a *threshold* — an arched recess with the light behind it and a
/// slot beneath where you name a site — so the one moment the whole page is
/// arranged around is the moment you go through. A right-to-left slide throws
/// that away and makes the front door feel like a settings list.
///
/// So the web page arrives the way something arrives through a doorway: an
/// arch opens from the slot, widens until it is the whole screen, and the page
/// is revealed inside it. The home screen behind falls away and dims rather
/// than sliding, so the eye reads depth instead of lateral motion.
///
/// ## Why it is a clip and not an image
///
/// Nothing is generated or pre-rendered. The arch is the same
/// `BorderRadius.vertical(top: elliptical)` the hero recess uses, drawn as a
/// path and animated — so it stays crisp at any size, costs one clip per
/// frame, and cannot drift out of step with the screen it is quoting. A
/// bitmap of an arch would be a second source of truth for a shape the app
/// already defines in code.
///
/// ## What it refuses to do
///
/// It honours `MediaQuery.disableAnimations` by handing back the child with a
/// plain fade, because a shape expanding across the whole screen is exactly
/// the kind of motion that switch exists to stop. And it never animates the
/// *outgoing* browser back through the arch on pop: leaving is not an arrival,
/// and a door that closes as theatrically as it opens gets tiring by the third
/// time.
class ThresholdTransition extends StatelessWidget {
  const ThresholdTransition({
    super.key,
    required this.animation,
    required this.child,
    this.origin = const Alignment(0, 0.42),
  });

  final Animation<double> animation;
  final Widget child;

  /// Where the arch opens from, in the -1..1 alignment space. Defaults to the
  /// slot's position on the home screen, so the door opens where the address
  /// was typed rather than from the middle of nowhere.
  final Alignment origin;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return FadeTransition(opacity: animation, child: child);
    }

    // Two curves, deliberately different. The opening leads — it is the
    // subject — and the content fades in behind it a beat later so the arch
    // reads as a hole being cut rather than as a mask sliding off a picture.
    final opening = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
    );
    final contents = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.25, 1, curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: opening,
      builder: (context, _) {
        return Stack(
          children: <Widget>[
            // A warm rim on the leading edge of the opening, brightest at the
            // start and gone by the time the door is wide. It is the light the
            // rest of the app already sits in, caught on a moving edge.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ArchRim(
                    t: opening.value,
                    origin: origin,
                  ),
                ),
              ),
            ),
            ClipPath(
              clipper: _ArchClipper(t: opening.value, origin: origin),
              child: FadeTransition(opacity: contents, child: child),
            ),
          ],
        );
      },
    );
  }
}

/// The opening itself.
///
/// At t=0 it is a slot-width arch sitting where the address field was; at t=1
/// it is larger than the screen in both directions, so the last frame has no
/// visible edge and the page is simply there.
class _ArchClipper extends CustomClipper<Path> {
  const _ArchClipper({required this.t, required this.origin});

  final double t;
  final Alignment origin;

  @override
  Path getClip(Size size) => _archPath(size, t, origin);

  @override
  bool shouldReclip(covariant _ArchClipper old) =>
      old.t != t || old.origin != origin;
}

class _ArchRim extends CustomPainter {
  const _ArchRim({required this.t, required this.origin});

  final double t;
  final Alignment origin;

  @override
  void paint(Canvas canvas, Size size) {
    // Fades out over the first two thirds. By the time the arch is near the
    // screen edges it is a line of light travelling off the display, and
    // holding it to the end would just be a border.
    final strength = (1 - (t / 0.66)).clamp(0.0, 1.0);
    if (strength <= 0) return;

    canvas.drawPath(
      _archPath(size, t, origin),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ShadowColors.primary.withValues(alpha: 0.55 * strength)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * strength),
    );
  }

  @override
  bool shouldRepaint(covariant _ArchRim old) =>
      old.t != t || old.origin != origin;
}

/// The shape both the clip and the rim use, so they can never disagree.
Path _archPath(Size size, double t, Alignment origin) {
  final centre = Offset(
    size.width * (0.5 + origin.x / 2),
    size.height * (0.5 + origin.y / 2),
  );

  // Grows past the far corner so the final frame is edge-free whatever the
  // origin is. Squared easing keeps the first third slow — that is where the
  // arch is legible as an arch.
  final reach = math.sqrt(
        math.pow(math.max(centre.dx, size.width - centre.dx), 2) +
            math.pow(math.max(centre.dy, size.height - centre.dy), 2),
      ) *
      1.08;

  final half = (28 + (reach - 28) * t * t).clamp(28.0, reach);
  // Slightly taller than wide throughout, which is what keeps it reading as a
  // doorway rather than as a circle wipe.
  final height = half * 2.05;
  final rect = Rect.fromCenter(
    center: Offset(centre.dx, centre.dy - height * 0.12),
    width: half * 2,
    height: height,
  );

  return Path()
    ..addRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.elliptical(half, half * 0.62),
        topRight: Radius.elliptical(half, half * 0.62),
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ),
    );
}

/// The home screen receding while the door opens.
///
/// Kept separate so the outgoing page can be given depth without the incoming
/// page having to know anything about it: it falls back and dims, which is
/// what makes the arch read as something you move *through* rather than a
/// shape drawn on top.
class ThresholdDeparture extends StatelessWidget {
  const ThresholdDeparture({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;

    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
    );

    return AnimatedBuilder(
      animation: curve,
      builder: (context, inner) {
        final t = curve.value;
        return Transform.scale(
          // Only 4%. Enough to read as receding; more and it announces itself.
          scale: 1 - 0.04 * t,
          child: Opacity(opacity: 1 - 0.55 * t, child: inner),
        );
      },
      child: child,
    );
  }
}
