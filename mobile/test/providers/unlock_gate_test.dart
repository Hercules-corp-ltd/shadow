import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/providers/wallet_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The unlock gate flag.
///
/// This is a one-bit piece of state with a nasty failure mode, which is exactly
/// the kind worth pinning down. While it is raised the router refuses to move an
/// unlocked user off `/wallet/locked` — that is its whole job, because unlocking
/// is what starts the animation and the redirect would otherwise tear the screen
/// down on the frame it began.
///
/// The consequence of leaving it raised is not a cosmetic glitch. It is an
/// unlocked wallet pinned to its own lock screen with no route forward. So every
/// exit has to lower it, including the ones nobody plans for, and these tests
/// exist to say so out loud rather than to check a getter returns what was set.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts down', () {
    expect(WalletProvider().gateOpen, isFalse);
  });

  test('raising and lowering each notify exactly once, and only on a change', () {
    final p = WalletProvider();
    var notifications = 0;
    p.addListener(() => notifications++);

    p.openGate();
    expect(p.gateOpen, isTrue);
    expect(notifications, 1);

    // Idempotent. The lock screen calls this from more than one place and
    // dispose() calls it unconditionally, so a redundant call must not churn
    // the router's refreshListenable.
    p.openGate();
    expect(notifications, 1);

    p.closeGate();
    expect(p.gateOpen, isFalse);
    expect(notifications, 2);

    p.closeGate();
    expect(notifications, 2);
  });

  test('locking lowers it', () {
    final p = WalletProvider()..openGate();
    p.lock();
    expect(
      p.gateOpen,
      isFalse,
      reason: 'a gate surviving lock() would strand the next unlock on the '
          'lock screen it is meant to be leaving',
    );
  });

  test('deleting the wallet lowers it', () async {
    final p = WalletProvider()..openGate();
    await p.deleteWallet();
    expect(p.gateOpen, isFalse);
  });

  test('lowering it is safe when it was never raised', () {
    // dispose() on the lock screen calls closeGate() unconditionally, and the
    // overwhelmingly common case is a screen that never played the animation
    // at all — a password unlock, or a back-out.
    final p = WalletProvider();
    var notifications = 0;
    p.addListener(() => notifications++);
    p.closeGate();
    expect(p.gateOpen, isFalse);
    expect(notifications, 0);
  });
}
