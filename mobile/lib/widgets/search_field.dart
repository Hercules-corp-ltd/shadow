import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_spacing.dart';
import '../theme/shadow_typography.dart';

/// The search field on history, bookmarks, tokens and the domain finder.
///
/// ## Why it is darker than the page
///
/// It used an opaque `surfaceElevated` fill with a solid border, which made it
/// a grey panel sitting on top of the screen — the one shape a field you type
/// *into* should not be. The home screen already answers this: its address
/// slot is cut into the stone, dark with a lit edge. This is the same cut, so
/// the two read as the same object in two places rather than as two different
/// design systems meeting at the top of a list.
///
/// The edge brightens on focus rather than changing colour, because the thing
/// that changed is that light is now on it.
class ShadowSearchField extends StatefulWidget {
  const ShadowSearchField({
    super.key,
    this.hint = 'Search domains or enter Web3/token address...',
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.trailing,
    this.autofocus = false,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final Widget? trailing;
  final bool autofocus;

  @override
  State<ShadowSearchField> createState() => _ShadowSearchFieldState();
}

class _ShadowSearchFieldState extends State<ShadowSearchField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final focused = _focus.hasFocus;

    return AnimatedContainer(
      duration: still ? Duration.zero : const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: ShadowColors.recess,
        borderRadius: BorderRadius.circular(ShadowRadius.md),
        border: Border.all(
          color: focused
              ? ShadowColors.primary.withValues(alpha: 0.55)
              : ShadowColors.edge,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: focused
                ? ShadowColors.primary
                : ShadowColors.textTertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              focusNode: _focus,
              autofocus: widget.autofocus,
              controller: widget.controller,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: ShadowTypography.body,
              cursorColor: ShadowColors.primary,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: ShadowTypography.body
                    .copyWith(color: ShadowColors.textTertiary),
                // The container above is the field. Left to the theme this
                // would draw a second filled, bordered box inside the first.
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
              ),
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: 8),
            widget.trailing!,
          ] else
            const Icon(
              Icons.mic_none_rounded,
              color: ShadowColors.textTertiary,
              size: 20,
            ),
        ],
      ),
    );
  }
}
