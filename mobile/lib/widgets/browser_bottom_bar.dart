import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_spacing.dart';
import '../theme/shadow_typography.dart';

/// Data describing an open browser tab.
class BrowserTab {
  const BrowserTab({required this.title, required this.url, this.icon});

  final String title;
  final String url;
  final IconData? icon;
}

/// The multi-row browser chrome that sits at the bottom of the app:
/// tab strip, secure URL bar, and navigation controls.
class BrowserBottomBar extends StatelessWidget {
  const BrowserBottomBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.currentUrl,
    this.onSelectTab,
    this.onCloseTab,
    this.onAddTab,
    this.onBack,
    this.onForward,
    this.onRefresh,
  });

  final List<BrowserTab> tabs;
  final int activeIndex;
  final String currentUrl;
  final ValueChanged<int>? onSelectTab;
  final ValueChanged<int>? onCloseTab;
  final VoidCallback? onAddTab;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: ShadowColors.surfaceElevated.withValues(alpha: 0.85),
            border: const Border(
              top: BorderSide(color: ShadowColors.border),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabStrip(),
                _buildUrlBar(),
                Container(
                  height: 4,
                  decoration: const BoxDecoration(
                    gradient: ShadowColors.primaryGradient,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < tabs.length; i++)
                    _TabChip(
                      tab: tabs[i],
                      active: i == activeIndex,
                      onTap: () => onSelectTab?.call(i),
                      onClose: tabs.length > 1 && i == activeIndex
                          ? () => onCloseTab?.call(i)
                          : null,
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onAddTab,
            icon: const Icon(Icons.add_rounded),
            color: ShadowColors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildUrlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: ShadowColors.surface,
                borderRadius: BorderRadius.circular(ShadowRadius.sm),
                border: Border.all(color: ShadowColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 14,
                    color: ShadowColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Secure',
                    style: ShadowTypography.caption.copyWith(
                      color: ShadowColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentUrl,
                      style: ShadowTypography.label.copyWith(
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _navBtn(Icons.arrow_back_ios_new_rounded, onBack),
          _navBtn(Icons.arrow_forward_ios_rounded, onForward),
          _navBtn(Icons.refresh_rounded, onRefresh),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      color: ShadowColors.textSecondary,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.tab,
    required this.active,
    this.onTap,
    this.onClose,
  });

  final BrowserTab tab;
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        active ? ShadowColors.primary : ShadowColors.textSecondary;
    final borderColor = active ? ShadowColors.primary : ShadowColors.border;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: active
            ? ShadowColors.primarySoft
            : ShadowColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tab.icon != null) ...[
                  Icon(tab.icon, size: 14, color: labelColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  tab.title,
                  style: ShadowTypography.label.copyWith(color: labelColor),
                ),
                if (onClose != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onClose,
                    customBorder: const CircleBorder(),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: labelColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
