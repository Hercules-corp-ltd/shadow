import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/wallet_provider.dart';
import '../../services/quick_unlock.dart';
import '../../theme/shadow_colors.dart';
import '../../theme/shadow_typography.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/hermes_threshold.dart';
import '../../widgets/shadow_button.dart';

class WalletLockedScreen extends StatefulWidget {
  const WalletLockedScreen({super.key});

  @override
  State<WalletLockedScreen> createState() => _WalletLockedScreenState();
}

class _WalletLockedScreenState extends State<WalletLockedScreen> {
  final _password = TextEditingController();
  final QuickUnlock _quick = QuickUnlock(slot: QuickUnlockSlot.wallet);

  bool _loading = false;
  String? _error;
  bool _remember = false;
  bool _canRemember = false;
  bool _armed = false;

  /// True while the Hermes gate is on screen.
  bool _gate = false;

  /// Held from initState rather than read from `context` on the way out:
  /// dispose() runs after the element is defunct, and looking a provider up
  /// through a defunct context throws. This is the reference the safety net at
  /// the bottom of dispose() uses.
  late final WalletProvider _wallet = context.read<WalletProvider>();

  @override
  void initState() {
    super.initState();
    _readQuickState();
  }

  @override
  void dispose() {
    _password.dispose();
    // The gate is a flag on a provider that outlives this screen, and while it
    // is set the router will not move an unlocked user off the lock screen. If
    // this widget goes away mid-animation — a lifecycle event, a hot reload, a
    // route replaced underneath it — nothing else would ever lower it, and the
    // app would sit unlocked on the lock screen with no way forward.
    _wallet.closeGate();
    super.dispose();
  }

  Future<void> _readQuickState() async {
    final available = await _quick.isAvailable();
    final armed = await _quick.isEnabled();
    if (!mounted) return;
    setState(() {
      _canRemember = available;
      _armed = armed;
    });
    // Offered straight away when armed. Making somebody reach for a button to
    // avoid typing a password they asked not to type is most of the friction
    // back again.
    if (armed) await _unlockWithDevice();
  }

