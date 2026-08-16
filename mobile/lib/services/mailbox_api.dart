import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../identity/identity.dart';
import 'fetch_outcome.dart';

/// One sealed message, still sealed.
class SealedMessage {
  const SealedMessage({required this.seq, required this.envelope});

  final int seq;
  final Uint8List envelope;
}

class MailboxPage {
  const MailboxPage({required this.messages, required this.cursor});

  final List<SealedMessage> messages;
  final int cursor;

  bool get isEmpty => messages.isEmpty;
}

/// Talks to the mail Worker.
///
/// ## Why this does not use ApiClient
///
/// `ApiClient` installs an interceptor that attaches `X-Shadow-Auth` to
/// *every* request it makes. Routing a mailbox poll through it would stamp
/// one account identifier onto forty different mailboxes, which is precisely
/// and completely the linkage the whole design exists to prevent — and it
/// would happen silently, as a side effect of reusing the obvious class.
///
/// So: a separate Dio instance with no interceptors, and no shared token of
/// any kind. Authentication is per mailbox, per request, signed by that
/// mailbox's own key. Nothing in this protocol spans two mailboxes.
///
/// What that does *not* fix: the operator still sees which mailbox was
/// polled, from which IP, at what moment. Removing that needs OHTTP with a
/// genuinely independent relay operator — one we ran ourselves would be
/// theatre — and it is not solvable on this side of the wire. Say so rather
/// than implying the signature scheme handled it.
class MailboxApi {
  MailboxApi({required String baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: <String, String>{'Content-Type': 'application/json'},
                // Non-2xx is data here, not an exception: the endpoints
                // answer 401/404/409 meaningfully and each maps to a
                // different thing to tell the user.
                validateStatus: (_) => true,
              ),
            );

  final Dio _dio;

  static int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  static String _b64(List<int> bytes) => base64Encode(bytes);

  /// Claims the address.
  ///
  /// Returns the server's receipt. The caller must check the sealing key in
  /// it against the one it derived *before* filling the address into any
  /// form — a substituted registration would otherwise eat the user's mail
  /// forever, and the account would be unrecoverable with no error anywhere.
  Future<FetchOutcome<MailboxReceipt>> register({
    required SiteMailboxKeys keys,
    required String powNonce,
  }) async {
    final timestamp = _now();
    final localPart = keys.localPart;
    final x25519 = await keys.x25519PublicKey();
    final signature = keys.sign(
      utf8.encode(
        'mail-register/v1|$localPart|${_b64(x25519)}|$timestamp',
      ),
    );

    return _post<MailboxReceipt>(
      '/mail/register',
      <String, dynamic>{
        'local_part': localPart,
        'ed25519_pub': _b64(keys.ed25519PublicKey),
        'x25519_pub': _b64(x25519),
        'pow': powNonce,
        'timestamp': timestamp,
        'signature': _b64(signature),
      },
      (json) => MailboxReceipt(
        localPart: json['local_part'] as String? ?? localPart,
        x25519PublicKey:
            base64Decode(json['x25519_pub'] as String? ?? ''),
      ),
    );
  }

  /// Fetches everything newer than [cursor].
  ///
  /// Cursor-based rather than time-based on purpose: the server returns what
  /// is new and never learns what was read.
  Future<FetchOutcome<MailboxPage>> poll({
    required SiteMailboxKeys keys,
    int cursor = 0,
  }) async {
    final timestamp = _now();
    final localPart = keys.localPart;
    final signature = keys.sign(
      utf8.encode('mail-poll/v1|$localPart|$cursor|$timestamp'),
    );

    return _post<MailboxPage>(
      '/mail/poll',
      <String, dynamic>{
        'local_part': localPart,
        'cursor': cursor,
        'timestamp': timestamp,
        'signature': _b64(signature),
      },
      (json) {
        final raw = json['messages'];
        final messages = <SealedMessage>[];
        if (raw is List) {
          for (final entry in raw) {
            if (entry is! Map) continue;
            final seq = entry['seq'];
            final sealed = entry['sealed'];
            if (seq is! int || sealed is! String) continue;
            try {
              messages.add(
                SealedMessage(seq: seq, envelope: base64Decode(sealed)),
              );
            } on FormatException {
              // One unreadable entry must not cost the rest of the page.
              continue;
            }
          }
        }
        return MailboxPage(
          messages: messages,
          cursor: json['cursor'] as int? ?? cursor,
        );
      },
    );
  }

