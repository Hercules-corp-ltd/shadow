import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/types/auth_messages.dart';
import 'package:shadow_mobile/services/quick_unlock.dart';

/// A device whose answer to "is it you" the test dictates.
class FakeAuth extends LocalAuthentication {
  FakeAuth({this.supported = true, this.accepts = true, this.throws});

  final bool supported;
  final bool accepts;
  final Exception? throws;
  int prompts = 0;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    prompts++;
    if (throws != null) throw throws!;
    return accepts;
  }
}

/// Secure storage, in memory.
class FakeStore extends FlutterSecureStorage {
  const FakeStore(this._values);
  final Map<String, String> _values;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}

void main() {
  group('arming the shortcut', () {
    test('a passphrase is stored only after the device says it is you',
        () async {
      final values = <String, String>{};
      final auth = FakeAuth();
      final quick = QuickUnlock(storage: FakeStore(values), auth: auth);

      expect(await quick.enable('correct horse'), isTrue);
      expect(auth.prompts, 1, reason: 'checked before storing, never after');
      expect(values.values, contains('correct horse'));
      expect(await quick.isEnabled(), isTrue);
    });

    test('a refused check stores nothing', () async {
      // The important direction. Storing first and checking later would let
      // anybody holding the unlocked phone arm the shortcut and then use it.
      final values = <String, String>{};
      final quick = QuickUnlock(
        storage: FakeStore(values),
        auth: FakeAuth(accepts: false),
      );

      expect(await quick.enable('correct horse'), isFalse);
      expect(values, isEmpty);
      expect(await quick.isEnabled(), isFalse);
    });
  });

  group('using it', () {
    test('the passphrase comes back after a successful check', () async {
      final quick = QuickUnlock(
        storage: const FakeStore(<String, String>{
          'shadow_identity_quick_passphrase': 'correct horse',
        }),
        auth: FakeAuth(),
      );

      final result = await quick.unlock();
      expect(result.succeeded, isTrue);
      expect(result.passphrase, 'correct horse');
    });

    test('a refused check hands back nothing', () async {
      final quick = QuickUnlock(
        storage: const FakeStore(<String, String>{
          'shadow_identity_quick_passphrase': 'correct horse',
        }),
        auth: FakeAuth(accepts: false),
      );

      final result = await quick.unlock();
      expect(result.succeeded, isFalse);
      expect(result.problem, QuickUnlockProblem.refused);
    });

    test('a lock screen removed after arming is not reported as a refusal',
        () async {
      // Different sentence, different remedy: one says try again, the other
      // says your phone has no lock any more.
      final quick = QuickUnlock(
        storage: const FakeStore(<String, String>{
          'shadow_identity_quick_passphrase': 'correct horse',
        }),
        auth: FakeAuth(supported: false),
      );

      final result = await quick.unlock();
      expect(result.problem, QuickUnlockProblem.unavailable);
    });

    test('nothing stored is its own answer, not a failure', () async {
      final quick = QuickUnlock(
        storage: const FakeStore(<String, String>{}),
        auth: FakeAuth(),
      );

      final result = await quick.unlock();
      expect(result.problem, QuickUnlockProblem.notSet);
    });

    test('turning it off removes the stored passphrase', () async {
      final values = <String, String>{
        'shadow_identity_quick_passphrase': 'correct horse',
      };
      final quick = QuickUnlock(storage: FakeStore(values), auth: FakeAuth());

      await quick.disable();
      expect(values, isEmpty);
      expect(await quick.isEnabled(), isFalse);
    });
  });

  group('when the platform itself fails', () {
    test('the reason is kept rather than swallowed', () async {
      // A setup problem — no enrolled biometric, no fragment activity — needs
      // different words than "that did not check out", and the switch sliding
      // back with nothing said is the same defect as a switch that lies.
      final quick = QuickUnlock(
        storage: const FakeStore(<String, String>{}),
        auth: FakeAuth(
          throws: PlatformExceptionStub('NotAvailable', 'no biometrics'),
        ),
      );

      expect(await quick.enable('correct horse'), isFalse);
      expect(quick.lastError, contains('NotAvailable'));
      expect(quick.lastError, contains('no biometrics'));
    });
  });

  group('what the user is told', () {
    test('every problem has its own sentence', () {
      final seen = <String>{};
      for (final problem in QuickUnlockProblem.values) {
        final text = QuickUnlock.explain(problem);
        expect(text, isNotEmpty);
        expect(seen.add(text), isTrue, reason: 'no two share wording');
      }
    });
  });
}

/// A PlatformException without pulling in the services binding.
class PlatformExceptionStub implements Exception {
  PlatformExceptionStub(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}
