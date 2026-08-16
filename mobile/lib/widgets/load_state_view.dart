import 'package:flutter/material.dart';

import 'empty_state.dart';

/// Renders the three states a loaded list can be in, and keeps them distinct.
///
/// The bug this exists to prevent is everywhere in this codebase's history:
/// a provider catches an exception, substitutes an empty list, and the screen
/// shows "No bookmarks yet". A dead backend then looks exactly like a fresh
/// account, across nine screens. Whoever is holding the phone has no way to
/// tell whether they have nothing or whether nothing worked.
///
/// Pass [error] and the failure is shown with a retry. Pass nothing and an
/// empty list is reported as genuinely empty.
class LoadStateView extends StatelessWidget {
  const LoadStateView({
    super.key,
    required this.isLoading,
    required this.isEmpty,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.child,
    this.error,
    this.onRetry,
  });

  final bool isLoading;
  final bool isEmpty;

  /// Non-null means the last load failed. Takes priority over [isEmpty],
  /// because an empty list after a failure is an artefact of the failure.
  final String? error;

  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  final VoidCallback? onRetry;

  /// Shown when there is data.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        tone: EmptyStateTone.error,
        title: 'Could not load',
        message: error!,
        actionLabel: onRetry == null ? null : 'Try again',
        onAction: onRetry,
      );
    }

    // Loading only shows a spinner when there is nothing to show underneath;
    // refreshing a populated list should not blank it out.
    if (isLoading && isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return child;
  }
}
