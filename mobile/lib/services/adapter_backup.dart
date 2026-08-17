import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/site_adapter_record.dart';

/// Why a backup could not be read.
enum BackupProblem {
  /// Not a Shadow backup, or not a file at all.
  notABackup,

  /// Written by a newer Shadow than this one.
  tooNew,

  /// The right shape, but this identity's key does not open it.
  ///
  /// Almost always the wrong phrase, or the right phrase with a different
  /// passphrase — which produces a different identity entirely.
  wrongIdentity,
}

class BackupFailure implements Exception {
  const BackupFailure(this.problem, this.message);
  final BackupProblem problem;
  final String message;

  @override
  String toString() => message;
}

/// Moves the per-site adapter records between devices.
///
/// ## Why this exists even though the phrase restores everything else
///
/// It does not restore everything else. The phrase regenerates credentials,
/// but not the *state* that says which ones are current: after a site forces
/// a password reset the user is on password epoch 2, and nothing outside
/// this device has ever seen anything derived from that number. The mail
/// server can be asked which alias epoch a site is on, because it holds the
/// mailbox — see `MailboxProvider.recoverAliasEpoch`. It cannot be asked
/// about the password, and it never should be.
///
/// So: the phrase gets you back to a working identity, the probe gets your
/// addresses back, and this gets back the rest.
///
/// ## What is in it
///
/// A list of the sites the user has accounts on. That is a sensitive
/// document — arguably more so than any single credential, because it is the
/// index — which is why it is encrypted to a key derived from the phrase
/// rather than to a password the user picks. A second password would be a
/// second thing to lose, and losing it would lose exactly the thing this is
/// for.
class AdapterBackup {
  AdapterBackup._();

  /// Bump only for a change old clients cannot read.
  static const int formatVersion = 1;
  static const String _magic = 'shadow.adapters';
  static const int _nonceBytes = 12;

  /// Encrypts [records] under [backupKey].
  static Future<String> export({
    required List<SiteAdapterRecord> records,
    required Uint8List backupKey,
  }) async {
    final plaintext = utf8.encode(
      jsonEncode(<String, Object?>{
        'records': records.map((r) => r.toJson()).toList(growable: false),
      }),
    );

    final box = await AesGcm.with256bits().encrypt(
      plaintext,
      secretKey: SecretKey(backupKey),
      // Authenticate the header, so a backup cannot be relabelled with a
      // different version and fed to a client that reads it differently.
      aad: utf8.encode('$_magic/$formatVersion'),
    );

    return jsonEncode(<String, Object?>{
      'magic': _magic,
      'version': formatVersion,
      'nonce': base64Encode(box.nonce),
      'payload': base64Encode(box.cipherText + box.mac.bytes),
    });
  }

  /// Decrypts a backup, or throws [BackupFailure] saying which thing is wrong.
  ///
  /// The three failures need different words in front of a user: a file that
  /// is not a backup, a backup from a newer Shadow, and a backup that is
  /// simply not theirs. Collapsing them into "could not import" leaves
  /// someone re-typing a correct phrase at a file that was never going to
  /// open.
  static Future<List<SiteAdapterRecord>> import({
    required String contents,
    required Uint8List backupKey,
  }) async {
    Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(contents);
      if (decoded is! Map) throw const FormatException('not an object');
      envelope = Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw const BackupFailure(
        BackupProblem.notABackup,
        'That file is not a Shadow backup.',
      );
    }

    if (envelope['magic'] != _magic) {
      throw const BackupFailure(
        BackupProblem.notABackup,
        'That file is not a Shadow backup.',
      );
    }

    final version = envelope['version'];
    if (version is! int || version > formatVersion) {
      throw const BackupFailure(
        BackupProblem.tooNew,
        'That backup was written by a newer version of Shadow.',
      );
    }

    final Uint8List nonce;
    final Uint8List payload;
    try {
      nonce = base64Decode(envelope['nonce'] as String? ?? '');
      payload = base64Decode(envelope['payload'] as String? ?? '');
    } on FormatException {
      throw const BackupFailure(
        BackupProblem.notABackup,
        'That backup is damaged.',
      );
    }
    if (nonce.length != _nonceBytes || payload.length <= 16) {
      throw const BackupFailure(
        BackupProblem.notABackup,
        'That backup is damaged.',
      );
    }

    List<int> plaintext;
    try {
      plaintext = await AesGcm.with256bits().decrypt(
        SecretBox(
          payload.sublist(0, payload.length - 16),
          nonce: nonce,
          mac: Mac(payload.sublist(payload.length - 16)),
        ),
        secretKey: SecretKey(backupKey),
        aad: utf8.encode('$_magic/$version'),
      );
    } on SecretBoxAuthenticationError {
      throw const BackupFailure(
        BackupProblem.wrongIdentity,
        'That backup belongs to a different recovery phrase, or the same '
        'phrase with a different passphrase.',
      );
    }

    final decoded = jsonDecode(utf8.decode(plaintext, allowMalformed: true));
    if (decoded is! Map || decoded['records'] is! List) {
      throw const BackupFailure(
        BackupProblem.notABackup,
        'That backup is damaged.',
      );
    }

    // Tolerant, like the store itself: one unreadable record costs its own
    // fields, never the whole restore. A backup is read exactly when
    // everything else has already gone wrong.
    return <SiteAdapterRecord>[
      for (final entry in decoded['records'] as List)
        if (entry is Map)
          SiteAdapterRecord.fromJson(Map<String, dynamic>.from(entry)),
    ];
  }

  /// Merges an imported list into what is already here.
  ///
  /// Takes the higher epoch on every site, rather than letting either side
  /// win wholesale. A backup restored onto a device that has since moved on
  /// must not walk that device backwards — a lower alias epoch derives an
  /// address the site no longer has, and a lower password epoch derives a
  /// password it will not accept.
  static List<SiteAdapterRecord> merge({
    required List<SiteAdapterRecord> current,
    required List<SiteAdapterRecord> imported,
  }) {
    final byId = <String, SiteAdapterRecord>{
      for (final record in current) record.id: record,
    };

    for (final incoming in imported) {
      final existing = byId[incoming.id];
      if (existing == null) {
        byId[incoming.id] = incoming;
        continue;
      }

      byId[incoming.id] = existing.copyWith(
        account: existing.account.copyWith(
          passwordEpoch: incoming.account.passwordEpoch >
                  existing.account.passwordEpoch
              ? incoming.account.passwordEpoch
              : existing.account.passwordEpoch,
          aliasEpoch: incoming.account.aliasEpoch > existing.account.aliasEpoch
              ? incoming.account.aliasEpoch
              : existing.account.aliasEpoch,
          // Keep whichever side actually recorded one.
          registeredHandle: existing.account.registeredHandle ??
              incoming.account.registeredHandle,
          mode: existing.account.mode == SiteMode.off
              ? incoming.account.mode
              : existing.account.mode,
        ),
      );
    }

    return byId.values.toList(growable: false);
  }
}
