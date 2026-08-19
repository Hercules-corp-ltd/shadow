import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../mail/claimable_name.dart';
import '../../providers/identity_provider.dart';
import '../../providers/public_address_provider.dart';
import '../../services/mailbox_api.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

/// The one address a person hands to other people.
///
/// ## Why this screen is careful in a way the rest of the app is not
///
/// Everything else Shadow derives is disposable. A password rotates, an alias
/// burns, a site can be forgotten. This cannot. It is chosen rather than
/// derived, it is bound to the identity on the mail service the moment it is
/// claimed, and there is no rename, no transfer and no release — because an
/// address other people have written down cannot be handed to a stranger
/// without making every one of them reachable by that stranger.
///
/// So the screen has one irreversible button, and it refuses to show it until
/// the mail service has confirmed whether this identity already owns a name.
/// A fresh install of an identity that owns one looks identical to an identity
/// that owns nothing, and offering to claim in that state costs the user a
/// name for no reason.
class PublicAddressScreen extends StatefulWidget {
  const PublicAddressScreen({super.key});

  @override
  State<PublicAddressScreen> createState() => _PublicAddressScreenState();
}

class _PublicAddressScreenState extends State<PublicAddressScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _problem;

  @override
  void initState() {
    super.initState();
    // Ask on open when storage has nothing, so the claim field is never live
    // in a state where claiming might overwrite a name the user already owns.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshIfUnknown());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshIfUnknown() async {
    final keys = context.read<IdentityProvider>().publicAddressKeys();
    if (keys == null) return;
    // ensureKnown waits for storage before deciding whether to ask. Checking
    // the state here instead would run while it is still loading, conclude
    // there was nothing to do, and never look — leaving the screen saying it
    // could not reach the mail service when it had not tried.
    await context.read<PublicAddressProvider>().ensureKnown(keys: keys);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final addresses = context.watch<PublicAddressProvider>();
    final identity = context.watch<IdentityProvider>();
    final domain = identity.aliasDomain ?? '';

    return ShadowScaffold(
      title: 'Public address',
      body: !identity.isUnlocked
          ? _locked()
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: <Widget>[
                _explainer(),
                const SizedBox(height: 16),
                switch (addresses.state) {
                  PublicAddressState.loading =>
                    const Center(child: CircularProgressIndicator()),
                  PublicAddressState.unknown => _unknown(addresses),
                  PublicAddressState.none => _claimCard(addresses),
                  PublicAddressState.held => _heldCard(addresses, domain),
                },
              ],
            ),
    );
  }

  Widget _locked() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unlock your identity to see or claim your public address.',
            style: ShadowTypography.bodySm,
            textAlign: TextAlign.center,
          ),
        ),
      );

  Widget _explainer() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('What this is', style: ShadowTypography.h4),
          const SizedBox(height: 8),
          Text(
            'One address, for people. Your per-site aliases are for sites — a '
            'different one each time, so nothing can be joined up. This is the '
            'opposite: one name you give to a person who needs to reach you, '
            'and the same one every time.',
            style: ShadowTypography.bodySm,
          ),
          const SizedBox(height: 10),
          Text(
            'That is a trade, not a feature. Everywhere you use this, you are '
            'the same person — and anyone holding two messages sent to it '
            'knows they came from one identity. Use an alias for anything you '
            'would rather nobody could line up.',
            style: ShadowTypography.caption
                .copyWith(color: ShadowColors.warning),
          ),
        ],
      ),
    );
  }

  /// The state that exists so the claim button does not.
  Widget _unknown(PublicAddressProvider addresses) {
    final problem = addresses.lastProblem;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            addresses.busy
                ? 'Checking for a name'
                : 'Cannot tell yet whether you have one',
            style: ShadowTypography.h4,
          ),
          const SizedBox(height: 8),
          Text(
            // Three different sentences, because they are three different
            // facts. Saying "could not reach it" before anything was attempted
            // reports a failure that never happened.
            addresses.busy
                ? 'Asking the mail service whether this identity already holds '
                    'an address.'
                : addresses.hasAsked
                    ? 'Shadow could not reach the mail service, so it does not '
                        'know whether this identity already holds a name. Do '
                        'not claim one until this succeeds — you only get one, '
                        'and a second claim cannot be undone.'
                    : 'Shadow has not asked the mail service yet. It needs to '
                        'before you claim anything, because an identity that '
                        'already holds a name looks exactly like one that does '
                        'not — and you only get one.',
            style: ShadowTypography.bodySm,
          ),
          if (problem != null && !addresses.busy) ...<Widget>[
            const SizedBox(height: 6),
            Text(problem, style: ShadowTypography.caption),
          ],
          const SizedBox(height: 14),
          ShadowButton(
            label: addresses.hasAsked ? 'Check again' : 'Check now',
            onPressed: addresses.busy ? null : _refreshNow,
          ),
        ],
      ),
    );
  }

  Widget _claimCard(PublicAddressProvider addresses) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Claim a name', style: ShadowTypography.h4),
          const SizedBox(height: 4),
          Text(
            'First come, first served, and permanent. There is no renaming it '
            'later and no giving it up — an address people have written down '
            'cannot be passed to somebody else.',
            style: ShadowTypography.caption,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            style: ShadowTypography.mono,
            decoration: InputDecoration(
              hintText: 'name',
              errorText: _problem,
              errorMaxLines: 4,
            ),
            onChanged: (value) {
              final problem = value.isEmpty ? null : ClaimableName.check(value);
              setState(() {
                _problem =
                    problem == null ? null : ClaimableName.explain(problem);
              });
            },
          ),
          const SizedBox(height: 6),
          Text(
            '${ClaimableName.minLength} to ${ClaimableName.maxLength} '
            'characters, letters a-z and digits 2-7.',
            style: ShadowTypography.caption,
          ),
          const SizedBox(height: 12),
          Text(
            'Claiming does a piece of work on this phone first — seconds on a '
            'new handset, up to a minute on an older one. That cost is what '
            'stands in for an account, and it is what makes grinding through a '
            'list of desirable names expensive. Keep the app open while it runs.',
            style: ShadowTypography.caption,
          ),
          const SizedBox(height: 14),
          ShadowButton(
            label: addresses.busy ? 'Claiming…' : 'Claim this name',
            onPressed: addresses.busy ? null : _claim,
          ),
        ],
      ),
    );
  }

  Widget _heldCard(PublicAddressProvider addresses, String domain) {
    final claimed = addresses.claimed!;
    final address = domain.isEmpty ? claimed.name : '${claimed.name}@$domain';

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Your address', style: ShadowTypography.h4),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: SelectableText(address, style: ShadowTypography.mono),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: address));
                  if (mounted) _toast('Address copied.');
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            claimed.retired
                ? 'Not accepting mail. Anything sent here is refused at the '
                    'door rather than held, so senders get a bounce.'
                : 'Accepting mail.',
            style: ShadowTypography.caption.copyWith(
              color: claimed.retired ? ShadowColors.warning : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Yours for as long as the identity exists. Rotating a password or '
            'burning an alias somewhere does not touch it.',
            style: ShadowTypography.caption,
          ),
          if (addresses.lastProblem != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(addresses.lastProblem!, style: ShadowTypography.caption),
          ],
          const SizedBox(height: 14),
          ShadowButton(
            label: 'Check with the mail service',
            variant: ShadowButtonVariant.secondary,
            onPressed: addresses.busy ? null : _refreshNow,
          ),
        ],
      ),
    );
  }

  Future<void> _refreshNow() async {
    final keys = context.read<IdentityProvider>().publicAddressKeys();
    if (keys == null) {
      _toast('Unlock your identity first.');
      return;
    }
    await context.read<PublicAddressProvider>().refresh(keys: keys);
  }

  Future<void> _claim() async {
    final name = _controller.text.trim();
    final problem = ClaimableName.check(name);
    if (problem != null) {
      setState(() => _problem = ClaimableName.explain(problem));
      return;
    }

    final identity = context.read<IdentityProvider>();
    final addresses = context.read<PublicAddressProvider>();
    final keys = identity.publicAddressKeys();
    if (keys == null) {
      _toast('Unlock your identity first.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Claim $name?', style: ShadowTypography.h3),
        content: Text(
          'This is the only one you get. It cannot be renamed, given up or '
          'transferred, and everywhere you use it you are recognisably the '
          'same person.',
          style: ShadowTypography.bodySm,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Claim it'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await addresses.claim(keys: keys, name: name);
    if (!mounted) return;

    switch (result) {
      case ClaimHeld(name: final held):
        _controller.clear();
        setState(() => _problem = null);
        // Not necessarily what they typed. One identity holds one name, so a
        // claim from a key that already has one returns the one it has —
        // which is exactly how a reinstall gets its address back, and must be
        // said out loud rather than looking like the claim succeeded as asked.
        _toast(held == name
            ? '$held is yours.'
            : 'This identity already had $held, so that is the one you keep.');
      case ClaimTaken():
        setState(() => _problem = 'Somebody already holds that name.');
      case ClaimRefused(reason: final reason):
        setState(() => _problem = switch (reason) {
              // Never "pick another": the shape was checked before mining, so
              // by here the likely cause is a reserved name or a clock too far
              // out — and the name may well still be free.
              ClaimRefusal.refusedName =>
                'The mail service refused this attempt. That name may be '
                    'reserved, or this phone\'s clock may be off. The name '
                    'may still be free — worth trying again.',
              ClaimRefusal.needsMoreWork =>
                'The mail service wants more work than this version does. '
                    'Nothing was claimed.',
              ClaimRefusal.rejectedKey =>
                'The mail service would not accept this device\'s signature. '
                    'Nothing was claimed.',
            });
      case ClaimUnreachable():
        setState(() => _problem =
            'Could not reach the mail service. Shadow does not know whether '
            '$name was claimed — try again with the same name and it will '
            'find out.');
      case ClaimNone():
        setState(() => _problem =
            'The mail service gave an answer Shadow did not expect.');
    }
  }
}
