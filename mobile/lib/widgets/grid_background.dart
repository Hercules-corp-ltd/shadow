import 'package:flutter/material.dart';

/// Subtle dotted "+" grid background seen on onboarding screens.
class GridBackground extends StatelessWidget {
  const GridBackground({super.key, this.child, this.spacing = 40});

  final Widget? child;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    // No fill of its own. This used to paint ShadowColors.background, which
    // is opaque black, and that sat on top of the app-wide AmbientLight and
    // hid it — so the screens using this grid stayed flat while every other
    // screen was lit. The grid is a texture over the light, not a backdrop.
    return CustomPaint(
      painter: _CrossGridPainter(spacing: spacing),
      child: child ?? const SizedBox.expand(),
    );
  }
}

class _CrossGridPainter extends CustomPainter {
  _CrossGridPainter({required this.spacing});

  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawLine(Offset(x - 3, y), Offset(x + 3, y), paint);
        canvas.drawLine(Offset(x, y - 3), Offset(x, y + 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CrossGridPainter oldDelegate) =>
      oldDelegate.spacing != spacing;
}
