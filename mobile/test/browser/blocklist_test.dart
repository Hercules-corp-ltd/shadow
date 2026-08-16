import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Validates the shipped rule list against WebKit's constraints.
///
/// This matters more than it looks. WKContentRuleList compiles atomically: one
/// malformed rule and WebKit rejects the whole list, so the app ships a
/// settings screen reading "blocking on" while nothing whatsoever is blocked.
/// The failure is silent on device and invisible in review, which makes it
/// exactly the kind of thing a test has to catch.
void main() {
  final rulesFile = File('assets/blocklist/trackers.json');
  final metaFile = File('assets/blocklist/trackers.meta.json');

  late List<dynamic> rules;
  late Map<String, dynamic> meta;

  setUpAll(() {
    rules = jsonDecode(rulesFile.readAsStringSync()) as List<dynamic>;
    meta = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
  });

  test('ships a non-empty list well under WebKit ceiling', () {
    expect(rules, isNotEmpty);
    // WebKit caps a compiled list at 150,000 rules. The curated list is
    // orders of magnitude below that; if it ever approaches, compile time on
    // older devices needs measuring before shipping.
    expect(rules.length, lessThan(150000));
    expect(meta['ruleCount'], rules.length);
  });

  test('every rule has the shape WebKit requires', () {
    for (final rule in rules) {
      expect(rule, isA<Map<String, dynamic>>());
      final map = rule as Map<String, dynamic>;

      expect(map.keys, containsAll(<String>['trigger', 'action']));
      final trigger = map['trigger'] as Map<String, dynamic>;
      final action = map['action'] as Map<String, dynamic>;

      expect(trigger['url-filter'], isA<String>());
      expect((trigger['url-filter'] as String), isNotEmpty);
      expect(action['type'], 'block');

      // Both conditions in one trigger is JSONMultipleConditions, which fails
      // the whole compile rather than skipping the rule.
      final hasIf = trigger.containsKey('if-domain');
      final hasUnless = trigger.containsKey('unless-domain');
      expect(hasIf && hasUnless, isFalse,
          reason: 'trigger may not carry both if-domain and unless-domain');
    }
  });

  test('every url-filter is a regex WebKit can compile', () {
    for (final rule in rules) {
      final filter =
          (rule as Map<String, dynamic>)['trigger']['url-filter'] as String;
      // Dart's engine is not WebKit's, but a pattern that will not parse here
      // is certainly wrong there too.
      expect(() => RegExp(filter), returnsNormally,
          reason: 'unparseable url-filter: $filter');
    }
  });

  test('domains are lowercase ASCII', () {
    // A single non-ASCII or uppercase domain triggers
    // JSONDomainNotLowerCaseASCII and takes the entire list down with it.
    for (final rule in rules) {
      final filter =
          (rule as Map<String, dynamic>)['trigger']['url-filter'] as String;
      expect(filter, equals(filter.toLowerCase()),
          reason: 'url-filter must be lowercase: $filter');
      expect(filter.codeUnits.every((c) => c < 128), isTrue,
          reason: 'url-filter must be ASCII (punycode first): $filter');
    }
  });

  test('blocks third-party loads only', () {
    // A first-party request to one of these hosts means the user navigated
    // there deliberately; blocking it breaks the site they asked for.
    for (final rule in rules) {
      final trigger =
          (rule as Map<String, dynamic>)['trigger'] as Map<String, dynamic>;
      expect(trigger['load-type'], <String>['third-party']);
    }
  });

  test('does not block the domains that would visibly break the web', () {
    // Several of these outrank everything in the list by prevalence, and
    // every one is load-bearing for ordinary pages. If one appears here,
    // somebody has widened the list without reading why they were excluded.
    const neverBlock = <String>[
      'googletagmanager',
      'gstatic',
      'fonts\\.googleapis',
      'ajax\\.googleapis',
      'cloudflare',
      'jsdelivr',
      'unpkg',
      'bootstrapcdn',
    ];
    final joined = rules
        .map((r) => (r as Map<String, dynamic>)['trigger']['url-filter'])
        .join(' ');
    for (final domain in neverBlock) {
      expect(joined, isNot(contains(domain)),
          reason: '$domain breaks ordinary sites and must stay unblocked');
    }
  });

  test('metadata records provenance and licence', () {
    // EasyPrivacy is CC BY-SA: attribution is an obligation, not a courtesy,
    // and the ShareAlike term attaches to this derived file.
    expect(meta['source'], 'EasyPrivacy');
    expect(meta['licence'], 'CC BY-SA 3.0');
    expect(meta['attribution'], isNotEmpty);
    expect(meta['contentHash'], isA<String>());
    expect((meta['contentHash'] as String).length, greaterThan(8));
  });

  test('rules are unique', () {
    final filters = rules
        .map((r) => (r as Map<String, dynamic>)['trigger']['url-filter'])
        .toList();
    expect(filters.toSet().length, filters.length,
        reason: 'duplicate rules waste compile budget for no benefit');
  });
}
