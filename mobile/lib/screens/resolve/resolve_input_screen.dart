import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/blind_colors.dart';
import '../../theme/blind_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/blind_button.dart';
import '../../widgets/blind_scaffold.dart';

class ResolveInputScreen extends StatefulWidget {
  const ResolveInputScreen({super.key});

  @override
  State<ResolveInputScreen> createState() => _ResolveInputScreenState();
}

class _ResolveInputScreenState extends State<ResolveInputScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _ctrl.text.trim().isNotEmpty;

    return BlindScaffold(
      title: 'Resolve content',
      subtitle: 'Enter a Blind ID, .blind domain, or CID',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _go(),
                  style: BlindTypography.body,
                  decoration: InputDecoration(
                    hintText: 'myname.blind / Qm... / bafy...',
                    prefixIcon: const Icon(Icons.link_rounded,
                        color: BlindColors.textSecondary),
                    suffixIcon: hasText
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _ctrl.clear();
                              setState(() {});
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.content_paste_rounded),
                            onPressed: _paste,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You can paste any Blind identifier: .blind domain, a site program address, or a raw IPFS / Arweave content ID.',
                  style: BlindTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BlindButton(
            label: 'Resolve',
            size: BlindButtonSize.lg,
            trailing: Icons.arrow_forward_rounded,
            onPressed: hasText ? _go : null,
          ),
        ],
      ),
    );
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    if (d?.text != null) {
      setState(() => _ctrl.text = d!.text!.trim());
    }
  }

  void _go() {
    final id = _ctrl.text.trim();
    if (id.isEmpty) return;
    context.push('/resolve/resolving?id=${Uri.encodeComponent(id)}');
  }
}
