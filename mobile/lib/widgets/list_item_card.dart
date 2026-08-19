import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_spacing.dart';
import '../theme/shadow_typography.dart';

/// The row every list in the app is made of.
///
/// ## Why this one file was worth changing
///
/// History, bookmarks, downloads, extensions, activity, tokens and the domain
/// screens are all built from this, so it is the single thing that decided
/// whether those pages looked like Shadow or like a stock Material list. It
/// used an opaque `surfaceElevated` fill and a flat 1px border, which meant
/// the app-wide light stopped dead at the edge of every row and nine screens
/// read as a different product from the home screen.
///
/// Now it is the same material as everything else: a translucent fill that
/// lets the drifting light through, brighter along the top edge where light
/// would catch, a soft shadow beneath, and a press that eases rather than
/// flashing an ink splash. Nothing about the API changed, so the nine screens
/// using it did not have to be touched one at a time.
class ListItemCard extends StatefulWidget {
  const ListItemCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingColor,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.statusLabel,
    this.statusColor,
    this.timeLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Color? leadingColor;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? statusLabel;
  final Color? statusColor;
  final String? timeLabel;

  @override
  State<ListItemCard> createState() => _ListItemCardState();
}

class _ListItemCardState extends State<ListItemCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final tappable = widget.onTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: tappable ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: tappable ? () => setState(() => _pressed = false) : null,
      onTap: tappable
          ? () {
              setState(() => _pressed = false);
              widget.onTap!.call();
            }
          : null,
      child: AnimatedContainer(
        duration: still ? Duration.zero : const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          // Translucent, so the light behind the whole app reaches the row.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.white.withValues(alpha: _pressed ? 0.10 : 0.070),
              Colors.white.withValues(alpha: 0.022),
            ],
          ),
          borderRadius: BorderRadius.circular(ShadowRadius.md),
          border: Border.all(
            color: Colors.white.withValues(alpha: _pressed ? 0.18 : 0.11),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: _pressed ? 8 : 16,
              offset: Offset(0, _pressed ? 2 : 7),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (widget.leading != null)
                widget.leading!
              else if (widget.leadingIcon != null)
                // A cut square rather than a saturated block. The old version
                // filled it with the caller's colour at 20% and drew the icon
                // in that colour at full strength, which put a row of bright
                // teal or purple chips down the left of every list — the one
                // thing on these screens loud enough to be the first thing
                // seen, carrying the least information. The colour stays, on
                // the glyph, where it still codes the kind of row without
                // shouting.
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(ShadowRadius.sm),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Icon(
                    widget.leadingIcon,
                    color: (widget.leadingColor ?? ShadowColors.primary)
                        .withValues(alpha: 0.80),
                    size: 19,
                  ),
                ),
              if (widget.leading != null || widget.leadingIcon != null)
                const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: ShadowTypography.h4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null ||
                        widget.timeLabel != null ||
                        widget.statusLabel != null) ...[
                      const SizedBox(height: 4),
                      DefaultTextStyle(
                        style: ShadowTypography.bodySm,
                        child: Row(
                          children: [
                            if (widget.timeLabel != null)
                              Text(widget.timeLabel!),
                            if (widget.timeLabel != null &&
                                widget.subtitle != null) ...[
                              const SizedBox(width: 6),
                              const Text('•'),
                              const SizedBox(width: 6),
                            ],
                            if (widget.subtitle != null)
                              Expanded(
                                child: Text(
                                  widget.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (widget.statusLabel != null) ...[
                              if (widget.subtitle != null ||
                                  widget.timeLabel != null) ...[
                                const SizedBox(width: 6),
                                const Text('•'),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                widget.statusLabel!,
                                style: ShadowTypography.bodySm.copyWith(
                                  color: widget.statusColor ??
                                      ShadowColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null)
                widget.trailing!
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ShadowColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