  /// Burns the address server-side.
  Future<FetchOutcome<void>> retire({required SiteMailboxKeys keys}) async {
    final timestamp = _now();
    final localPart = keys.localPart;
    final signature = keys.sign(
      utf8.encode('mail-retire/v1|$localPart|$timestamp'),
    );

    return _post<void>(
      '/mail/retire',
      <String, dynamic>{
        'local_part': localPart,
        'timestamp': timestamp,
        'signature': _b64(signature),
      },
      (_) {},
    );
  }

  /// Asks whether an address exists, for a client rebuilding lost state.
  ///
  /// Signed like everything else, so it proves nothing to anyone who does
  /// not already hold the key — and therefore reveals nothing the asker
  /// could not already have computed.
  Future<FetchOutcome<bool>> probe({required SiteMailboxKeys keys}) async {
    final timestamp = _now();
    final localPart = keys.localPart;
    final signature = keys.sign(
      utf8.encode('mail-probe/v1|$localPart|$timestamp'),
    );

    return _post<bool>(
      '/mail/probe',
      <String, dynamic>{
        'local_part': localPart,
        'timestamp': timestamp,
        'signature': _b64(signature),
      },
      (json) => json['exists'] as bool? ?? false,
    );
  }

  Future<FetchOutcome<T>> _post<T>(
    String path,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic> json) parse,
  ) async {
    try {
      final response = await _dio.post<dynamic>(path, data: body);
      return outcomeFromMailboxResponse<T>(
        statusCode: response.statusCode,
        data: response.data,
        parse: parse,
      );
    } on DioException catch (error) {
      return FetchUnreachable<T>(describeDioFailure(error));
    } catch (_) {
      // Anything else — a malformed URL, a bad base address typed into
      // settings — is still "we could not ask", which is the one thing the
      // caller must never render as "no code arrived".
      return const FetchUnreachable('Could not reach the mail server.');
    }
  }
}

/// What the server hands back when an address is claimed.
class MailboxReceipt {
  const MailboxReceipt({
    required this.localPart,
    required this.x25519PublicKey,
  });

  final String localPart;
  final Uint8List x25519PublicKey;

  /// True when the server is sealing to the key we actually hold.
  ///
  /// Checked before the address is filled into a form. If this is false, a
  /// different key is registered against this address and mail sent to it is
  /// being sealed to somebody else.
  bool matches(Uint8List expected) {
    if (x25519PublicKey.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= x25519PublicKey[i] ^ expected[i];
    }
    return difference == 0;
  }
}

/// Maps a mailbox response onto the outcome type the app already uses.
///
/// The three cases mean genuinely different things here, and conflating them
/// is the exact failure `FetchOutcome` was introduced to stop:
///
/// - success with an empty page — the mailbox exists, nothing new. *No code
///   yet.*
/// - not found — no such mailbox. Registration never landed, or it was
///   retired. **Not** "no mail": the user needs to be offered a retry.
/// - unreachable — we could not ask. Telling someone their code has not
///   arrived when the truth is the phone is offline is a lie that costs them
///   an account.
FetchOutcome<T> outcomeFromMailboxResponse<T>({
  required int? statusCode,
  required Object? data,
  required T Function(Map<String, dynamic> json) parse,
}) {
  if (statusCode == null) {
    return const FetchUnreachable('The mail server did not respond.');
  }
  if (statusCode == 404) return FetchNotFound<T>();
  if (statusCode == 401) {
    return FetchUnreachable<T>(
      'The mail server rejected this device\'s signature.',
    );
  }
  if (statusCode == 409) {
    return FetchUnreachable<T>(
      'A different key is already registered for this address.',
    );
  }
  if (statusCode == 402) {
    return FetchUnreachable<T>('The mail server asked for more work.');
  }
  if (statusCode < 200 || statusCode >= 300) {
    return FetchUnreachable<T>('The mail server returned $statusCode.');
  }
  if (data is! Map) {
    return const FetchUnreachable('The mail server sent something unreadable.');
  }
  final json = Map<String, dynamic>.from(data);
  if (json['ok'] != true) {
    return const FetchUnreachable('The mail server refused the request.');
  }
  return FetchSuccess<T>(parse(json));
}
