import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/screens/browser/browser_screen.dart';

/// Opens the address bar the way the browser does and returns its field.
Future<TextField> openSheet(WidgetTester tester, String initialValue) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showModalBottomSheet<String>(
              context: context,
              isScrollControlled: true,
              builder: (_) => UrlPromptSheet(initialValue: initialValue),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return tester.widget<TextField>(find.byType(TextField));
}

void main() {
  group('the address bar replaces what is there, rather than appending', () {
    testWidgets('the current address arrives fully selected', (tester) async {
      // The bug this exists for made the browser unusable: from bbc.com,
      // typing "wikipedia.org" navigated to bbc.com/wikipedia.org and 404ed,
      // so once a page was open you could not go anywhere else.
      const current = 'https://bbc.co.uk/news';
      final field = await openSheet(tester, current);

      expect(field.controller!.text, current);
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: current.length),
        reason: 'typing must replace the address, not insert into it',
      );
    });

    testWidgets('typing replaces the whole address', (tester) async {
      await openSheet(tester, 'https://bbc.co.uk/news');
      await tester.enterText(find.byType(TextField), 'wikipedia.org');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'wikipedia.org');
      expect(field.controller!.text, isNot(contains('bbc')));
    });

    testWidgets('an empty tab starts empty, with no phantom selection',
        (tester) async {
      final field = await openSheet(tester, '');

      expect(field.controller!.text, isEmpty);
      expect(field.controller!.selection.baseOffset, 0);
      expect(field.controller!.selection.extentOffset, 0);
    });
  });

  group('there is a way out that does not rely on the selection', () {
    testWidgets('a clear button appears only when there is text',
        (tester) async {
      await openSheet(tester, '');
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.enterText(find.byType(TextField), 'bbc.co.uk');
      await tester.pump();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('tapping it empties the field', (tester) async {
      await openSheet(tester, 'https://bbc.co.uk/news');

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });
  });
}
