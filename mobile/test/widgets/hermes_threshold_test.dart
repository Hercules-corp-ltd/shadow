import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/widgets/hermes_threshold.dart';

/// The unlock gate.
///
/// Four hundred lines of CustomPainter standing between a correct fingerprint
/// and the wallet. It is the only thing on screen while it plays, so a paint
/// exception here is not a visual glitch — it is a red screen on the unlock
/// path, reached by the user who did everything right.
///
/// These tests pump it across its whole life rather than asserting on pixels.
/// Nothing here can tell you it looks good; they can only tell you it never
/// throws, that it finishes, and that it takes the length of time the lock
/// screen has been told to wait for.
void main() {
  Future<void> pumpGate(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HermesThreshold()));
  }

  testWidgets('paints every frame of the doors parting without throwing',
      (tester) async {
    await pumpGate(tester);

    // Step through the open in small increments: a painter that divides by a
    // value which is zero only at t = 0, or only at t = 1, is exactly the kind
    // of bug a single mid-animation pump sails past.
    const steps = 24;
    final slice = kHermesGateOpenDuration ~/ steps;
    for (var i = 0; i < steps; i++) {
      await tester.pump(slice);
      expect(tester.takeException(), isNull, reason: 'threw at step $i');
    }
    await tester.pump(kHermesGateOpenDuration);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps painting past the hold without throwing', (tester) async {
    await pumpGate(tester);
    await tester.pump(kHermesGateHold);
    expect(tester.takeException(), isNull);

    // Deliberately NOT pumpAndSettle. The Hermes sigil pulses on
    // `.animate(onPlay: (c) => c.repeat(reverse: true))`, so this widget never
    // quiesces by design and pumpAndSettle times out on it every time. That is
    // not a leak — the controller dies with the widget, and the widget lives
    // about a second and a half — but it does mean the gate must never be the
    // thing a test tries to settle, and it means the compositor stays awake for
    // as long as the gate is up. Both are fine at 1.6s and neither would be at
    // the 5.8s this shipped with.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: 'threw after the hold');
    }
  });

  testWidgets('the animation fits inside the hold the lock screen waits for',
      (tester) async {
    // The lock screen shows this, waits kHermesGateHold, then navigates. If the
    // doors took longer to part than the hold, it would cut its own animation
    // off partway on every unlock.
    expect(
      kHermesGateOpenDuration,
      lessThanOrEqualTo(kHermesGateHold),
      reason: 'the gate would be navigated away from before it finished opening',
    );
    // And it has to stay short enough to be a flourish rather than a wait. It
    // shipped at 5.8 seconds once; that is a loading screen, paid on every
    // single unlock by someone who has already proved who they are.
    expect(
      kHermesGateHold,
      lessThanOrEqualTo(const Duration(milliseconds: 2000)),
      reason: 'an unskippable gate longer than two seconds is a toll, not a '
          'flourish',
    );
  });

  testWidgets('disposing mid-animation does not throw', (tester) async {
    await pumpGate(tester);
    await tester.pump(kHermesGateOpenDuration ~/ 3);
    // The lock screen can be torn down here — a lifecycle event, the wallet
    // being locked from elsewhere, a failed decrypt dropping the gate.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out on the smallest phone anyone still runs', (tester) async {
    // 320x568 is the first-generation iPhone SE, and the floor worth holding.
    // The gate is a Column of fixed-height pieces separated by Spacers, so a
    // short viewport is where it runs out of room — at 240x400 it overflows the
    // bottom by 20px, which is below any real device and is not being chased.
    await pumpGate(tester, size: const Size(320, 568));
    await tester.pump(kHermesGateOpenDuration ~/ 2);
    expect(tester.takeException(), isNull, reason: 'overflowed mid-animation');
    await tester.pump(kHermesGateHold);
    expect(tester.takeException(), isNull, reason: 'overflowed at rest');
  });
}
