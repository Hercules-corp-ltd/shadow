import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/models/deploy_project.dart';
import 'package:shadow_mobile/screens/wallet/wallet_import_screen.dart';
import 'package:shadow_mobile/theme/shadow_theme.dart';

void main() {
  group('recovery phrase fields', () {
    testWidgets('never hand a seed word to the keyboard to remember',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ShadowTheme.build(),
        home: const WalletImportScreen(),
      ));
      await tester.pump();

      // Every word field, not just the first: the phrase is only as private
      // as its least careful slot.
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, isNotEmpty);

      var checked = 0;
      for (final f in fields) {
        // Left at their defaults these are all true, which puts each word of
        // a BIP-39 seed into the system keyboard's personal dictionary — a
        // store that syncs to the vendor's cloud on both platforms. The
        // phrase reconstructs the wallet, so that is the whole secret.
        expect(f.autocorrect, isFalse, reason: 'autocorrect must be off');
        expect(f.enableSuggestions, isFalse,
            reason: 'predictive suggestions must be off');
        expect(f.enableIMEPersonalizedLearning, isFalse,
            reason: 'the IME must not learn from a seed phrase');
        expect(f.autofillHints, isEmpty,
            reason: 'a seed word is not an autofill value');
        checked++;
      }
      expect(checked, greaterThanOrEqualTo(12));
    });
  });

  group('a deployment with no domain', () {
    test('clearing the domain field actually clears it', () {
      final named = DeployProject(
        id: 'p1',
        name: 'site',
        framework: ProjectFramework.static_,
        createdAt: DateTime.utc(2026),
        domain: 'mine.shadow',
      );

      // The plain copyWith idiom cannot express "no domain": null means
      // "leave unchanged". A user who typed a name, went forward, came back
      // and emptied the field used to deploy under the name they removed.
      expect(named.copyWith(domain: null).domain, 'mine.shadow');
      expect(named.copyWith(clearDomain: true).domain, isNull);

      // And clearing must not disturb anything else on the way past.
      final cleared = named.copyWith(clearDomain: true, name: 'renamed');
      expect(cleared.name, 'renamed');
      expect(cleared.id, 'p1');
      expect(cleared.framework, ProjectFramework.static_);
    });
  });
}
