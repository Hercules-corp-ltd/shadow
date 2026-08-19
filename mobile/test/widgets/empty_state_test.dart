import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadow_mobile/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState shows icon, title, message, and fires action',
      (tester) async {
    var pressed = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EmptyState(
          icon: Icons.bookmark_border_rounded,
          title: 'No bookmarks yet',
          message: 'Save sites to get back to them fast.',
          actionLabel: 'Browse',
          onAction: () => pressed++,
        ),
      ),
    ));

    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(find.text('No bookmarks yet'), findsOneWidget);
    expect(find.text('Save sites to get back to them fast.'), findsOneWidget);

    await tester.tap(find.text('Browse'));
    await tester.pump();

    expect(pressed, equals(1));
  });
}
