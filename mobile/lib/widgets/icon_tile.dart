import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_spacing.dart';
import '../theme/shadow_typography.dart';

/// A round action button with a label under it — Send, Receive, Swap, Buy.
///
/// ## Why the colour moved off the fill
///
/// Four filled 56dp squares in blue, green, purple and amber, each with a
/// coloured drop shadow, was the loudest thing in the wallet: a row of app
/// icons sitting on Shadow's page. The colours carry almost no information —
/// nobody learns that swap is the purple one — so they were spending all the
/// attention on the screen and buying nothing.
///
/// The tile is now a socket cut into the page, ringed and lit in the action's
/// colour, with the glyph itself carrying the accent. The row still reads as
/// four distinct actions, in the same material as everything around it.
class IconTile extends StatefulWidget {
  const IconTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.size = 56,
  });

  final String label;
  final Widget icon;
  final Color color;
  final VoidCallback? onTap;
  final double size;

  @override
  State<IconTile> createState() => _IconTileState();
}

class _IconTileState extends State<IconTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // onTap was checked three times for gestures and never once for looks, so
    // a tile with no handler rendered pixel-identical to a working one — the
    // trap the wallet screen walked straight into when its "Buy" tile was
    // disabled and stayed indistinguishable from Send, Receive and Swap.
    final disabled = widget.onTap == null;

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Semantics(
      button: true,
      enabled: !disabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapCancel: widget.onTap == null
            ? null
            : () => setState(() => _pressed = false),
        onTap: widget.onTap == null
            ? null
            : () {
                setState(() => _pressed = false);
                widget.onTap!.call();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration:
                    still ? Duration.zero : const Duration(milliseconds: 130),
                curve: Curves.easeOut,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: ShadowColors.recessDeep,
                  borderRadius: BorderRadius.circular(ShadowRadius.md),
                  border: Border.all(
                    color:
                        widget.color.withValues(alpha: _pressed ? 0.62 : 0.34),
                  ),
                  boxShadow: <BoxShadow>[
                    // Held in, not lifted: pressing brightens the light inside
                    // the socket rather than raising the tile off the page.
                    BoxShadow(
                      color: widget.color
                          .withValues(alpha: _pressed ? 0.26 : 0.13),
                      blurRadius: _pressed ? 22 : 16,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(
                      color: _pressed
                          ? Colors.white
                          : widget.color.withValues(alpha: 0.92),
                      size: 24,
                    ),
                    child: widget.icon,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: ShadowTypography.bodySm.copyWith(
                  color: ShadowColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
