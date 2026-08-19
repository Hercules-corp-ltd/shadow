import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

/// Shows a freshly generated recovery phrase, once.
///
/// This screen is the whole backup story. Every account Shadow derives comes
/// from these words, and nothing on the device or any server can reproduce
/// them — so the user cannot leave until they have confirmed they wrote them
/// down. The app previously created keys with no phrase shown at all, which
/// meant a forgotten password was permanent, silent loss of funds.
class IdentityPhraseScreen extends StatefulWidget {
  const IdentityPhraseScreen({
    super.key,
    required this.phrase,
    this.subtitle = 'Twelve words that rebuild every account you create',
    this.continueRoute = '/identity',
    this.alsoRecord,
  });

  final String phrase;

  /// What these particular words unlock. A wallet phrase and an identity
  /// phrase carry different stakes and the screen should say which.
  final String subtitle;

  /// Where "Continue" goes once the user has confirmed the backup.
  final String continueRoute;

  /// Something that is *not* in the phrase but is needed to restore from it.
  ///
  /// The alias domain is the case that matters: it lives in the keystore, not
  /// in the words, so "twelve words restore everything" is false without it.
  /// A user who writes down only the phrase and later reinstalls will hold a
  /// valid identity that mints addresses at the wrong domain.
  final String? alsoRecord;

  @override
  State<IdentityPhraseScreen> createState() => _IdentityPhraseScreenState();
}

class _IdentityPhraseScreenState extends State<IdentityPhraseScreen> {
  bool _acknowledged = false;
  bool _revealed = false;

  List<String> get _words => widget.phrase.split(RegExp(r'\s+'));

  @override
  Widget build(BuildContext context) {
    return ShadowScaffold(
      title: 'Your recovery phrase',
      subtitle: widget.subtitle,
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            border: Border.all(color: ShadowColors.warning.withValues(alpha: 0.4)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: ShadowColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Text('Write these down now', style: ShadowTypography.h4),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Shadow keeps no copy. Lose these words and every account '
                  'derived from them is gone for good — there is no reset '
                  'link and no support channel that can bring them back.',
                  style: ShadowTypography.bodySm,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: _revealed ? _wordGrid() : _coveredState(),
          ),
          if (widget.alsoRecord != null) ...[
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Write this down too', style: ShadowTypography.h4),
                  const SizedBox(height: 8),
                  Text(widget.alsoRecord!, style: ShadowTypography.mono),
                  const SizedBox(height: 8),
                  Text(
                    'This is not part of the phrase, and the words alone will '
                    'not bring it back. Without it your addresses come out at '
                    'the wrong domain and your mail goes nowhere.',
                    style: ShadowTypography.bodySm,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_revealed)
            ShadowButton(
              label: 'Copy phrase',
              variant: ShadowButtonVariant.secondary,
              leading: Icons.copy_rounded,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.phrase));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Copied. Paste it somewhere only you can reach, then '
                      'clear your clipboard.',
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 20),
          CheckboxListTile(
            value: _acknowledged,
            onChanged: _revealed
                ? (value) => setState(() => _acknowledged = value ?? false)
                : null,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: ShadowColors.primary,
            title: Text(
              'I have written these words down somewhere safe',
              style: ShadowTypography.body,
            ),
          ),
          const SizedBox(height: 8),
          ShadowButton(
            label: 'Continue',
            onPressed:
                _acknowledged ? () => context.go(widget.continueRoute) : null,
          ),
        ],
      ),
    );
  }

  Widget _coveredState() {
    return Column(
      children: [
        const Icon(Icons.visibility_off_rounded,
            size: 36, color: ShadowColors.textSecondary),
        const SizedBox(height: 12),
        Text(
          'Make sure nobody is watching your screen',
          style: ShadowTypography.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ShadowButton(
          label: 'Reveal phrase',
          variant: ShadowButtonVariant.secondary,
          onPressed: () => setState(() => _revealed = true),
        ),
      ],
    );
  }

  Widget _wordGrid() {
    final words = _words;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(words.length, (index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          // Twelve of these at once, so an opaque grey block each turned the
          // one screen that matters most into a spreadsheet.
          decoration: BoxDecoration(
            color: ShadowColors.recess,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ShadowColors.edge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${index + 1}',
                  style: ShadowTypography.caption
                      .copyWith(color: ShadowColors.textTertiary)),
              const SizedBox(width: 6),
              Text(words[index], style: ShadowTypography.mono),
            ],
          ),
        );
      }),
    );
  }
}
