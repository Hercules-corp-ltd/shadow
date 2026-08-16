import 'package:flutter/material.dart';

import '../theme/shadow_colors.dart';
import '../theme/shadow_typography.dart';

/// A setting that exists in the design but is not wired to anything yet.
///
/// Shadow's settings screens persisted every value correctly and **nothing
/// read any of them** — a grep across the app found zero consumers outside the
/// settings screens themselves. The Tor switch was the worst of them: there is
/// no Tor client in the dependency list, so flipping it changed a boolean and
/// nothing else, in a product whose entire pitch is privacy.
///
/// A switch that moves is a promise. This shows the control so the roadmap is
/// legible, makes plain that it does nothing yet, and refuses to move.
class UnbuiltTile extends StatelessWidget {
  const UnbuiltTile({
    super.key,
    required this.title,
    required this.reason,
    this.icon,
  });

  final String title;

  /// Why it does not work yet. Concrete, not "coming soon".
  final String reason;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon ?? Icons.construction_rounded,
        color: ShadowColors.textDisabled,
        size: 20,
      ),
      title: Text(
        title,
        style: ShadowTypography.body
            .copyWith(color: ShadowColors.textDisabled),
      ),
      subtitle: Text(reason, style: ShadowTypography.bodySm),
      trailing: Text(
        'Not built',
        style: ShadowTypography.caption
            .copyWith(color: ShadowColors.textTertiary),
      ),
      enabled: false,
    );
  }
}
