import 'dart:convert';
import 'dart:typed_data';

import 'package:bs58/bs58.dart';
import 'package:solana/solana.dart';

import 'api_client.dart';

/// Sign-In-With-Solana (Ares module) flow.
///
/// 1. `requestChallenge(pubkey)` - ask the backend for a random nonce.
/// 2. Client signs the nonce with the user's ed25519 private key.
/// 3. `verify(pubkey, signature, message)` - backend verifies and returns
///    a session token which is stored by [ApiClient].
class AuthService {
  final ApiClient _api = ApiClient.instance;

  /// Requests a login challenge from the backend.
  Future<String> requestChallenge(String pubkey) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/auth/challenge',
      data: {'pubkey': pubkey},
    );
    return res.data?['message'] as String? ?? '';
  }

  /// Signs a SIWS challenge and exchanges it for a session token.
  Future<String> signInWithSolana({
    required Ed25519HDKeyPair wallet,
  }) async {
    final pubkey = wallet.publicKey.toBase58();
    final message = await requestChallenge(pubkey);

    final signed = await wallet.sign(utf8.encode(message));
    final signature = base58.encode(Uint8List.fromList(signed.bytes));

    final res = await _api.post<Map<String, dynamic>>(
      '/auth/verify',
      data: {
        'pubkey': pubkey,
        'signature': signature,
        'message': message,
      },
    );

    final token = res.data?['token'] as String? ?? '';
    await _api.setAuthToken(token);
    return token;
  }

  Future<void> signOut() async {
    await _api.setAuthToken(null);
  }
}
