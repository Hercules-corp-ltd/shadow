import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Low-level key-derivation primitives shared by the identity layer.
///
/// Implemented here rather than pulled from a package so the identity core
/// stays pure Dart with no platform channels — it runs identically on iOS,
/// Android and in unit tests, and adds nothing to the CocoaPods graph.
class ShadowKdf {
  ShadowKdf._();

  static const int _hashLength = 64; // SHA-512

  /// HKDF-Extract (RFC 5869 §2.2).
  static Uint8List extract({
    required List<int> salt,
    required List<int> inputKeyMaterial,
  }) {
    return Uint8List.fromList(
      Hmac(sha512, salt).convert(inputKeyMaterial).bytes,
    );
  }

  /// HKDF-Expand (RFC 5869 §2.3).
  static Uint8List expand({
    required List<int> pseudoRandomKey,
    required String info,
    required int length,
  }) {
    if (length <= 0) {
      throw ArgumentError.value(length, 'length', 'must be positive');
    }
    final blocks = (length / _hashLength).ceil();
    if (blocks > 255) {
      throw ArgumentError.value(
        length,
        'length',
        'HKDF cannot expand beyond 255 blocks',
      );
    }

    final infoBytes = utf8.encode(info);
    final output = <int>[];
    var previous = const <int>[];

    for (var counter = 1; counter <= blocks; counter++) {
      previous = Hmac(sha512, pseudoRandomKey)
          .convert(<int>[...previous, ...infoBytes, counter]).bytes;
      output.addAll(previous);
    }

    return Uint8List.fromList(output.sublist(0, length));
  }

  /// Full extract-then-expand, the only form callers should normally need.
  static Uint8List derive({
    required List<int> inputKeyMaterial,
    required String salt,
    required String info,
    required int length,
  }) {
    final prk = extract(
      salt: utf8.encode(salt),
      inputKeyMaterial: inputKeyMaterial,
    );
    return expand(pseudoRandomKey: prk, info: info, length: length);
  }
}

/// A deterministic, unbounded byte stream seeded from fixed entropy.
///
/// Password and handle shaping need more decisions than a single 32-byte
/// secret can cover, and those decisions must be reproducible: the same seed
/// must always yield the same password. This expands one secret into as many
/// bytes as the shapers ask for, using HMAC-SHA-512 in counter mode.
class DeterministicBytes {
  DeterministicBytes(List<int> seed, {String domainSeparator = 'stream'})
      : _seed = List<int>.unmodifiable(seed),
        _domainSeparator = domainSeparator;

  final List<int> _seed;
  final String _domainSeparator;

  int _counter = 0;
  List<int> _buffer = const <int>[];
  int _offset = 0;

  void _refill() {
    _buffer = Hmac(sha512, _seed)
        .convert(utf8.encode('$_domainSeparator|$_counter'))
        .bytes;
    _counter++;
    _offset = 0;
  }

  int nextByte() {
    if (_offset >= _buffer.length) _refill();
    return _buffer[_offset++];
  }

  /// A uniformly distributed integer in `[0, bound)`.
  ///
  /// Uses rejection sampling rather than a modulo fold. Folding would bias
  /// selection toward the low end of any alphabet whose size is not a power
  /// of two, which for password generation quietly costs real entropy.
  int nextInt(int bound) {
    if (bound <= 0) {
      throw ArgumentError.value(bound, 'bound', 'must be positive');
    }
    if (bound == 1) return 0;

    // Smallest byte count that covers the range.
    var byteCount = 1;
    while ((1 << (8 * byteCount)) < bound) {
      byteCount++;
    }
    final range = 1 << (8 * byteCount);
    final limit = range - (range % bound); // largest unbiased multiple

    while (true) {
      var value = 0;
      for (var i = 0; i < byteCount; i++) {
        value = (value << 8) | nextByte();
      }
      if (value < limit) return value % bound;
    }
  }

  /// In-place Fisher-Yates shuffle driven by this stream.
  void shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }
}

/// RFC 4648 base32, lowercase and unpadded.
///
/// Email local-parts must survive case-insensitive handling by mail servers,
/// so the alphabet is lowercased and no padding character is emitted.
String base32Encode(List<int> bytes) {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz234567';
  final buffer = StringBuffer();
  var accumulator = 0;
  var bits = 0;

  for (final byte in bytes) {
    accumulator = (accumulator << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      buffer.write(alphabet[(accumulator >> (bits - 5)) & 31]);
      bits -= 5;
    }
  }
  if (bits > 0) {
    buffer.write(alphabet[(accumulator << (5 - bits)) & 31]);
  }
  return buffer.toString();
}
