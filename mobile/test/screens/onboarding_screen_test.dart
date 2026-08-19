import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/screens/onboarding/onboarding_screen.dart';
import 'package:shadow_mobile/screens/onboarding/welcome_screen.dart';
import 'package:shadow_mobile/theme/shadow_theme.dart';

/// The first two screens of the app, which are the hardest ones to reach.
///
/// Once a wallet exists the router redirects `/welcome` and `/onboarding`
/// straight to `/home`, so on any device that has been set up these screens
/// cannot be opened again without deleting the wallet. That is exactly the
/// kind of screen that rots: nobody looks at it after the first launch.
///
/// These tests pump them for real — real theme, real assets, real layout — so
/// an overflow, a missing asset or a reintroduced claim fails in CI instead of
/// waiting for a fresh install to notice.
Widget _host(Widget child) => MaterialApp(
      theme: ShadowTheme.build(),
      home: child,
    );

void main() {
  group('welcome screen', () {
    testWidgets('renders the brand mark rather than a placeholder letter',
        (tester) async {
      await tester.pumpWidget(_host(const WelcomeScreen()));
      await tester.pump();

      // It used to be a white disc with a Text('S') in it. The real mark has
      // shipped in the bundle the whole time.
      final marks = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => i.image)
          .whereType<AssetImage>()
          .map((a) => a.assetName)
          .toList();
      expect(marks, contains('assets/brand/shadow-mark.png'));
      expect(find.text('S'), findsNothing);
    });

    testWidgets('lays out without overflowing a small phone', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(const WelcomeScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('onboarding slides', () {
    /// Claims that were on these screens and are not true of this app. They
    /// are asserted individually so a failure names the one that came back.
    const withdrawn = <String>[
      'Sign-In-With-Solana',
      'no passwords, no servers, no breach',
      'deterministic on-chain token',
      'indexes every Shadow site',
      'Divine Power',
      'Search across the pantheon',
    ];

    testWidgets('the first slide makes no withdrawn claim', (tester) async {
      await tester.pumpWidget(_host(const OnboardingScreen()));
      await tester.pump();

      for (final claim in withdrawn) {
        expect(
          find.textContaining(claim, findRichText: true),
          findsNothing,
          reason: '"$claim" describes a capability Shadow does not have',
        );
      }
    });

    testWidgets('leads with the phrase everything is derived from',
        (tester) async {
      await tester.pumpWidget(_host(const OnboardingScreen()));
      await tester.pump();

      expect(find.text('One phrase'), findsOneWidget);
      expect(find.text('ZEUS'), findsOneWidget);
    });

    testWidgets('slides fit a small phone', (tester) async {
      // Same failure mode the welcome screen had: a Column of illustration
      // plus four blocks of text, on a 360x640 handset.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(const OnboardingScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);

      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byType(PageView), const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'slide $i overflowed');
      }
    });

    testWidgets('every slide builds without an exception', (tester) async {
      await tester.pumpWidget(_host(const OnboardingScreen()));
      await tester.pump();

      // Four slides, walked with the same gesture a user would make.
      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byType(PageView), const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      // The last one is the tracker claim, which is the one measured on a
      // device rather than argued from the code.
      expect(find.text('ARES'), findsOneWidget);
      expect(find.text('Nothing follows you out'), findsOneWidget);
    });
  });
}