  Future<void> _unlockWithDevice() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // QuickUnlock.unlock reads and deletes through flutter_secure_storage,
    // which throws PlatformException on a corrupted Android keystore. That
    // throw used to escape as an unhandled async error with _loading still
    // true — so the primary Unlock button stayed a disabled spinner for the
    // life of the screen, with nothing said, on the screen whose only job is
    // getting back into the wallet.
    final QuickUnlockResult result;
    try {
      result = await _quick.unlock();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not ask the phone to unlock. '
            'Type your password instead.';
      });
      return;
    }
    if (!mounted) return;

    if (!result.succeeded) {
      setState(() => _loading = false);
      final problem = result.problem;
      if (problem != null && problem != QuickUnlockProblem.notSet) {
        setState(() => _error = QuickUnlock.explain(problem));
      }
      return;
    }

    // The gate goes up BEFORE the wallet opens, and the order is the whole
    // trick. unlockWallet() flips the lifecycle to unlocked and notifies, the
    // router is listening, and its redirect would replace this screen on that
    // same frame. Raising the flag first tells the redirect to hold.
    //
    // Only on this path. Typing a password gets you in immediately — the gate
    // is the answer to being recognised without the word, so it belongs to the
    // gesture that skipped the word.
    _wallet.openGate();
    if (mounted) setState(() => _gate = true);
    final startedAt = DateTime.now();

    try {
      await _wallet.unlockWallet(result.passphrase!);
    } catch (_) {
      // The stored password no longer opens this wallet — changed, or the
      // wallet was replaced. Drop it rather than going on offering a
      // fingerprint that cannot work again.
      _wallet.closeGate();
      await _quick.disable();
      if (!mounted) return;
      setState(() {
        _gate = false;
        _armed = false;
        _loading = false;
        _error = 'The remembered password no longer opens this wallet, so '
            'Shadow has forgotten it. Type it instead.';
      });
      return;
    }

    // Whatever is left of the animation. Decrypting is local and takes a few
    // milliseconds, so this is nearly the whole hold — but it is written as a
    // remainder rather than a fixed sleep so a slow device spends its time
    // working instead of adding to it.
    final spent = DateTime.now().difference(startedAt);
    final remaining = kHermesGateHold - spent;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }

    // Lowering the flag is what actually completes the journey: the router
    // re-evaluates, sees an unlocked wallet on the lock screen, and sends us
    // home. The explicit go() below is for the case where this screen is
    // somehow no longer the one being redirected.
    _wallet.closeGate();
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _unlock() async {
    if (_password.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<WalletProvider>().unlockWallet(_password.text);
      if (!mounted) return;
      // Stored only after a password that actually opened the wallet, and
      // before navigating, so the screen is still alive to say so if the
      // device check is refused.
      if (_remember && !_armed) {
        final stored = await _quick.enable(_password.text);
        if (!mounted) return;
        if (!stored) {
          final detail = _quick.lastError;
          setState(() {
            _error = detail == null
                ? 'The phone did not confirm it was you, so the password was '
                    'not remembered.'
                : 'Could not remember the password: $detail';
          });
        }
      }
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() {
        _error = 'Incorrect password';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The gate replaces the screen rather than covering it. It is opaque and
    // full-bleed, so stacking it would only mean laying out a password form
    // nobody can see behind an animation.
    if (_gate) return const HermesThreshold(key: ValueKey('hermes-gate'));

    final wallet = context.watch<WalletProvider>();
    final addr = wallet.walletAddress ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GridBackground(
        child: SafeArea(
          // Scrollable, with a floor of the viewport height so the Spacers
          // still centre things when there is room. Adding the remember
          // checkbox pushed this 21px past the screen with the keyboard up —
          // a real overflow on a short handset, not just on the emulator.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Spacer(),
                        // A socket with the lock lit inside it, not a grey coin. This
                        // is the first thing seen on a cold launch, so it is the one
                        // shape that decides whether the app looks like Shadow before
                        // anything else has loaded.
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: ShadowColors.recessDeep,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  ShadowColors.primary.withValues(alpha: 0.26),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: ShadowColors.primary
                                    .withValues(alpha: 0.16),
                                blurRadius: 34,
                                spreadRadius: -6,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.lock_rounded,
                              color: ShadowColors.primary, size: 40),
                        ),
                        const SizedBox(height: 24),
                        Text('Wallet locked',
                            style: ShadowTypography.displayMd),
                        const SizedBox(height: 8),
                        Text(
                          addr.isEmpty
                              ? 'Enter your password to unlock'
                              : '${addr.substring(0, 6)}…${addr.substring(addr.length - 6)}',
                          style: ShadowTypography.bodySm,
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          autofocus: true,
                          onSubmitted: (_) => _unlock(),
                          decoration:
                              const InputDecoration(hintText: 'Password'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!,
                              style: ShadowTypography.bodySm
                                  .copyWith(color: ShadowColors.error)),
                        ],
                        // A checkbox rather than a card offered afterwards: this screen
                        // is replaced the instant the wallet opens, so anything shown
                        // after a successful unlock cannot be read. Asked before, it
                        // is also just the familiar "remember me".
                        if (_canRemember && !_armed) ...<Widget>[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => setState(() => _remember = !_remember),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: <Widget>[
                                  Checkbox(
                                    value: _remember,
                                    onChanged: (v) =>
                                        setState(() => _remember = v ?? false),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Remember this password and unlock with my '
                                      'fingerprint',
                                      style: ShadowTypography.bodySm,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_remember)
                            Text(
                              'Stored on this phone. Anything that opens the phone '
                              'then opens the wallet.',
                              style: ShadowTypography.caption
                                  .copyWith(color: ShadowColors.warning),
                            ),
                        ],
                        const SizedBox(height: 16),
                        ShadowButton(
                          label: 'Unlock',
                          isLoading: _loading,
                          onPressed: _loading ? null : _unlock,
                          size: ShadowButtonSize.lg,
                        ),
                        if (_armed) ...<Widget>[
                          const SizedBox(height: 10),
                          ShadowButton(
                            label: 'Use my fingerprint',
                            variant: ShadowButtonVariant.secondary,
                            onPressed: _loading ? null : _unlockWithDevice,
                          ),
                        ],
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete wallet?'),
                                content: Text(
                                  context
                                              .read<WalletProvider>()
                                              .hasRecoveryPhrase ==
                                          true
                                      ? 'This erases the encrypted wallet from this '
                                          'device. You can restore it from your '
                                          'twelve words.'
                                      : 'This wallet has no recovery phrase, so the '
                                          'key on this device is the only copy. '
                                          'Deleting it destroys the wallet and any '
                                          'funds in it, permanently.',
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (confirm == true && context.mounted) {
                              // The destructive branch had no catch either:
                              // deleteWallet awaits seven removals and then a
                              // sign-out, and a throw anywhere in there meant
                              // the navigation never ran and the user was left
                              // on the locked screen with no idea whether the
                              // deletion they had just confirmed had happened.
                              try {
                                await context
                                    .read<WalletProvider>()
                                    .deleteWallet();
                              } catch (_) {
                                if (!context.mounted) return;
                                setState(() => _error =
                                    'Deleting did not finish. Some of the '
                                    'wallet may already be gone — check '
                                    'before relying on it.');
                                return;
                              }
                              if (context.mounted) context.go('/welcome');
                            }
                          },
                          child: const Text('Forgot password? Delete wallet'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
