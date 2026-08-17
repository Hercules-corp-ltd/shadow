import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/identity_provider.dart';
import '../../providers/site_adapter_provider.dart';
import '../../services/adapter_backup.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

/// Moving the per-site state between devices.
///
/// ## Why this is not covered by the recovery phrase
///
/// The phrase regenerates credentials. It does not regenerate the *state*
/// saying which ones are current — that a site forced a reset and you are on
/// your third password there. The mail server can be asked which address a
/// site is on, because it holds the mailbox. It has never seen anything
/// derived from the password counter, and never should.
///
/// So a phrase alone restores a working identity with every counter back at
/// one. For anyone who has rotated anything, this file is the difference.
class IdentityBackupScreen extends StatefulWidget {
  const IdentityBackupScreen({super.key});

  @override
  State<IdentityBackupScreen> createState() => _IdentityBackupScreenState();
}

class _IdentityBackupScreenState extends State<IdentityBackupScreen> {
  final TextEditingController _importController = TextEditingController();
  bool _busy = false;
  int _siteCount = 0;

  @override
  void initState() {
    super.initState();
    _countSites();
  }

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  Future<void> _countSites() async {
    final records = await context.read<SiteAdapterProvider>().configured();
    if (!mounted) return;
    setState(() => _siteCount = records.length);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = context.watch<IdentityProvider>().isUnlocked;

    return ShadowScaffold(
      title: 'Backup',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('What this is for', style: ShadowTypography.h4),
                const SizedBox(height: 8),
                Text(
                  'Your twelve words rebuild every password and address from '
                  'scratch. What they cannot rebuild is which one is current: '
                  'if a site made you reset, you are on your second or third '
                  'password there, and only this device knows that.\n\n'
                  'Shadow can ask the mail server which address a site is on, '
                  'because the server holds the mailbox. It has never been '
                  'told anything about your passwords, and it should stay '
                  'that way. This file is how that part travels.',
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
              children: <Widget>[
                Text('Save a backup', style: ShadowTypography.h4),
                const SizedBox(height: 4),
                Text(
                  _siteCount == 0
                      ? 'No sites recorded yet, so there is nothing to save.'
                      : '$_siteCount site${_siteCount == 1 ? '' : 's'}.',
                  style: ShadowTypography.caption,
                ),
                const SizedBox(height: 10),
                Text(
                  'Encrypted to your recovery phrase, so it is useless to '
                  'anyone without it — and useless to you without it too. '
                  'Keep it somewhere you would keep the words.',
                  style: ShadowTypography.caption,
                ),
                const SizedBox(height: 6),
                Text(
                  'It lists the sites you have accounts on. That is worth '
                  'protecting on its own, whatever the passwords are.',
                  style: ShadowTypography.caption
                      .copyWith(color: ShadowColors.warning),
                ),
                const SizedBox(height: 14),
                ShadowButton(
                  label: 'Copy backup to clipboard',
                  onPressed: (_busy || !unlocked || _siteCount == 0)
                      ? null
                      : _export,
                ),
                if (!unlocked) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('Unlock your identity first.',
                      style: ShadowTypography.caption),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Restore one', style: ShadowTypography.h4),
                const SizedBox(height: 4),
                Text(
                  'Merged with what is already here, taking the newer of each '
                  'counter. A backup can add sites and move them forward; it '
                  'never moves this device backwards.',
                  style: ShadowTypography.caption,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _importController,
                  maxLines: 4,
                  autocorrect: false,
                  style: ShadowTypography.caption,
                  decoration: const InputDecoration(
                    hintText: 'Paste a backup here',
                  ),
                ),
                const SizedBox(height: 12),
                ShadowButton(
                  label: 'Restore',
                  variant: ShadowButtonVariant.secondary,
                  onPressed: (_busy || !unlocked) ? null : _import,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final identity = context.read<IdentityProvider>();
      final key = identity.backupKey();
      if (key == null) {
        _toast('Unlock your identity first.');
        return;
      }

      final records = await context.read<SiteAdapterProvider>().configured();
      final blob = await AdapterBackup.export(records: records, backupKey: key);
      await Clipboard.setData(ClipboardData(text: blob));
      if (mounted) _toast('Backup copied. Paste it somewhere safe.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final contents = _importController.text.trim();
    if (contents.isEmpty) {
      _toast('Paste a backup first.');
      return;
    }

    setState(() => _busy = true);
    try {
      final identity = context.read<IdentityProvider>();
      final adapters = context.read<SiteAdapterProvider>();
      final key = identity.backupKey();
      if (key == null) {
        _toast('Unlock your identity first.');
        return;
      }

      final imported = await AdapterBackup.import(
        contents: contents,
        backupKey: key,
      );
      final merged = AdapterBackup.merge(
        current: await adapters.configured(),
        imported: imported,
      );

      for (final record in merged) {
        await adapters.upsert(record);
      }

      if (!mounted) return;
      _importController.clear();
      await _countSites();
      if (mounted) {
        _toast('Restored ${imported.length} site'
            '${imported.length == 1 ? '' : 's'}.');
      }
    } on BackupFailure catch (e) {
      // Three different things, three different sentences. "Could not
      // import" leaves someone re-typing a correct phrase at a file that was
      // never going to open.
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
