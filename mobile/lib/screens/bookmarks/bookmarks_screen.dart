import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/bookmarks_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/list_item_card.dart';
import '../../widgets/search_field.dart';
import '../../widgets/shadow_scaffold.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<BookmarksProvider>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BookmarksProvider>();

    return ShadowScaffold(
      title: 'Bookmarks',
      subtitle: '${p.bookmarks.length} saved sites',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: ShadowColors.error),
          onPressed: p.bookmarks.isEmpty
              ? null
              : () => context.push('/bookmarks/clear'),
        ),
      ],
      body: Column(
        children: [
          ShadowSearchField(
            hint: 'Search bookmarks...',
            onChanged: p.setQuery,
          ),
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final folders = <String>['All', ...p.folders.where((f) => f != 'All')];
            if (folders.length <= 1) return const SizedBox.shrink();
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in folders)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: p.folder == f ||
                            (p.folder == null && f == 'All'),
                        onSelected: (_) =>
                            p.load(folder: f == 'All' ? null : f),
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Expanded(
            child: p.isLoading && p.bookmarks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : p.bookmarks.isEmpty
                    ? const EmptyState(
                        icon: Icons.bookmark_border_rounded,
                        title: 'No bookmarks yet',
                        message:
                            'Tap the star on any site to save it for later.',
                      )
                    : ListView.separated(
                        itemBuilder: (_, i) {
                          final b = p.bookmarks[i];
                          return ListItemCard(
                            title: b.title ?? b.domain,
                            subtitle: b.domain,
                            leadingIcon: Icons.bookmark_rounded,
                            leadingColor: ShadowColors.primary,
                            onTap: () => context.push(
                                '/resolve?id=${Uri.encodeComponent(b.domain)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert_rounded,
                                  color: ShadowColors.textTertiary),
                              onPressed: () => _showBookmarkMenu(context, b.domain),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemCount: p.bookmarks.length,
                      ),
          ),
        ],
      ),
    );
  }

  void _showBookmarkMenu(BuildContext context, String domain) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ShadowColors.surfaceElevated,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                context.push('/resolve?id=${Uri.encodeComponent(domain)}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: ShadowColors.error),
              title: const Text('Remove bookmark'),
              onTap: () async {
                Navigator.pop(context);
                await context.read<BookmarksProvider>().remove(domain);
              },
            ),
          ],
        ),
      ),
    );
  }
}
