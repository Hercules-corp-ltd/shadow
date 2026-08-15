import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_mobile/utils/validators.dart';

void main() {
  group('Validators.isValidPubkey', () {
    test('accepts a realistic base58 Solana pubkey', () {
      expect(
        Validators.isValidPubkey('11111111111111111111111111111111'),
        isTrue,
      );
      expect(
        Validators.isValidPubkey(
          'HN7cABqLq46Es1jh92dQQisAq662SmxELLLsHHe4YWrH',
        ),
        isTrue,
      );
    });

    test('rejects too-short, too-long, or non-base58 keys', () {
      expect(Validators.isValidPubkey('short'), isFalse);
      expect(Validators.isValidPubkey('0' * 50), isFalse);
      // '0', 'O', 'I', 'l' are not valid base58 characters.
      expect(
        Validators.isValidPubkey('0000000000000000000000000000000O'),
        isFalse,
      );
    });
  });

  group('Validators.isValidDomain', () {
    test('accepts normal domains', () {
      expect(Validators.isValidDomain('example.shadow'), isTrue);
      expect(Validators.isValidDomain('sub.my-site.shadow'), isTrue);
    });

    test('rejects empty or malformed domains', () {
      expect(Validators.isValidDomain(''), isFalse);
      expect(Validators.isValidDomain('-bad.shadow'), isFalse);
      expect(Validators.isValidDomain('bad-.shadow'), isFalse);
      expect(Validators.isValidDomain('a' * 254), isFalse);
    });
  });

  group('Validators.isValidIPFSCid', () {
    test('accepts v0, v1, and ipfs:// CIDs', () {
      expect(
        Validators.isValidIPFSCid(
          'QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG',
        ),
        isTrue,
      );
      expect(
        Validators.isValidIPFSCid(
          'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi',
        ),
        isTrue,
      );
      expect(Validators.isValidIPFSCid('ipfs://Qmfoo'), isTrue);
    });

    test('rejects obviously non-CID strings', () {
      expect(Validators.isValidIPFSCid(''), isFalse);
      expect(Validators.isValidIPFSCid('not a cid'), isFalse);
    });
  });

  group('Validators.isValidSearchQuery', () {
    test('accepts safe queries', () {
      expect(Validators.isValidSearchQuery('hello world'), isTrue);
      expect(Validators.isValidSearchQuery('solana docs'), isTrue);
    });

    test('rejects empty, oversized, or dangerous queries', () {
      expect(Validators.isValidSearchQuery(''), isFalse);
      expect(Validators.isValidSearchQuery('a' * 201), isFalse);
      expect(Validators.isValidSearchQuery('<script>'), isFalse);
      expect(Validators.isValidSearchQuery("bobby's tables"), isFalse);
    });
  });

  group('Validators.isStrongPassword', () {
    test('requires upper, lower, number, and 8+ chars', () {
      expect(Validators.isStrongPassword('Abcdef12'), isTrue);
      expect(Validators.isStrongPassword('short1A'), isFalse);
      expect(Validators.isStrongPassword('alllower1'), isFalse);
      expect(Validators.isStrongPassword('ALLUPPER1'), isFalse);
      expect(Validators.isStrongPassword('NoNumbers'), isFalse);
    });
  });

  group('Validators.sanitizeInput', () {
    test('escapes HTML-special characters and trims whitespace', () {
      expect(
        Validators.sanitizeInput('  <b>"hi"</b> '),
        equals('&lt;b&gt;&quot;hi&quot;&lt;/b&gt;'),
      );
      expect(Validators.sanitizeInput("it's fine"), equals('it&#x27;s fine'));
    });
  });

  group('Validators.formatWalletAddress', () {
    test('truncates long addresses to 4...4', () {
      expect(
        Validators.formatWalletAddress(
          'HN7cABqLq46Es1jh92dQQisAq662SmxELLLsHHe4YWrH',
        ),
        equals('HN7c...YWrH'),
      );
    });

    test('returns short addresses unchanged', () {
      expect(Validators.formatWalletAddress('abc123'), equals('abc123'));
    });
  });

  group('Validators.isValidUrl / extractDomain', () {
    test('accepts http/https URLs only', () {
      expect(Validators.isValidUrl('https://example.com'), isTrue);
      expect(Validators.isValidUrl('http://example.com/path'), isTrue);
      expect(Validators.isValidUrl('ftp://example.com'), isFalse);
      expect(Validators.isValidUrl('not a url'), isFalse);
    });

    test('extracts the host', () {
      expect(
        Validators.extractDomain('https://sub.example.com/some/path?q=1'),
        equals('sub.example.com'),
      );
    });
  });
}
