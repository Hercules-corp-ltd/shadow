import 'package:flutter/material.dart';

import '../theme/blind_colors.dart';
import '../theme/blind_spacing.dart';
import '../theme/blind_typography.dart';

/// A consistent dark scaffold with optional back button + title + subtitle.
/// Used on almost every inner screen (History, Bookmarks, etc.).
class BlindScaffold extends StatelessWidget {
  const BlindScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    required this.body,
    this.bottomBar,
    this.showBack = true,
    this.padding =
        const EdgeInsets.symmetric(horizontal: BlindSpacing.pagePadding),
    this.background,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final Widget body;
  final Widget? bottomBar;
  final bool showBack;
  final EdgeInsetsGeometry padding;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlindColors.background,
      bottomNavigationBar: bottomBar,
      body: Stack(
        children: [
          if (background != null) Positioned.fill(child: background!),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                Expanded(
                  child: Padding(padding: padding, child: body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (title == null && leading == null && actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack && Navigator.of(context).canPop())
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          else if (leading != null)
            leading!
          else
            const SizedBox(width: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(title!, style: BlindTypography.h2),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: BlindTypography.bodySm),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
