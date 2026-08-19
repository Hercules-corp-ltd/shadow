import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/identity/identity.dart';
import 'package:shadow_mobile/services/wallet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fixed phrase so expectations are reproducible. Test vector, never a
/// wallet — do not fund it.
const String testPhrase = 'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';

const String password = 'correct horse battery';

void main() {
  late WalletService service;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    service = WalletService();
  });

  group('recovery phrases', () {
    test('a generated phrase is a valid BIP-39 mnemonic', () {
      final phrase = service.createMnemonic();
      expect(phrase.split(' ').length, 12);
      expect(ShadowIdentity.isValidMnemonic(phrase), isTrue);
    });

    test('generated phrases differ', () {
      expect(service.createMnemonic(), isNot(service.createMnemonic()));
    });

    test('a phrase always derives the same wallet', () async {
      final a = await service.walletFromMnemonic(testPhrase);
      final b = await service.walletFromMnemonic(testPhrase);
      expect(a.address, b.address);
    });

    test('a created wallet can actually be restored from its words', () async {
      // The property the delete screen has always claimed and could not
      // deliver: derive, store, wipe the device, restore from words alone,
      // and arrive at the same address.
      final phrase = service.createMnemonic();
      final created = await service.walletFromMnemonic(phrase);
      await service.storeWallet(created, password, mnemonic: phrase);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final restored = await service.walletFromMnemonic(phrase);

      expect(restored.address, created.address);
    });
  });

  group('phrase storage', () {
    test('round-trips under the wallet password', () async {
      final keypair = await service.walletFromMnemonic(testPhrase);
      await service.storeWallet(keypair, password, mnemonic: testPhrase);

      expect(await service.hasRecoveryPhrase(), isTrue);
      expect(await service.revealMnemonic(password), testPhrase);
    });

    test('the wrong password does not surrender the phrase', () async {
      final keypair = await service.walletFromMnemonic(testPhrase);
      await service.storeWallet(keypair, password, mnemonic: testPhrase);

      expect(
        () => service.revealMnemonic('not the password'),
        throwsA(isA<Exception>()),
      );
    });

    test('the stored phrase is not sitting in prefs as plaintext', () async {
      final keypair = await service.walletFromMnemonic(testPhrase);
      await service.storeWallet(keypair, password, mnemonic: testPhrase);

      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        final value = prefs.get(key).toString();
        expect(value, isNot(contains('abandon')), reason: 'key: $key');
        expect(value, isNot(contains(testPhrase)), reason: 'key: $key');
      }
    });

    test('deleting the wallet takes the phrase with it', () async {
      final keypair = await service.walletFromMnemonic(testPhrase);
      await service.storeWallet(keypair, password, mnemonic: testPhrase);

      await service.deleteWallet();

      expect(await service.hasRecoveryPhrase(), isFalse);
      expect(await service.revealMnemonic(password), isNull);
    });
  });

  group('wallets from before phrases existed', () {
    test('are reported as unrecoverable rather than assumed recoverable',
        () async {
      // Stored with no mnemonic, exactly as Ed25519HDKeyPair.random() left
      // them. The screens read this to decide whether they may promise the
      // user a restore, so getting it wrong is how someone deletes their
      // funds believing twelve words will bring them back.
      final keypair = await service.walletFromMnemonic(testPhrase);
      await service.storeWallet(keypair, password);

      expect(await service.hasStoredWallet(), isTrue);
      expect(await service.hasRecoveryPhrase(), isFalse);
      expect(await service.revealMnemonic(password), isNull);
    });

    test('still unlock with their password', () async {
      final keypair = await service.walletFromMnemonic(testPhrase);
      await service.storeWallet(keypair, password);

      final loaded = await service.loadWallet(password);
      expect(loaded?.address, keypair.address);
    });
  });
}
