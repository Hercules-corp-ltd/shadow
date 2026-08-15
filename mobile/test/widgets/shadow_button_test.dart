import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_mobile/widgets/shadow_button.dart';

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  // Keep google_fonts offline so widget tests don't hit the network.

  group('ShadowButton', () {
    testWidgets('renders its label', (tester) async {
      await tester.pumpWidget(_harness(
        const ShadowButton(label: 'Deploy'),
      ));
      expect(find.text('Deploy'), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(
        ShadowButton(label: 'Tap me', onPressed: () => taps++),
      ));

      await tester.tap(find.text('Tap me'));
      await tester.pump();

      expect(taps, equals(1));
    });

    testWidgets('does not fire onPressed when isLoading is true',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(
        ShadowButton(
          label: 'Working',
          isLoading: true,
          onPressed: () => taps++,
        ),
      ));

      // Tap the whole button area, not the text (which is hidden in loading).
      await tester.tap(find.byType(ShadowButton));
      await tester.pump();

      expect(taps, equals(0));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders leading and trailing icons', (tester) async {
      await tester.pumpWidget(_harness(
        const ShadowButton(
          label: 'Send',
          leading: Icons.arrow_forward_rounded,
          trailing: Icons.bolt_rounded,
        ),
      ));

      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    });
  });
}
