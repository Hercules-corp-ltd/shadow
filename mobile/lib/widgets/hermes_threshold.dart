import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_typography.dart';
import 'grid_background.dart';

/// How long the Greek doors take to part (slow-motion threshold).
const kHermesGateOpenDuration = Duration(milliseconds: 3200);

/// Total time on the gate screen after biometrics — open animation + a beat.
const kHermesGateHold = Duration(milliseconds: 5800);

/// Hermes at the gate — full-screen Greek doors, closed then parting.
class HermesThreshold extends StatefulWidget {
  const HermesThreshold({super.key});

  @override
  State<HermesThreshold> createState() => _HermesThresholdState();
}

class _HermesThresholdState extends State<HermesThreshold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gate;

  @override
  void initState() {
    super.initState();
    _gate = AnimationController(
      vsync: this,
      duration: kHermesGateOpenDuration,
    );
    // Run as soon as this screen is visible — no delay, no hidden content.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _gate.forward();
    });
  }

  @override
  void dispose() {
    _gate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final doorWidth = screenWidth / 2 + 3;

    return Material(
      color: ShadowColors.background,
      child: AnimatedBuilder(
        animation: _gate,
        builder: (context, child) {
          final t = Curves.easeInOutQuart.transform(_gate.value);
          final pedimentOpacity = (1 - t * 1.25).clamp(0.0, 1.0);
          final seamGlow = (1 - t) * 0.75;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Grid + Hermes copy always rendered underneath the doors.
              child!,
              // Pediment
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: screenWidth / 2 - doorWidth + 3,
                width: doorWidth * 2 - 6,
                child: Opacity(
                  opacity: pedimentOpacity,
                  child: Transform.translate(
                    offset: Offset(0, -20 * t),
                    child: _GreekPediment(width: doorWidth * 2 - 6),
                  ),
                ),
              ),
              // Center seam light
              if (seamGlow > 0.04)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 3,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            ShadowColors.primary.withValues(alpha: 0),
                            ShadowColors.primary.withValues(alpha: seamGlow),
                            ShadowColors.primary.withValues(alpha: 0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ShadowColors.primary
                                .withValues(alpha: seamGlow * 0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Left door — slides left (no 3D — reliable on all devices).
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: doorWidth,
                child: Transform.translate(
                  offset: Offset(-doorWidth * t, 0),
                  child: CustomPaint(
                    painter: _GreekGateDoorPainter(isLeft: true),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              // Right door — slides right
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: doorWidth,
                child: Transform.translate(
                  offset: Offset(doorWidth * t, 0),
                  child: CustomPaint(
                    painter: _GreekGateDoorPainter(isLeft: false),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          );
        },
        child: GridBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const _HermesSigil(),
                  const SizedBox(height: 36),
                  Text(
                    'THE THRESHOLD',
                    textAlign: TextAlign.center,
                    style: ShadowTypography.caption.copyWith(
                      letterSpacing: 4,
                      color: ShadowColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hermes recognizes the traveller.',
                    textAlign: TextAlign.center,
                    style: ShadowTypography.displayMd.copyWith(
                      fontSize: 22,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The gate opens — no password, only your sign.',
                    textAlign: TextAlign.center,
                    style: ShadowTypography.bodySm,
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GreekPediment extends StatelessWidget {
  const _GreekPediment({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, 44),
      painter: _GreekPedimentPainter(),
    );
  }
}

class _GreekPedimentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const bronze = ShadowColors.primary;
    const marble = Color(0xFF2A2724);

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A3530), marble],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = bronze.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GreekGateDoorPainter extends CustomPainter {
  _GreekGateDoorPainter({required this.isLeft});

  final bool isLeft;

  static const _marbleBase = Color(0xFF252220);
  static const _marbleMid = Color(0xFF33302C);
  static const _marbleHi = Color(0xFF454139);

  @override
  void paint(Canvas canvas, Size size) {
    const bronze = ShadowColors.primary;
    final innerEdge = isLeft ? size.width : 0.0;

    // Solid marble — must cover fully so nothing behind reads as blank.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          colors: const [_marbleHi, _marbleMid, _marbleBase],
        ).createShader(Offset.zero & size),
    );

    // Outer column pilaster on the screen edge
    final colW = 26.0;
    final colRect = isLeft
        ? Rect.fromLTWH(0, 0, colW, size.height)
        : Rect.fromLTWH(size.width - colW, 0, colW, size.height);
    canvas.drawRect(
      colRect,
      Paint()..color = _marbleHi.withValues(alpha: 0.35),
    );
    for (var i = 0; i < 4; i++) {
      final x = isLeft
          ? colW * (i + 0.5) / 4
          : size.width - colW + colW * (i + 0.5) / 4;
      canvas.drawLine(
        Offset(x, 40),
        Offset(x, size.height - 24),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..strokeWidth = 1,
      );
    }

    // Stylobate
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          i * 4.0,
          size.height - 16 + i * 5,
          size.width - i * 8,
          4,
        ),
        Paint()..color = Color.lerp(_marbleBase, _marbleHi, i * 0.2)!,
      );
    }

    // Lintel + meander frieze
    canvas.drawRect(
      Rect.fromLTWH(0, 36, size.width, 12),
      Paint()..color = _marbleHi,
    );
    canvas.drawLine(
      const Offset(0, 50),
      Offset(size.width, 50),
      Paint()
        ..color = bronze.withValues(alpha: 0.65)
        ..strokeWidth = 1.5,
    );
    _paintMeander(
      canvas,
      Rect.fromLTWH(12, 54, size.width - 24, 24),
      bronze.withValues(alpha: 0.5),
    );

    // Door flutes
    const panels = 5;
    for (var i = 0; i < panels; i++) {
      final x = size.width * (i + 0.5) / panels;
      canvas.drawLine(
        Offset(x, 86),
        Offset(x, size.height - 28),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..strokeWidth = 1.5,
      );
    }

    // Bronze seam + ring boss at center edge
    canvas.drawLine(
      Offset(innerEdge, 50),
      Offset(innerEdge, size.height - 22),
      Paint()
        ..color = bronze.withValues(alpha: 0.8)
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      Offset(innerEdge, size.height * 0.46),
      12,
      Paint()
        ..color = bronze.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(innerEdge, size.height * 0.46),
      12,
      Paint()
        ..color = bronze
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = bronze.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _paintMeander(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.miter;

    const step = 8.0;
    var x = rect.left;
    final y = rect.top + rect.height / 2;
    final path = Path()..moveTo(x, y);
    while (x < rect.right - step * 4) {
      path
        ..lineTo(x + step, y)
        ..lineTo(x + step, y - step * 0.65)
        ..lineTo(x + step * 2, y - step * 0.65)
        ..lineTo(x + step * 2, y)
        ..lineTo(x + step * 3, y)
        ..lineTo(x + step * 3, y + step * 0.65)
        ..lineTo(x + step * 4, y + step * 0.65)
        ..lineTo(x + step * 4, y);
      x += step * 4;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GreekGateDoorPainter oldDelegate) =>
      oldDelegate.isLeft != isLeft;
}

class _HermesSigil extends StatelessWidget {
  const _HermesSigil();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const CustomPaint(
          size: Size(120, 120),
          painter: _WingedCirclePainter(),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              duration: 1800.ms,
              begin: const Offset(0.94, 0.94),
              end: const Offset(1.06, 1.06),
            ),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: ShadowColors.surfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(color: ShadowColors.primarySoft, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: ShadowColors.primary.withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.fingerprint_rounded,
            color: ShadowColors.primary,
            size: 44,
          ),
        ),
      ],
    );
  }
}

class _WingedCirclePainter extends CustomPainter {
  const _WingedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = ShadowColors.primary.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (final side in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(center.dx + side * 20, center.dy - 4)
        ..quadraticBezierTo(
          center.dx + side * 28,
          center.dy - 8,
          center.dx + side * 38,
          center.dy + 6,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WingedCirclePainter oldDelegate) => false;
}
