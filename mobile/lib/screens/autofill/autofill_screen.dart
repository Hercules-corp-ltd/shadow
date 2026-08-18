import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../autofill/fill_target.dart';
import '../../providers/identity_provider.dart';
import '../../providers/site_adapter_provider.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/shadow_button.dart';
import '../../widgets/shadow_scaffold.dart';

/// The screen another app's login form sends you to.
///
/// Opened by `AutofillUnlockActivity`, which is itself launched by the
/// platform when somebody taps Shadow in an autofill popup. It exists because
/// the autofill service cannot derive anything: the branch key is in this
/// isolate and is wiped on lock, so a value can only be made here, after an
/// unlock, and handed back.
///
/// Kept deliberately plain. It appears over whatever the person was doing,
/// they are mid-login somewhere else, and the only two things worth saying are
/// which site Shadow thinks this is and what it is about to type.
class AutofillScreen extends StatefulWidget {
  const AutofillScreen({super.key});

  @override
  State<AutofillScreen> createState() => _AutofillScreenState();
}

class _AutofillScreenState extends State<AutofillScreen> {
  static const MethodChannel _channel = MethodChannel('app.shadow/autofill');

  final TextEditingController _passphrase = TextEditingController();
  FillDecision? _decision;
  List<String> _kinds = const <String>[];
  String? _problem;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('request');
      if (raw == null || !mounted) return;

      final kinds = (raw['kinds'] as List<dynamic>? ?? <dynamic>[])
          .map((k) => k.toString())
          .toList();
      final request = AutofillRequest(
        packageName: raw['package'] as String? ?? '',
        browserTrusted: raw['browserTrusted'] as bool? ?? false,
        webDomains: (raw['webDomains'] as List<dynamic>? ?? <dynamic>[])
            .map((d) => d.toString())
            .toList(),
        wantsPassword: kinds.contains('PASSWORD'),
        wantsUsername: kinds.contains('USERNAME'),
        wantsEmail: kinds.contains('EMAIL'),
      );

      setState(() {
        _kinds = kinds;
        _decision = FillTarget.decide(request);
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => _problem = e.message ?? 'Could not read the request.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final decision = _decision;

    return ShadowScaffold(
      title: 'Fill from Shadow',
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          if (_problem != null)
            _card('Something went wrong', _problem!)
          else if (decision == null)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ))
          else if (decision is FillRefused)
            _card('Shadow will not fill this',
                FillTarget.explain(decision.reason))
          else if (decision is FillFor)
            _unlockCard(decision.domain),
          const SizedBox(height: 12),
          ShadowButton(
            label: 'Cancel',
            variant: ShadowButtonVariant.ghost,
            onPressed: _busy ? null : () => _channel.invokeMethod<void>('cancel'),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, String body) => GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: ShadowTypography.h4),
            const SizedBox(height: 8),
            Text(body, style: ShadowTypography.bodySm),
          ],
        ),
      );

  Widget _unlockCard(String domain) {
    final identity = context.watch<IdentityProvider>();

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Sign in to $domain', style: ShadowTypography.h4),
          const SizedBox(height: 6),
          Text(
            // Naming the site is the whole safety of this screen. Everything
            // Shadow is about to type is derived from that one word, and if
            // it is not the site the person thinks they are on, this is the
            // moment to notice.
            'Shadow will fill the identity it derives for this site, and '
            'nothing from any other. Check the name above matches the page '
            'you are on.',
            style: ShadowTypography.caption,
          ),
          const SizedBox(height: 10),
          Text(
            _describe(_kinds),
            style: ShadowTypography.caption.copyWith(color: ShadowColors.primary),
          ),
          if (!identity.isUnlocked) ...<Widget>[
            const SizedBox(height: 14),
            TextField(
              controller: _passphrase,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                hintText: 'passphrase (or leave empty)',
              ),
            ),
          ],
          const SizedBox(height: 14),
          ShadowButton(
            label: _busy ? 'Filling…' : 'Fill',
            onPressed: _busy ? null : () => _fill(domain),
          ),
        ],
      ),
    );
  }

  static String _describe(List<String> kinds) {
    final parts = <String>[
      if (kinds.contains('EMAIL')) 'the alias for this site',
      if (kinds.contains('USERNAME')) 'a username',
      if (kinds.contains('PASSWORD')) 'the password',
    ];
    if (parts.isEmpty) return 'Nothing to fill.';
    return 'About to fill ${parts.join(', ')}.';
  }

  Future<void> _fill(String domain) async {
    setState(() {
      _busy = true;
      _problem = null;
    });

    try {
      final identity = context.read<IdentityProvider>();
      // Read both providers before the first await. After it this State may
      // have been torn down, and reaching back through context then is how a
      // fill ends in a crash over somebody else's login form.
      final adapters = context.read<SiteAdapterProvider>();

      if (!identity.isUnlocked) {
        final ok = await identity.unlock(passphrase: _passphrase.text);
        if (!mounted) return;
        if (!ok) {
          setState(() => _problem = identity.error ?? 'That passphrase did not work.');
          return;
        }
      }

      final record = await adapters.resolve(domain);
      if (!mounted) return;
      final site = identity.identityFor(
        domain,
        passwordEpoch: record.account.passwordEpoch,
        aliasEpoch: record.account.aliasEpoch,
        policy: record.policy.passwordPolicy,
      );
      if (site == null) {
        setState(() => _problem = 'Shadow could not derive an identity here.');
        return;
      }

      await _channel.invokeMethod<bool>('fill', <String, String>{
        if (_kinds.contains('PASSWORD')) 'PASSWORD': site.password,
        if (_kinds.contains('USERNAME')) 'USERNAME': site.handle,
        if (_kinds.contains('EMAIL')) 'EMAIL': site.email,
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => _problem = e.message ?? 'Could not fill.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
