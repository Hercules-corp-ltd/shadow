import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/shadow_colors.dart';

/// The one control left on screen when everything else is gone.
///
/// ## Why it is this small and this faint
///
/// Its whole job is to get the browser chrome out of the way, so it cannot be
/// another piece of chrome. At rest it sits at a third opacity and 34dp
/// across — legible if you look for it, ignorable if you are reading. It
/// brightens while touched and while being moved, because a control you are
/// holding should answer, and fades back the moment you let go.
///
/// ## Why it moves
///
/// A fixed handle is always in front of something. On a long article it lands
/// on the text; on a map it lands on the part you are pinching. Rather than
/// guess a corner that is safe on every page, it is dragged wherever the
/// reader wants and stays there — snapped to whichever side is nearer, so it
/// never floats in open space, and clamped inside the safe area so it cannot
/// be lost behind a notch or a gesture bar.
///
/// The position is remembered across launches. Moving it is a small piece of
/// work and making somebody repeat it every session is the kind of detail
/// that reads as the app not paying attention.
///
/// ## What it refuses
///
/// It never hides itself. Whatever else is dismissed, this stays — a control
/// that removes the last way back is a trap, and "shake to restore" is not an
/// affordance anybody discovers while holding a phone in one hand.
class ImmersionHandle extends StatefulWidget {
  const ImmersionHandle({
    super.key,
    required this.hidden,
    required this.onToggle,
  });

  /// Whether the browser chrome is currently hidden.
  final bool hidden;
  final ValueChanged<bool> onToggle;

  @override
  State<ImmersionHandle> createState() => _ImmersionHandleState();
}

class _ImmersionHandleState extends State<ImmersionHandle> {
  static const String _keyX = 'shadow_immersion_handle_x';
  static const String _keyY = 'shadow_immersion_handle_y';
  static const double _size = 34;
  static const double _margin = 10;

  /// Fraction of the free space, not pixels: a position saved on one screen
  /// has to land somewhere sensible on another.
  double _x = 1;
  double _y = 0.62;
  bool _held = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _x = prefs.getDouble(_keyX) ?? 1;
      _y = prefs.getDouble(_keyY) ?? 0.62;
      _loaded = true;
    });
  }

  Future<void> _remember() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyX, _x);
    await prefs.setDouble(_keyY, _y);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final media = MediaQuery.of(context);
    final safe = media.padding;
    final size = media.size;

    final minX = safe.left + _margin;
    final maxX = size.width - safe.right - _margin - _size;
    final minY = safe.top + _margin;
    final maxY = size.height - safe.bottom - _margin - _size;

    final left = (minX + (maxX - minX) * _x).clamp(minX, maxX);
    final top = (minY + (maxY - minY) * _y).clamp(minY, maxY);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onToggle(!widget.hidden),
        onPanStart: (_) => setState(() => _held = true),
        onPanUpdate: (details) {
          setState(() {
            _x = (_x + details.delta.dx / (maxX - minX)).clamp(0.0, 1.0);
            _y = (_y + details.delta.dy / (maxY - minY)).clamp(0.0, 1.0);
          });
        },
        onPanEnd: (_) {
          setState(() {
            _held = false;
            // Snap to the nearer side. Left free-floating it reads as
            // something dropped rather than something placed, and an edge is
            // where a thumb expects to find it again.
            _x = _x < 0.5 ? 0.0 : 1.0;
          });
          _remember();
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: _held ? 0.95 : 0.34,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: _held ? 0.30 : 0.14),
              ),
            ),
            child: Icon(
              // The icon says what the tap does, not what the state is: while
              // the chrome is hidden it offers to bring it back.
              widget.hidden
                  ? Icons.unfold_more_rounded
                  : Icons.unfold_less_rounded,
              size: 17,
              color: widget.hidden
                  ? ShadowColors.primary
                  : Colors.white.withValues(alpha: 0.85),
              semanticLabel: widget.hidden
                  ? 'Show browser controls'
                  : 'Hide browser controls',
            ),
          ),
        ),
      ),
    );
  }
}
