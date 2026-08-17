import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/site_adapter_record.dart';
import '../../providers/identity_provider.dart';
import '../../providers/mailbox_provider.dart';
import '../../providers/site_adapter_provider.dart';
import '../../services/fetch_outcome.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

/// One site: how Shadow behaves there, and what to do when it goes wrong.
///
/// The two things that "go wrong" are different and must not share a
/// control. A site forcing a password reset needs a new password and the
/// same address. An address that has started attracting spam needs a new
/// address and the same password. One button for both is how a user loses
/// an account trying to fix a nuisance.
class SiteDetailScreen extends StatefulWidget {
  const SiteDetailScreen({
    super.key,
    required this.domain,
    this.accountIndex = 0,
  });

  final String domain;
  final int accountIndex;

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  SiteAdapterRecord? _record;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final record = await context
        .read<SiteAdapterProvider>()
        .resolve(widget.domain, accountIndex: widget.accountIndex);
    if (!mounted) return;
    setState(() => _record = record);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    await action();
    await _reload();
    if (mounted) setState(() => _busy = false);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// The address for a given epoch, or null while locked.
  String? _addressFor(int aliasEpoch) {
    final identity = context.read<IdentityProvider>();
    final keys = identity.mailboxKeysFor(
      widget.domain,
      accountIndex: widget.accountIndex,
      aliasEpoch: aliasEpoch,
    );
    final domain = identity.aliasDomain;
    if (keys == null || domain == null || domain.isEmpty) return null;
    return keys.addressAt(domain);
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;

    return ShadowScaffold(
      title: widget.domain,
      body: record == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: <Widget>[
                _addressCard(record),
                const SizedBox(height: 16),
                _modeCard(record),
                const SizedBox(height: 16),
                if (record.account.isBurning)
                  _burnInProgressCard(record)
                else
                  _maintenanceCard(record),
              ],
            ),
    );
  }

  Widget _addressCard(SiteAdapterRecord record) {
    final address = _addressFor(record.account.aliasEpoch);
    final mailbox = record.account.mailbox;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Address for this site', style: ShadowTypography.h4),
          const SizedBox(height: 8),
          if (address == null)
            Text(
              'Unlock your identity to see it.',
              style: ShadowTypography.bodySm,
            )
          else
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
            switch (mailbox.state) {
              MailboxState.registered => 'Registered and receiving.',
              MailboxState.failed =>
                'Not registered — mail sent here would not arrive. '
                    'Filling on this site again will try once more.',
              MailboxState.retired => 'Retired. This address is closed.',
              MailboxState.none => 'No mailbox yet. One is created the first '
                  'time you fill an identity here.',
            },
            style: ShadowTypography.caption,
          ),
          if (record.account.registeredHandle != null) ...<Widget>[
            const SizedBox(height: 10),
            Text('Signed up as', style: ShadowTypography.caption),
            Text(record.account.registeredHandle!,
                style: ShadowTypography.mono),
          ],
        ],
      ),
    );
  }

  Widget _modeCard(SiteAdapterRecord record) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('How Shadow behaves here', style: ShadowTypography.h4),
          const SizedBox(height: 4),
          Text(
            'Sticky for this site. Nothing changes on any other.',
            style: ShadowTypography.caption,
          ),
          const SizedBox(height: 8),
          RadioGroup<SiteMode>(
            groupValue: record.account.mode,
            onChanged: (value) {
              // RadioGroup takes a non-nullable callback, so the busy check
              // lives here rather than in whether one is supplied.
              if (value == null || _busy) return;
              _run(() => context.read<SiteAdapterProvider>().setMode(
                    widget.domain,
                    value,
                    accountIndex: widget.accountIndex,
                  ));
            },
            child: Column(
              children: <Widget>[
                for (final mode in SiteMode.values)
                  RadioListTile<SiteMode>(
                    value: mode,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: ShadowColors.primary,
                    title: Text(
                      switch (mode) {
                        SiteMode.off => 'Normal browsing',
                        SiteMode.masked => 'Masked identity',
                        SiteMode.public => 'Your shareable handle',
                      },
                      style: ShadowTypography.body,
                    ),
                    subtitle: Text(
                      switch (mode) {
                        SiteMode.off =>
                          'No derived identity, and the mail service is never '
                              'told about this site.',
                        SiteMode.masked =>
                          'An address, password and username only this site '
                              'ever sees.',
                        SiteMode.public =>
                          'Your one public address, so people can reach you '
                              'here. Not unlinkable — that is the trade.',
                      },
                      style: ShadowTypography.caption,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _maintenanceCard(SiteAdapterRecord record) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('When something goes wrong', style: ShadowTypography.h4),
          const SizedBox(height: 12),

          Text('This site made me reset my password',
              style: ShadowTypography.body),
          const SizedBox(height: 2),
          Text(
            'Derives a new password and keeps the same address, so the '
            'account and its mailbox both survive. Currently on '
            'v${record.account.passwordEpoch}.',
            style: ShadowTypography.caption,
          ),
          const SizedBox(height: 10),
          ShadowButton(
            label: 'New password for this site',
            variant: ShadowButtonVariant.secondary,
            onPressed: _busy ? null : _confirmRotatePassword,
          ),

          const SizedBox(height: 22),

          Text('This address is getting spam', style: ShadowTypography.body),
          const SizedBox(height: 2),
          Text(
            'Replaces the address and keeps the same password. Both stay '
            'live until you tell Shadow the site has been updated, so '
            'nothing is lost in between.',
            style: ShadowTypography.caption,
          ),
          const SizedBox(height: 10),
          ShadowButton(
            label: 'Replace this address',
            variant: ShadowButtonVariant.secondary,
            onPressed: _busy ? null : _confirmBeginBurn,
          ),
        ],
      ),
    );
  }

  /// The middle of a two-phase burn.
  ///
  /// This state exists because adopting the new epoch straight away would
  /// strand the user: the record would say v2 while the site still mails v1,
  /// and the old mailbox would already be gone.
  Widget _burnInProgressCard(SiteAdapterRecord record) {
    final pending = record.account.pendingAliasEpoch!;
    final next = _addressFor(pending);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.local_fire_department_rounded,
                  size: 18, color: ShadowColors.warning),
              const SizedBox(width: 8),
              Text('Replacing the address', style: ShadowTypography.h4),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Change the address at ${widget.domain} to this one, then come '
            'back and confirm. Both are receiving until you do.',
            style: ShadowTypography.bodySm,
          ),
          const SizedBox(height: 12),
          if (next != null)
            Row(
              children: <Widget>[
                Expanded(
                  child: SelectableText(next, style: ShadowTypography.mono),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: next));
                    if (mounted) _toast('New address copied.');
                  },
                ),
              ],
            ),
          const SizedBox(height: 16),
          ShadowButton(
            label: 'The site has the new address',
            onPressed: _busy ? null : _confirmCommitBurn,
          ),
          const SizedBox(height: 8),
          ShadowButton(
            label: 'Cancel — keep the old one',
            variant: ShadowButtonVariant.secondary,
            onPressed: _busy
                ? null
                : () => _run(() async {
                      await context.read<SiteAdapterProvider>().abandonAliasBurn(
                            widget.domain,
                            accountIndex: widget.accountIndex,
                          );
                      if (mounted) _toast('Kept the old address.');
                    }),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRotatePassword() async {
    final ok = await _confirm(
      title: 'New password for ${widget.domain}?',
      body: 'Shadow will derive a different password from now on. Change it '
          'at the site as well — otherwise the one Shadow fills will no '
          'longer be the one the site knows.\n\n'
          'Your address here does not change.',
      action: 'Rotate',
    );
    if (ok != true) return;

    await _run(() async {
      await context.read<SiteAdapterProvider>().rotatePassword(
            widget.domain,
            accountIndex: widget.accountIndex,
          );
      if (mounted) _toast('Set the new password at ${widget.domain} now.');
    });
  }

  Future<void> _confirmBeginBurn() async {
    final ok = await _confirm(
      title: 'Replace the address for ${widget.domain}?',
      body: 'Shadow will start using a new address here. The old one keeps '
          'receiving until you confirm the site has been updated, so nothing '
          'in flight is lost.\n\n'
          'Your password here does not change.',
      action: 'Replace',
    );
    if (ok != true) return;

    await _run(() async {
      await context.read<SiteAdapterProvider>().beginAliasBurn(
            widget.domain,
            accountIndex: widget.accountIndex,
          );
    });
  }

  Future<void> _confirmCommitBurn() async {
    final ok = await _confirm(
      title: 'Close the old address?',
      body: 'Only do this once ${widget.domain} is actually sending to the '
          'new one. Anything still addressed to the old one will stop '
          'arriving — including a password reset.',
      action: 'Close it',
    );
    if (ok != true) return;

    await _run(() async {
      final record = _record;
      final adapters = context.read<SiteAdapterProvider>();
      final mailbox = context.read<MailboxProvider>();
      final identity = context.read<IdentityProvider>();

      // Retire the old mailbox server-side before adopting the new epoch, so
      // a failure here leaves the burn resumable rather than half-done.
      //
      // If the server could not be reached, stop. The user is here because
      // the old address is attracting mail they do not want; finishing the
      // burn now would move Shadow onto the new address and tell them the
      // old one is shut while it quietly keeps collecting. Both addresses
      // stay live instead, which is where they already were, and the button
      // is still here when there is a network again.
      if (record != null) {
        final oldKeys = identity.mailboxKeysFor(
          widget.domain,
          accountIndex: widget.accountIndex,
          aliasEpoch: record.account.aliasEpoch,
        );
        if (oldKeys != null) {
          final outcome = await mailbox.retire(keys: oldKeys);
          if (outcome is FetchUnreachable<void>) {
            if (mounted) {
              _toast('Could not reach the mail service, so the old address is '
                  'still open. Both keep receiving — try again later.');
            }
            return;
          }
        }
      }

      await adapters.commitAliasBurn(
        widget.domain,
        accountIndex: widget.accountIndex,
      );
      if (mounted) _toast('The old address is closed.');
    });
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String action,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ShadowColors.surfaceElevated,
        title: Text(title, style: ShadowTypography.h3),
        content: Text(body, style: ShadowTypography.bodySm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}
