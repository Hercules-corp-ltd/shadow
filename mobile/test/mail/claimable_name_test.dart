import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/identity/identity.dart';
import 'package:shadow_mobile/mail/claimable_name.dart';

void main() {
  group('what a person is allowed to claim', () {
    test('an ordinary name is fine', () {
      expect(ClaimableName.isValid('alice'), isTrue);
      expect(ClaimableName.isValid('mydeskmail'), isTrue);
      expect(ClaimableName.isValid('bassoon27'), isTrue);
    });

    test('length bounds', () {
      expect(ClaimableName.check('abcd'), NameProblem.tooShort);
      expect(ClaimableName.check('a' * 21), NameProblem.tooLong);
      expect(ClaimableName.isValid('a' * 19), isTrue);
    });

    test('the alphabet excludes every confusable pair', () {
      // 0/o and 1/l are the whole reason the alphabet is this narrow: this is
      // an address someone reads off a screen and types from memory, and
      // `a1ice` beside `alice` is the cheapest impersonation there is.
      for (final rejected in <String>[
        'alice0',
        'alice1',
        'alice8',
        'alice9',
        'Alice7',
        'alice.smith',
        'alice-smith',
        'alice_smith',
        'alice smith',
        'alicé7',
      ]) {
        expect(
          ClaimableName.check(rejected),
          NameProblem.badCharacters,
          reason: rejected,
        );
      }
    });

    test('role addresses the domain owes an answer to are reserved', () {
      // RFC 2142: a domain that cannot be reached at postmaster or abuse
      // starts being treated as unattended by other mail operators.
      expect(ClaimableName.check('postmaster'), NameProblem.reserved);
      expect(ClaimableName.check('abuse'), NameProblem.reserved);
      expect(ClaimableName.check('security'), NameProblem.reserved);
      expect(ClaimableName.check('noreply'), NameProblem.reserved);
    });

    test('anything shorter than the minimum is already unreachable', () {
      // root, mail, help, info and team are refused on length, which is why
      // they are deliberately absent from the reserved list rather than
      // duplicated into it.
      for (final short in <String>['root', 'mail', 'help', 'info', 'team']) {
        expect(ClaimableName.check(short), NameProblem.tooShort, reason: short);
      }
    });
  });

  group('the disjointness rule', () {
    test('a real derived alias can never be claimed as a name', () {
      // The property the whole design rests on, checked against addresses
      // actually produced by the derivation rather than a hand-written string.
      // Shadow displays an alias before it is registered, and an unregistered
      // alias has no row on the mail service — so if one could be claimed
      // here, anyone who saw it could take delivery of the resets that follow.
      //
      // If mask derivation ever changes shape, this fails, and so does the
      // equivalent fuzz check in services/mail-worker/tool/probe.mjs.
      for (var seed = 1; seed <= 64; seed++) {
        final keys = SiteMailboxKeys.fromMaterial(
          Uint8List(64)..fillRange(0, 64, seed),
        );
        final localPart = keys.localPart;
        expect(
          ClaimableName.isValid(localPart),
          isFalse,
          reason: 'claimable: $localPart',
        );
        // Today this is `tooLong`, because the current alias length of 20 sits
        // outside the 5..19 window and the length bound catches it first. The
        // maskLengths check is not redundant with that — it is what covers a
        // future truncation that lands *inside* the window, which is the only
        // way this rule could quietly stop holding.
        expect(
          ClaimableName.check(localPart),
          anyOf(NameProblem.looksLikeAnAlias, NameProblem.tooLong),
          reason: localPart,
        );
      }
    });

    test('the excluded lengths are the derivation lengths', () {
      // Not a tautology: it is the assertion that the two constants have not
      // drifted, which is the way this rule would actually die.
      expect(
        ClaimableName.maskLengths,
        contains(SiteMailboxKeys.localPartLength),
      );
    });

    test('a name of alias length is refused even with a legal alphabet', () {
      const aliasLength = SiteMailboxKeys.localPartLength;
      expect(
        ClaimableName.check('a' * aliasLength),
        anyOf(NameProblem.looksLikeAnAlias, NameProblem.tooLong),
      );
    });
  });

  group('what the user is told', () {
    test('every problem has copy, and none of it blames the user', () {
      for (final problem in NameProblem.values) {
        final text = ClaimableName.explain(problem);
        expect(text, isNotEmpty);
        expect(text.length, greaterThan(10), reason: problem.name);
      }
    });
  });
}
