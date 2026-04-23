import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import 'status_pill.dart';

/// The persistent top bar with network pill + shortcut icons that appears
/// on the home page and most nested screens.
class ShadowTopBar extends StatelessWidget implements PreferredSizeWidget {
  const ShadowTopBar({
    super.key,
    this.network = 'Mainnet',
    this.networkColor = ShadowColors.mainnet,
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
                color: ShadowColors.textSecondary,
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

/// Compact icon button used in the ShadowTopBar actions.
class ShadowTopBarButton extends StatelessWidget {
  const ShadowTopBarButton({
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
        ? ShadowColors.primary
        : (background ?? ShadowColors.surfaceElevated);
    final fg = isActive ? Colors.white : (color ?? ShadowColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isActive ? ShadowColors.primary : ShadowColors.border,
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
