/// The per-site rules a generated password has to satisfy.
///
/// This is the state that pure derivation cannot know and the user cannot
/// remember, and it is the reason a site adapter is worth owning: no single
/// password shape satisfies every site, so the shape has to be published,
/// versioned and shared rather than guessed.
class PasswordPolicy {
  const PasswordPolicy({
    this.minLength = 16,
    this.maxLength = 64,
    this.preferredLength = 24,
    this.requireLowercase = true,
    this.requireUppercase = true,
    this.requireDigit = true,
    this.requireSymbol = true,
    this.symbols = defaultSymbols,
    this.bannedCharacters = '',
  });

  /// A conservative shape that most sites accept.
  static const PasswordPolicy standard = PasswordPolicy();

  /// For sites that reject punctuation outright.
  static const PasswordPolicy alphanumericOnly = PasswordPolicy(
    requireSymbol: false,
    symbols: '',
  );

  /// For legacy sites with short maximums — still strong at 12 characters,
  /// but worth flagging in the UI as the site's limitation, not ours.
  static const PasswordPolicy legacyShort = PasswordPolicy(
    minLength: 8,
    maxLength: 12,
    preferredLength: 12,
  );

  /// Deliberately excludes backslash, quotes, backtick, angle brackets and
  /// semicolon. Those survive a password field only to break later, when the
  /// value passes through a shell, a JSON payload or a site's own escaping.
  static const String defaultSymbols = r'!#$%&*+-=?@^_';

  // Visually ambiguous characters are excluded throughout: no l/I/1 and no
  // O/0. Users do read these aloud and retype them by hand when a site
  // refuses a paste, and the ~0.4 bits per character this costs is far
  // cheaper than a password that cannot be transcribed.
  static const String lowercaseAlphabet = 'abcdefghijkmnopqrstuvwxyz';
  static const String uppercaseAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const String digitAlphabet = '23456789';

  final int minLength;
  final int maxLength;
  final int preferredLength;
  final bool requireLowercase;
  final bool requireUppercase;
  final bool requireDigit;
  final bool requireSymbol;
  final String symbols;

  /// Characters the site rejects, on top of the class rules.
  final String bannedCharacters;

  /// The length to actually generate: the preferred length, pulled inside
  /// whatever window the site allows.
  int get targetLength => preferredLength.clamp(minLength, maxLength);

  String get lowercase => _strip(lowercaseAlphabet);
  String get uppercase => _strip(uppercaseAlphabet);
  String get digits => _strip(digitAlphabet);
  String get symbolSet => _strip(symbols);

  /// Every character the generator may emit.
  String get alphabet {
    final buffer = StringBuffer()
      ..write(lowercase)
      ..write(uppercase)
      ..write(digits);
    if (requireSymbol || symbols.isNotEmpty) buffer.write(symbolSet);
    return buffer.toString();
  }

  String _strip(String source) {
    if (bannedCharacters.isEmpty) return source;
    final banned = bannedCharacters.split('').toSet();
    return source.split('').where((c) => !banned.contains(c)).join();
  }

  /// Throws [StateError] when the rules cannot be satisfied at all, which is
  /// a bug in an adapter rather than something a user can act on.
  void validate() {
    if (minLength < 1) {
      throw StateError('Password policy minLength must be at least 1');
    }
    if (maxLength < minLength) {
      throw StateError(
        'Password policy maxLength ($maxLength) is below minLength ($minLength)',
      );
    }
    if (alphabet.isEmpty) {
      throw StateError('Password policy bans every available character');
    }

    var requiredClasses = 0;
    if (requireLowercase) {
      if (lowercase.isEmpty) {
        throw StateError('Policy requires lowercase but bans every lowercase character');
      }
      requiredClasses++;
    }
    if (requireUppercase) {
      if (uppercase.isEmpty) {
        throw StateError('Policy requires uppercase but bans every uppercase character');
      }
      requiredClasses++;
    }
    if (requireDigit) {
      if (digits.isEmpty) {
        throw StateError('Policy requires a digit but bans every digit');
      }
      requiredClasses++;
    }
    if (requireSymbol) {
      if (symbolSet.isEmpty) {
        throw StateError('Policy requires a symbol but allows no symbols');
      }
      requiredClasses++;
    }

    if (requiredClasses > targetLength) {
      throw StateError(
        'Password policy requires $requiredClasses character classes but '
        'allows only $targetLength characters',
      );
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'minLength': minLength,
        'maxLength': maxLength,
        'preferredLength': preferredLength,
        'requireLowercase': requireLowercase,
        'requireUppercase': requireUppercase,
        'requireDigit': requireDigit,
        'requireSymbol': requireSymbol,
        'symbols': symbols,
        if (bannedCharacters.isNotEmpty) 'bannedCharacters': bannedCharacters,
      };

  factory PasswordPolicy.fromJson(Map<String, dynamic> json) {
    return PasswordPolicy(
      minLength: json['minLength'] as int? ?? 16,
      maxLength: json['maxLength'] as int? ?? 64,
      preferredLength: json['preferredLength'] as int? ?? 24,
      requireLowercase: json['requireLowercase'] as bool? ?? true,
      requireUppercase: json['requireUppercase'] as bool? ?? true,
      requireDigit: json['requireDigit'] as bool? ?? true,
      requireSymbol: json['requireSymbol'] as bool? ?? true,
      symbols: json['symbols'] as String? ?? defaultSymbols,
      bannedCharacters: json['bannedCharacters'] as String? ?? '',
    );
  }
}
