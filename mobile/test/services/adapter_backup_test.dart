import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/models/site_adapter_record.dart';
import 'package:shadow_mobile/services/adapter_backup.dart';

Uint8List keyOf(int fill) => Uint8List(32)..fillRange(0, 32, fill);

SiteAdapterRecord recordFor(
  String domain, {
  int passwordEpoch = 1,
  int aliasEpoch = 1,
  SiteMode mode = SiteMode.masked,
  String? handle,
}) {
  return SiteAdapterRecord(
    domain: domain,
    account: SiteAccountState(
      mode: mode,
      passwordEpoch: passwordEpoch,
      aliasEpoch: aliasEpoch,
      registeredHandle: handle,
    ),
  );
}

void main() {
  group('round trip', () {
    test('everything the server cannot recover survives', () async {
      // The password epoch is the point. No probe can find it, because the
      // mail server has never seen anything derived from it.
      final records = <SiteAdapterRecord>[
        recordFor('twitter.com',
            passwordEpoch: 3, aliasEpoch: 2, handle: 'quietharbor4821'),
        recordFor('reddit.com', mode: SiteMode.public),
      ];

      final blob = await AdapterBackup.export(
        records: records,
        backupKey: keyOf(7),
      );
      final restored = await AdapterBackup.import(
        contents: blob,
        backupKey: keyOf(7),
      );

      expect(restored, hasLength(2));
      final twitter = restored.firstWhere((r) => r.domain == 'twitter.com');
      expect(twitter.account.passwordEpoch, 3);
      expect(twitter.account.aliasEpoch, 2);
      expect(twitter.account.registeredHandle, 'quietharbor4821');
      expect(
        restored.firstWhere((r) => r.domain == 'reddit.com').account.mode,
        SiteMode.public,
      );
    });

    test('an empty store exports and imports as empty', () async {
      final blob = await AdapterBackup.export(
        records: <SiteAdapterRecord>[],
        backupKey: keyOf(7),
      );
      expect(
        await AdapterBackup.import(contents: blob, backupKey: keyOf(7)),
        isEmpty,
      );
    });

    test('the site list is not readable without the key', () async {
      // The list of sites someone has accounts on is the index to their
      // whole life online, and arguably more sensitive than any one
      // credential in it.
      final blob = await AdapterBackup.export(
        records: <SiteAdapterRecord>[recordFor('twitter.com')],
        backupKey: keyOf(7),
      );

      expect(blob, isNot(contains('twitter')));
    });
  });

  group('failures say which thing is wrong', () {
    Future<BackupProblem> problemFor(String contents, [int key = 7]) async {
      try {
        await AdapterBackup.import(contents: contents, backupKey: keyOf(key));
        fail('expected a BackupFailure');
      } on BackupFailure catch (e) {
        return e.problem;
      }
    }

    test('a different identity is named as such', () async {
      // The common case, and the one where a vague message sends someone
      // re-typing a phrase that was never going to work.
      final blob = await AdapterBackup.export(
        records: <SiteAdapterRecord>[recordFor('twitter.com')],
        backupKey: keyOf(7),
      );

      expect(await problemFor(blob, 9), BackupProblem.wrongIdentity);
    });

    test('a file that is not a backup', () async {
      for (final junk in <String>[
        'not json at all',
        '[]',
        '{"hello":"world"}',
        '',
      ]) {
        expect(await problemFor(junk), BackupProblem.notABackup, reason: junk);
      }
    });

    test('a backup from a newer Shadow', () async {
      final future = jsonEncode(<String, Object?>{
        'magic': 'shadow.adapters',
        'version': 99,
        'nonce': base64Encode(List<int>.filled(12, 0)),
        'payload': base64Encode(List<int>.filled(32, 0)),
      });

      expect(await problemFor(future), BackupProblem.tooNew);
    });

    test('a tampered payload is refused, not half-read', () async {
      final blob = await AdapterBackup.export(
        records: <SiteAdapterRecord>[recordFor('twitter.com')],
        backupKey: keyOf(7),
      );
      final envelope = jsonDecode(blob) as Map<String, dynamic>;
      final payload = base64Decode(envelope['payload'] as String);
      payload[0] ^= 0xFF;
      envelope['payload'] = base64Encode(payload);

      expect(
        await problemFor(jsonEncode(envelope)),
        BackupProblem.wrongIdentity,
      );
    });

    test('relabelling the version is caught by the header binding', () async {
      final blob = await AdapterBackup.export(
        records: <SiteAdapterRecord>[recordFor('twitter.com')],
        backupKey: keyOf(7),
      );
      final envelope = jsonDecode(blob) as Map<String, dynamic>;
      envelope['version'] = 0;

      expect(
        await problemFor(jsonEncode(envelope)),
        BackupProblem.wrongIdentity,
      );
    });
  });

  group('merging never walks a device backwards', () {
    test('the higher epoch wins on each side independently', () async {
      // A backup restored onto a device that has since rotated must not undo
      // that: a lower alias epoch derives an address the site no longer has,
      // and a lower password epoch derives one it will not accept.
      final merged = AdapterBackup.merge(
        current: <SiteAdapterRecord>[
          recordFor('twitter.com', passwordEpoch: 4, aliasEpoch: 1),
        ],
        imported: <SiteAdapterRecord>[
          recordFor('twitter.com', passwordEpoch: 2, aliasEpoch: 3),
        ],
      );

      expect(merged, hasLength(1));
      expect(merged.first.account.passwordEpoch, 4);
      expect(merged.first.account.aliasEpoch, 3);
    });

    test('sites only in the backup are added', () async {
      final merged = AdapterBackup.merge(
        current: <SiteAdapterRecord>[recordFor('twitter.com')],
        imported: <SiteAdapterRecord>[recordFor('reddit.com')],
      );

      expect(merged.map((r) => r.domain).toSet(),
          <String>{'twitter.com', 'reddit.com'});
    });

    test('a handle recorded on either side survives', () async {
      final merged = AdapterBackup.merge(
        current: <SiteAdapterRecord>[recordFor('twitter.com')],
        imported: <SiteAdapterRecord>[
          recordFor('twitter.com', handle: 'quietharbor4821'),
        ],
      );

      expect(merged.first.account.registeredHandle, 'quietharbor4821');
    });

    test('two accounts on one site stay separate', () async {
      final merged = AdapterBackup.merge(
        current: <SiteAdapterRecord>[
          const SiteAdapterRecord(domain: 'twitter.com'),
        ],
        imported: <SiteAdapterRecord>[
          const SiteAdapterRecord(domain: 'twitter.com', accountIndex: 1),
        ],
      );

      expect(merged, hasLength(2));
    });
  });
}
