/// Blind's identity layer.
///
/// One recovery phrase in, a different unlinkable account for every site out.
/// Pure Dart with no platform channels, so it behaves identically on iOS,
/// Android and under test.
library;

export 'blind_identity.dart';
export 'blind_kdf.dart';
export 'handle_shaper.dart';
export 'password_policy.dart';
export 'password_shaper.dart';
export 'registrable_domain.dart';
export 'site_identity.dart';
