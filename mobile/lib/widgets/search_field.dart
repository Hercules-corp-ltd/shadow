import 'package:flutter/material.dart';

import '../theme/blind_colors.dart';
import '../theme/blind_spacing.dart';
import '../theme/blind_typography.dart';

/// The rounded search field used on the home page (and other list screens).
class BlindSearchField extends StatelessWidget {
  const BlindSearchField({
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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BlindColors.surfaceElevated,
        borderRadius: BorderRadius.circular(BlindRadius.md),
        border: Border.all(color: BlindColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: BlindColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              autofocus: autofocus,
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: BlindTypography.body,
              cursorColor: BlindColors.primary,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: BlindTypography.body
                    .copyWith(color: BlindColors.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else
            const Icon(
              Icons.mic_none_rounded,
              color: BlindColors.textSecondary,
              size: 20,
            ),
        ],
      ),
    );
  }
}
