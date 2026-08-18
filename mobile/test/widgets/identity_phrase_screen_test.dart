import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/widgets/ambient_light.dart';

import 'package:shadow_mobile/screens/identity/identity_phrase_screen.dart';

const String phrase =
    'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  // The drifting background never settles, so pumpAndSettle would wait on it
  // rather than on anything this file is about.
  setUpAll(() => AmbientLight.motion = false);

  testWidgets('keeps the words covered until the user asks', (tester) async {
    await tester.pumpWidget(_wrap(const IdentityPhraseScreen(phrase: phrase)));

    expect(find.text('Reveal phrase'), findsOneWidget);
    expect(find.text('about'), findsNothing);

    await tester.tap(find.text('Reveal phrase'));
    await tester.pumpAndSettle();

    expect(find.text('about'), findsOneWidget);
    expect(find.text('abandon'), findsNWidgets(11));
  });

  testWidgets('will not let the user leave without acknowledging',
      (tester) async {
    await tester.pumpWidget(_wrap(const IdentityPhraseScreen(phrase: phrase)));

    final continueButton = find.widgetWithText(InkWell, 'Continue');
    expect(continueButton, findsOneWidget);

    // The checkbox is disabled until the phrase has actually been shown, so
    // there is no path to Continue that skips seeing the words.
    final checkbox = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    expect(checkbox.onChanged, isNull);
  });

  testWidgets('names what is not in the phrase but is needed to restore it',
      (tester) async {
    // The alias domain lives in the keystore, not in the words. Without it a
    // restored identity mints addresses at the wrong domain and the mail goes
    // nowhere — so "twelve words restore everything" is only true if this
    // card is on screen.
    await tester.pumpWidget(_wrap(const IdentityPhraseScreen(
      phrase: phrase,
      alsoRecord: 'mail.example.com',
    )));

    expect(find.text('Write this down too'), findsOneWidget);
    expect(find.text('mail.example.com'), findsOneWidget);
    expect(
      find.textContaining('not part of the phrase'),
      findsOneWidget,
    );
  });

  testWidgets('omits the extra card when there is nothing else to record',
      (tester) async {
    await tester.pumpWidget(_wrap(const IdentityPhraseScreen(phrase: phrase)));
    expect(find.text('Write this down too'), findsNothing);
  });

  testWidgets('says which secret these words are', (tester) async {
    await tester.pumpWidget(_wrap(const IdentityPhraseScreen(
      phrase: phrase,
      subtitle: 'Twelve words that restore this wallet and its funds',
    )));

    expect(
      find.text('Twelve words that restore this wallet and its funds'),
      findsOneWidget,
    );
  });
}
