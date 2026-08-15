import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../identity/identity.dart';
import '../../providers/identity_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

/// The identity layer's home: set up a phrase, unlock it, and see exactly
/// what a given site would receive if you signed up right now.
class IdentityScreen extends StatelessWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<IdentityProvider>();

    return ShadowScaffold(
      title: 'Identity',
      subtitle: 'One phrase. A different you on every site.',
      body: switch (identity.state) {
        IdentityLifecycle.uninitialized =>
          const Center(child: CircularProgressIndicator()),
        IdentityLifecycle.empty => const _SetupView(),
        IdentityLifecycle.locked => const _UnlockView(),
        IdentityLifecycle.unlocked => const _DeriveView(),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

class _SetupView extends StatefulWidget {
  const _SetupView();

  @override
  State<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends State<_SetupView> {
  final _aliasCtrl = TextEditingController();
  final _importCtrl = TextEditingController();
  bool _importing = false;
  bool _busy = false;

  @override
  void dispose() {
    _aliasCtrl.dispose();
    _importCtrl.dispose();
    super.dispose();
  }

  bool get _aliasLooksValid {
    final value = _aliasCtrl.text.trim();
    return value.contains('.') && !value.contains('@') && value.length > 3;
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final provider = context.read<IdentityProvider>();
    final phrase = await provider.createPhrase(aliasDomain: _aliasCtrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    context.go('/identity/phrase', extra: phrase);
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    final provider = context.read<IdentityProvider>();
    final ok = await provider.importPhrase(
      _importCtrl.text,
      aliasDomain: _aliasCtrl.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'That phrase is not valid.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How this works', style: ShadowTypography.h4),
              const SizedBox(height: 10),
              Text(
                'Shadow does not replace a site\'s login. It generates one for '
                'you — an address, a password and a username that site has '
                'never seen and cannot connect to anything else you own. '
                'Every one of them comes back from your recovery phrase, so '
                'there is nothing to sync and nothing to lose with the phone.',
                style: ShadowTypography.bodySm,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Where should mail arrive?', style: ShadowTypography.h4),
              const SizedBox(height: 6),
              Text(
                'A domain you control with catch-all mail switched on, or an '
                'aliasing provider that accepts any address. Apple\'s Hide My '
                'Email will not work here — Apple mints those addresses, so '
                'they cannot be derived from your phrase.',
                style: ShadowTypography.bodySm,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _aliasCtrl,
                onChanged: (_) => setState(() {}),
                autocorrect: false,
                keyboardType: TextInputType.url,
                style: ShadowTypography.body,
                decoration: const InputDecoration(
                  hintText: 'mail.yourdomain.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded,
                      color: ShadowColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_importing) ...<Widget>[
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your recovery phrase', style: ShadowTypography.h4),
                const SizedBox(height: 12),
                TextField(
                  controller: _importCtrl,
                  maxLines: 3,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: ShadowTypography.mono,
                  decoration: const InputDecoration(
                    hintText: 'twelve words separated by spaces',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ShadowButton(
            label: 'Restore identity',
            isLoading: _busy,
            onPressed: _aliasLooksValid && _importCtrl.text.trim().isNotEmpty
                ? _import
                : null,
          ),
          const SizedBox(height: 8),
          ShadowButton(
            label: 'Back',
            variant: ShadowButtonVariant.ghost,
            onPressed: () => setState(() => _importing = false),
          ),
        ] else ...<Widget>[
          ShadowButton(
            label: 'Create a new identity',
            isLoading: _busy,
            onPressed: _aliasLooksValid ? _create : null,
          ),
          const SizedBox(height: 8),
          ShadowButton(
            label: 'I already have a phrase',
            variant: ShadowButtonVariant.ghost,
            onPressed: () => setState(() => _importing = true),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Unlock
// ---------------------------------------------------------------------------

class _UnlockView extends StatefulWidget {
  const _UnlockView();

  @override
  State<_UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends State<_UnlockView> {
  final _passphraseCtrl = TextEditingController();
  bool _busy = false;
  bool _obscured = true;

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() => _busy = true);
    final provider = context.read<IdentityProvider>();
    final ok = await provider.unlock(passphrase: _passphraseCtrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Could not unlock.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Passphrase', style: ShadowTypography.h4),
              const SizedBox(height: 6),
              Text(
                'Your optional twenty-fifth word. It is never stored, on this '
                'device or anywhere else — it is what keeps your accounts on a '
                'different branch from your wallet keys, so a seed exposed '
                'while signing a transaction does not hand over your whole '
                'identity. Leave it empty only if you set it up that way.',
                style: ShadowTypography.bodySm,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passphraseCtrl,
                obscureText: _obscured,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _unlock(),
                style: ShadowTypography.body,
                decoration: InputDecoration(
                  hintText: 'passphrase (or leave empty)',
                  prefixIcon: const Icon(Icons.key_rounded,
                      color: ShadowColors.textSecondary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: ShadowColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShadowButton(label: 'Unlock', isLoading: _busy, onPressed: _unlock),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Derive
// ---------------------------------------------------------------------------

class _DeriveView extends StatefulWidget {
  const _DeriveView();

  @override
  State<_DeriveView> createState() => _DeriveViewState();
}

class _DeriveViewState extends State<_DeriveView> {
  final _siteCtrl = TextEditingController();
  SiteIdentity? _identity;
  String? _failure;

  @override
  void dispose() {
    _siteCtrl.dispose();
    super.dispose();
  }

  void _derive() {
    final input = _siteCtrl.text.trim();
    if (input.isEmpty) return;
    final result = context.read<IdentityProvider>().identityFor(input);
    setState(() {
      _identity = result;
      _failure = result == null
          ? 'That does not look like a website address. Try twitter.com.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IdentityProvider>();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_open_rounded,
                      size: 18, color: ShadowColors.success),
                  const SizedBox(width: 8),
                  Text('Unlocked', style: ShadowTypography.h4),
                  const Spacer(),
                  TextButton(
                    onPressed: provider.lock,
                    child: Text('Lock', style: ShadowTypography.label),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Aliases arrive at ${provider.aliasDomain}',
                  style: ShadowTypography.bodySm),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Which site?', style: ShadowTypography.h4),
              const SizedBox(height: 12),
              TextField(
                controller: _siteCtrl,
                autocorrect: false,
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _derive(),
                style: ShadowTypography.body,
                decoration: const InputDecoration(
                  hintText: 'twitter.com',
                  prefixIcon: Icon(Icons.public_rounded,
                      color: ShadowColors.textSecondary),
                ),
              ),
              const SizedBox(height: 14),
              ShadowButton(label: 'Show my identity', onPressed: _derive),
            ],
          ),
        ),
        if (_failure != null) ...<Widget>[
          const SizedBox(height: 16),
          Text(_failure!,
              style: ShadowTypography.bodySm.copyWith(color: ShadowColors.error)),
        ],
        if (_identity != null) ...<Widget>[
          const SizedBox(height: 16),
          _IdentityCard(identity: _identity!),
        ],
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.identity});

  final SiteIdentity identity;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(identity.registrableDomain, style: ShadowTypography.h3),
          const SizedBox(height: 4),
          Text(
            'What this site would receive. Nothing here is stored — it is '
            'recomputed from your phrase every time.',
            style: ShadowTypography.caption,
          ),
          const SizedBox(height: 18),
          _Field(label: 'Email', value: identity.email),
          const SizedBox(height: 14),
          _Field(label: 'Username', value: identity.handle),
          const SizedBox(height: 14),
          _Field(label: 'Password', value: identity.password, secret: true),
        ],
      ),
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({required this.label, required this.value, this.secret = false});

  final String label;
  final String value;
  final bool secret;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late bool _hidden = widget.secret;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(),
            style: ShadowTypography.caption
                .copyWith(letterSpacing: 1.2, color: ShadowColors.textTertiary)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                _hidden ? '•' * widget.value.length : widget.value,
                style: ShadowTypography.mono,
              ),
            ),
            if (widget.secret)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _hidden
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  size: 18,
                  color: ShadowColors.textSecondary,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded,
                  size: 18, color: ShadowColors.textSecondary),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${widget.label} copied')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
