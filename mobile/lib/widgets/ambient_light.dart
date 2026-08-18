import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/shadow_colors.dart';

/// The light this app was missing.
///
/// ## Why a background fixes more than the background
///
/// Every card in Shadow is a `GlassCard`: translucent fill, thin bright
/// border, and — until this existed — a 24-pixel backdrop blur. Sitting on
/// `ShadowColors.background`, which is `#000000`, that blur had nothing to
/// work on. Blurring solid black returns solid black, so the whole glass
/// system rendered as flat grey rectangles and paid for a `BackdropFilter` to
/// do it. The same is true of the name: a shadow is what happens when
/// something interrupts light, and there was no light anywhere in the app.
///
/// So this paints one. Two broad pools of warmth and one cold counterweight,
/// far larger than the screen, drifting on periods that do not divide into
/// each other so the pattern never visibly repeats. Everything above it —
/// borders, edges, the translucent fills — starts reading as a surface
/// catching light from somewhere, which is what "glass" was always claiming.
///
/// ## What it refuses to cost
///
/// Motion stops when the platform asks. `MediaQuery.disableAnimations` is set
/// by the OS accessibility switch, and this honours it by painting a single
/// still frame rather than by animating faster — someone who turns that on is
/// often doing it because motion makes them ill.
///
/// It also stops when the app is not in front. A gradient animating at 60fps
/// behind a backgrounded browser is a battery complaint, and this is a
/// privacy tool: a user who notices Shadow near the top of their battery
/// screen has been given a reason to uninstall it that has nothing to do with
/// privacy.
class AmbientLight extends StatefulWidget {
  const AmbientLight({super.key, this.child, this.intensity = 1});

  /// Turn the drift off for the whole app.
  ///
  /// Exists for widget tests. Nothing that animates forever ever lets
  /// `pumpAndSettle` return, so with this on a test that pumps any screen
  /// waits on the background rather than on whatever it meant to assert — and
  /// it fails as a timeout, which says nothing about the cause. Set it false
  /// in `setUpAll` and the light renders one still frame.
  ///
  /// Deliberately not inferred from the binding type: a widget reaching into
  /// the test framework to behave differently under test is how a thing ends
  /// up passing its tests and failing in someone's hand.
  @visibleForTesting
  static bool motion = true;

  final Widget? child;

  /// Scales every pool. 0 is a black screen; above 1 the warmth starts to
  /// compete with content, which is the wrong way round for this app.
  final double intensity;

  @override
  State<AmbientLight> createState() => _AmbientLightState();
}

class _AmbientLightState extends State<AmbientLight>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  double _seconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A raw Ticker rather than an AnimationController: the periods here are
    // half a minute and longer, and driving that through a controller means
    // either a 40-second duration or arithmetic on a 0..1 value that reads
    // worse than the elapsed seconds it is standing in for.
    _ticker = createTicker((elapsed) {
      setState(() => _seconds = elapsed.inMilliseconds / 1000);
    });
    if (AmbientLight.motion) _ticker.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (AmbientLight.motion && !_ticker.isActive) _ticker.start();
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = !AmbientLight.motion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (still && _ticker.isActive) _ticker.stop();

    return RepaintBoundary(
      child: CustomPaint(
        painter: _AmbientPainter(
          // A fixed offset rather than zero, so the still frame is a moment
          // in the drift rather than the one instant where every pool is at
          // its starting corner.
          seconds: still ? 11 : _seconds,
          intensity: widget.intensity,
        ),
        isComplex: true,
        willChange: !still,
        child: widget.child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _Pool {
  const _Pool({
    required this.color,
    required this.radius,
    required this.period,
    required this.phase,
    required this.centre,
    required this.travel,
  });

  final Color color;

  /// Fraction of the shortest screen edge.
  final double radius;

  /// Seconds for one full circuit.
  final double period;
  final double phase;
  final Alignment centre;

  /// How far it wanders, as a fraction of the screen.
  final Offset travel;
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({required this.seconds, required this.intensity});

  final double seconds;
  final double intensity;

  /// Periods deliberately coprime-ish, so the arrangement does not resolve
  /// into an obvious loop while somebody is looking at it.
  static const List<_Pool> _pools = <_Pool>[
    _Pool(
      color: ShadowColors.primary,
      radius: 0.95,
      period: 47,
      phase: 0,
      centre: Alignment(-0.6, -0.85),
      travel: Offset(0.22, 0.10),
    ),
    _Pool(
      color: Color(0xFFFB923C),
      radius: 0.70,
      period: 71,
      phase: 2.1,
      centre: Alignment(0.85, 0.45),
      travel: Offset(-0.16, -0.20),
    ),
    // The cold one. Without it the warm pools read as a phone screen left in
    // the sun; against it they read as a light source in a dark room.
    _Pool(
      color: Color(0xFF3B6FE0),
      radius: 0.85,
      period: 59,
      phase: 4.3,
      centre: Alignment(0.25, 1.05),
      travel: Offset(0.14, -0.12),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = ShadowColors.background);

    final shortest = math.min(size.width, size.height);

    for (final pool in _pools) {
      final t = (seconds / pool.period + pool.phase) * 2 * math.pi;
      final centre = Offset(
        size.width * (0.5 + pool.centre.x / 2) +
            size.width * pool.travel.dx * math.sin(t),
        size.height * (0.5 + pool.centre.y / 2) +
            size.height * pool.travel.dy * math.cos(t * 0.83),
      );
      final radius = shortest * pool.radius;

      // Alpha is low enough that no pool ever becomes a shape. The point is
      // that a surface laid over it picks up a gradient, not that anyone sees
      // a circle.
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              pool.color.withValues(alpha: 0.22 * intensity),
              pool.color.withValues(alpha: 0.07 * intensity),
              pool.color.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    // Pull the corners back down to black. Light in the middle and darkness
    // at the edges is the whole read of the name, and it keeps text near the
    // screen edge on the contrast it was designed against.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[
            Color(0x00000000),
            Color(0x40000000),
            Color(0xB3000000),
          ],
          stops: <double>[0.55, 0.85, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) =>
      old.seconds != seconds || old.intensity != intensity;
}
