import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/extensions_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/load_state_view.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_scaffold.dart';

class ExtensionsScreen extends StatefulWidget {
  const ExtensionsScreen({super.key});

  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<ExtensionsProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExtensionsProvider>();

    return ShadowScaffold(
      title: 'Extensions',
      subtitle: '${p.items.length} installed',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: ShadowColors.error),
          onPressed:
              p.items.isEmpty ? null : () => context.push('/extensions/clear'),
        ),
      ],
      body: LoadStateView(
        isLoading: p.isLoading,
        isEmpty: p.items.isEmpty,
        error: p.error,
        onRetry: p.load,
        emptyIcon: Icons.extension_rounded,
        // There is no install path and no "Shadow directory": the service
        // exposes only list/toggle/uninstall/clearAll, nothing ever writes an
        // extension, and extensions_service.dart says so outright — "Shadow
        // has no extension runtime yet… the screen must not imply otherwise".
        // This string implied exactly that, and sent people looking for a
        // storefront that does not exist.
        emptyTitle: 'Extensions are not built yet',
        emptyMessage: 'Shadow has no extension runtime and no directory to '
            'install from, so nothing can be added here yet.',
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemBuilder: (_, i) {
            final e = p.items[i];
            return GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: ShadowColors.recessDeep,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ShadowColors.edge),
                    ),
                    child: Icon(
                      Icons.extension_rounded,
                      color: ShadowColors.tilePurple.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name, style: ShadowTypography.h4),
                        const SizedBox(height: 4),
                        Text(
                          'v${e.version} · by ${e.author}',
                          style: ShadowTypography.bodySm,
                        ),
                        if (e.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            e.description,
                            style: ShadowTypography.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Switch(
                    value: e.enabled,
                    onChanged: (v) =>
                        context.read<ExtensionsProvider>().toggle(e.id, v),
                  ),
                ],
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: p.items.length,
        ),
      ),
    );
  }
}
