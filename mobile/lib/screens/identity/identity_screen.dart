import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../identity/identity.dart';
import '../../providers/identity_provider.dart';
import '../../services/quick_unlock.dart';
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
                  // Restore's enabled state is computed from this controller
                  // during build, and a controller change is not a rebuild.
                  // Without this the button reads the field as empty forever:
                  // the card appears after the domain is already filled, so
                  // nothing else triggers a build, and someone typing a
                  // perfectly good phrase watches the only button stay dead.
                  onChanged: (_) => setState(() {}),
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
  final QuickUnlock _quick = QuickUnlock();

  bool _busy = false;
  bool _obscured = true;
  bool _quickArmed = false;

  @override
  void initState() {
    super.initState();
    _readQuickState();
  }

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _readQuickState() async {
    final armed = await _quick.isEnabled();
    if (!mounted) return;
    setState(() => _quickArmed = armed);
    // Offer straight away rather than making the user hunt for it, but only
    // once — after the first successful unlock the card is gone.
    if (armed) await _unlockWithBiometrics();
  }

  Future<void> _unlockWithBiometrics() async {
    setState(() => _busy = true);
    final result = await _quick.unlock();
    if (!mounted) return;

    if (!result.succeeded) {
      setState(() => _busy = false);
      final problem = result.problem;
      if (problem != null && problem != QuickUnlockProblem.notSet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(QuickUnlock.explain(problem))),
        );
      }
      return;
    }

    final provider = context.read<IdentityProvider>();
    final ok = await provider.unlock(passphrase: result.passphrase!);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      // The stored passphrase no longer matches — the identity was replaced,
      // or the passphrase changed elsewhere. Drop it rather than prompting
      // for a fingerprint that can never work again.
      await _quick.disable();
      if (!mounted) return;
      setState(() => _quickArmed = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The remembered passphrase no longer opens this identity, so '
            'Shadow has forgotten it. Type it instead.',
          ),
        ),
      );
    }
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
    // No offer to remember here. This view is torn down the instant the state
    // flips to unlocked, so anything shown at this point cannot be read. The
    // offer lives on the unlocked screen, which is also where somebody would
    // go looking for it later.
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
        if (_quickArmed) ...<Widget>[
          const SizedBox(height: 10),
          ShadowButton(
            label: 'Use my fingerprint',
            variant: ShadowButtonVariant.secondary,
            onPressed: _busy ? null : _unlockWithBiometrics,
          ),
        ],
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
              if (provider.fingerprint != null) ...[
                const SizedBox(height: 10),
                Text('This identity', style: ShadowTypography.caption),
                const SizedBox(height: 2),
                Text(provider.fingerprint!, style: ShadowTypography.mono),
                const SizedBox(height: 6),
                Text(
                  'Should read the same every time you unlock. If it changes, '
                  'your passphrase is different and these are not your '
                  'accounts.',
                  style: ShadowTypography.caption,
                ),
              ],
              const _QuickUnlockRow(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.alternate_email_rounded, size: 20),
                title: Text('Public address', style: ShadowTypography.body),
                subtitle: Text(
                  'One name you give to people, rather than to sites. Claimed '
                  'once and permanent.',
                  style: ShadowTypography.caption,
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => context.push('/identity/public-address'),
              ),
              ListTile(
                leading: const Icon(Icons.list_alt_rounded, size: 20),
                title: Text('Your sites', style: ShadowTypography.body),
                subtitle: Text(
                  'Change how Shadow behaves on a site, rotate a password, '
                  'or replace an address that has started getting spam.',
                  style: ShadowTypography.caption,
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => context.push('/identity/sites'),
              ),
              ListTile(
                leading: const Icon(Icons.backup_outlined, size: 20),
                title: Text('Backup', style: ShadowTypography.body),
                subtitle: Text(
                  'Your words rebuild the credentials. This carries which '
                  'ones are current.',
                  style: ShadowTypography.caption,
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => context.push('/identity/backup'),
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

/// Offering to trade the passphrase for a fingerprint, and saying what it costs.
///
/// Lives on the unlocked screen rather than on the unlock screen. Two reasons:
/// the unlock view is torn down the moment the state flips, so anything shown
/// there is unreadable; and a security question put in front of somebody who is
/// trying to get in gets answered with whichever button is larger.
class _QuickUnlockRow extends StatefulWidget {
  const _QuickUnlockRow();

  @override
  State<_QuickUnlockRow> createState() => _QuickUnlockRowState();
}

class _QuickUnlockRowState extends State<_QuickUnlockRow> {
  final QuickUnlock _quick = QuickUnlock();
  final TextEditingController _confirm = TextEditingController();

  bool _available = false;
  bool _armed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    final available = await _quick.isAvailable();
    final armed = await _quick.isEnabled();
    if (!mounted) return;
    setState(() {
      _available = available;
      _armed = armed;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to offer on a phone with no lock screen, and no row explaining
    // that either — an unavailable control is worse than an absent one.
    if (!_available) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const Icon(Icons.fingerprint_rounded,
                  size: 18, color: ShadowColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _armed
                      ? 'Unlocking with your fingerprint'
                      : 'Unlock with your fingerprint',
                  style: ShadowTypography.body,
                ),
              ),
              Switch(
                value: _armed,
                onChanged: _busy ? null : (want) => want ? _arm() : _disarm(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _armed
                ? 'Your passphrase is on this phone. Anything that opens the '
                    'phone opens your accounts. Turn this off to go back to '
                    'typing it.'
                : 'Right now your passphrase is only in your head, so somebody '
                    'holding your unlocked phone still cannot derive a single '
                    'account. Store it and anything that opens this phone '
                    'opens your accounts too. Your written twelve words stay '
                    'the only way back if you forget it.',
            style: ShadowTypography.caption.copyWith(
              color: _armed ? ShadowColors.warning : ShadowColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  /// Asks for the passphrase again rather than holding it in memory.
  ///
  /// The provider does not keep it — only the branch key derived from it — and
  /// keeping a copy around on the chance somebody later enables this would be
  /// a secret held for no current purpose. Typing it once also proves the
  /// person arming the shortcut is the person who knows it.
  Future<void> _arm() async {
    _confirm.clear();
    final passphrase = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ShadowColors.surfaceElevated,
        title: Text('Your passphrase', style: ShadowTypography.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Type it once so Shadow can check it before storing it. Leave it '
              'empty if that is how you set the identity up.',
              style: ShadowTypography.bodySm,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(hintText: 'passphrase'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_confirm.text),
            child: const Text('Check and store'),
          ),
        ],
      ),
    );
    if (passphrase == null || !mounted) return;

    setState(() => _busy = true);
    final identity = context.read<IdentityProvider>();

    // Verified against the identity that is already open, so a typo cannot
    // arm a fingerprint that opens a different, empty universe of accounts.
    if (!identity.matchesCurrentPassphrase(passphrase)) {
      setState(() => _busy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That is not the passphrase this identity is open with. Nothing '
            'was stored.',
          ),
        ),
      );
      return;
    }

    final stored = await _quick.enable(passphrase);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _armed = stored;
    });

    // A switch that slides back with no explanation is the same defect as a
    // switch that lies: the user tried something, it did not happen, and the
    // screen said nothing. The device check is the only way this fails here.
    if (!stored) {
      final detail = _quick.lastError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail == null
                ? 'The phone did not confirm it was you, so nothing was '
                    'stored. Your passphrase is unchanged.'
                : 'The phone could not check it was you, so nothing was '
                    'stored: $detail',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _disarm() async {
    await _quick.disable();
    if (!mounted) return;
    setState(() => _armed = false);
  }
}
