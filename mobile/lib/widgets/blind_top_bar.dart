import 'package:flutter/material.dart';

import '../theme/blind_colors.dart';
import 'status_pill.dart';

/// The persistent top bar with network pill + shortcut icons that appears
/// on the home page and most nested screens.
class BlindTopBar extends StatelessWidget implements PreferredSizeWidget {
  const BlindTopBar({
    super.key,
    this.network = 'Mainnet',
    this.networkColor = BlindColors.mainnet,
    this.onNetworkTap,
    this.actions = const [],
  });

  final String network;
  final Color networkColor;
  final VoidCallback? onNetworkTap;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 16);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            StatusPill(
              label: network,
              color: networkColor,
              onTap: onNetworkTap,
              trailing: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: BlindColors.textSecondary,
              ),
            ),
            const Spacer(),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Compact icon button used in the BlindTopBar actions.
class BlindTopBarButton extends StatelessWidget {
  const BlindTopBarButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.background,
    this.isActive = false,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? background;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final bg = isActive
        ? BlindColors.primary
        : (background ?? BlindColors.surfaceElevated);
    final fg = isActive ? Colors.white : (color ?? BlindColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isActive ? BlindColors.primary : BlindColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: IconTheme(
                data: IconThemeData(color: fg, size: 18),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
