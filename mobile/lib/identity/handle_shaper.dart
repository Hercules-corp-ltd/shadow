import 'shadow_kdf.dart';

/// Builds a per-site username.
///
/// Random base32 would be simpler, but a great many sites quietly score
/// account names for "bot-likeness" at signup, and a pronounceable
/// word-word-number handle passes where `k7fq3z9x` draws a challenge. The
/// goal is a name that looks like a person picked it while still being
/// unlinkable to every other account the same seed produces.
class HandleShaper {
  HandleShaper._();

  static const List<String> _adjectives = <String>[
    'amber',
    'ancient',
    'arctic',
    'autumn',
    'blue',
    'bold',
    'brave',
    'bright',
    'calm',
    'clever',
    'cobalt',
    'cosmic',
    'crimson',
    'crystal',
    'daily',
    'dawn',
    'deep',
    'dusty',
    'eager',
    'early',
    'east',
    'electric',
    'ember',
    'fair',
    'fast',
    'fern',
    'first',
    'flint',
    'free',
    'frost',
    'gentle',
    'gilded',
    'glass',
    'golden',
    'grand',
    'green',
    'grey',
    'happy',
    'hidden',
    'high',
    'hollow',
    'humble',
    'ivory',
    'jade',
    'keen',
    'kind',
    'late',
    'lively',
    'lone',
    'lucky',
    'lunar',
    'marble',
    'mellow',
    'mighty',
    'misty',
    'modern',
    'north',
    'olive',
    'open',
    'pale',
    'patient',
    'plain',
    'polar',
    'proud',
    'quick',
    'quiet',
    'rapid',
    'raven',
    'ready',
    'red',
    'river',
    'rough',
    'royal',
    'rustic',
    'sable',
    'sage',
    'salt',
    'sharp',
    'silent',
    'silver',
    'simple',
    'slate',
    'small',
    'smooth',
    'snowy',
    'solar',
    'solid',
    'south',
    'spare',
    'spring',
    'steady',
    'steel',
    'still',
    'stone',
    'storm',
    'summer',
    'sunny',
    'swift',
    'tall',
    'teal',
    'tidy',
    'true',
    'urban',
    'velvet',
    'violet',
    'warm',
    'west',
    'wild',
    'winter',
    'wise',
    'young',
  ];

  static const List<String> _nouns = <String>[
    'acorn',
    'anchor',
    'arbor',
    'arrow',
    'aspen',
    'atlas',
    'basin',
    'beacon',
    'birch',
    'bison',
    'bloom',
    'bluff',
    'branch',
    'bridge',
    'brook',
    'canyon',
    'cedar',
    'cliff',
    'clover',
    'comet',
    'compass',
    'coral',
    'cove',
    'crane',
    'creek',
    'crest',
    'delta',
    'dune',
    'eagle',
    'ember',
    'falcon',
    'fathom',
    'fern',
    'field',
    'finch',
    'fjord',
    'forest',
    'forge',
    'fox',
    'garden',
    'glade',
    'glacier',
    'granite',
    'grove',
    'harbor',
    'harvest',
    'haven',
    'hawk',
    'heron',
    'hollow',
    'horizon',
    'island',
    'juniper',
    'lantern',
    'ledge',
    'lily',
    'linden',
    'lodge',
    'maple',
    'meadow',
    'mesa',
    'meteor',
    'moss',
    'mountain',
    'oak',
    'oasis',
    'orchard',
    'osprey',
    'otter',
    'palm',
    'peak',
    'pebble',
    'pine',
    'plateau',
    'pond',
    'prairie',
    'quarry',
    'quill',
    'rapids',
    'reef',
    'ridge',
    'river',
    'sable',
    'sage',
    'sail',
    'sequoia',
    'shore',
    'signal',
    'sparrow',
    'spruce',
    'stone',
    'stream',
    'summit',
    'thicket',
    'thorn',
    'tide',
    'timber',
    'trail',
    'tundra',
    'valley',
    'vale',
    'wave',
    'willow',
    'window',
    'wolf',
    'wren',
  ];

  /// Four words naming *which* identity is unlocked, such as
  /// `quiet harbor · golden fern`.
  ///
  /// Not a credential and not a secret — a label, so a user can recognise
  /// their own identity at a glance and notice when a mistyped passphrase
  /// has handed them somebody else's empty universe. Words rather than hex
  /// because the whole job is "does this look like what I saw last time",
  /// and people are far better at that with language than with `a3f19c`.
  ///
  /// About 27 bits, which is ample: a wrong passphrase produces an unrelated
  /// fingerprint essentially every time.
  static String fingerprint(List<int> entropy) {
    final stream = DeterministicBytes(entropy, domainSeparator: 'fingerprint');
    final first = '${_adjectives[stream.nextInt(_adjectives.length)]} '
        '${_nouns[stream.nextInt(_nouns.length)]}';
    final second = '${_adjectives[stream.nextInt(_adjectives.length)]} '
        '${_nouns[stream.nextInt(_nouns.length)]}';
    return '$first · $second';
  }

  /// Produces a handle such as `quietharbor4821`.
  ///
  /// [separator] is empty by default because many sites reject punctuation in
  /// usernames; adapters for sites that allow it can pass `_` or `-`.
  static String shape({
    required List<int> entropy,
    String separator = '',
    int digits = 4,
  }) {
    final stream = DeterministicBytes(entropy, domainSeparator: 'handle');
    final adjective = _adjectives[stream.nextInt(_adjectives.length)];
    final noun = _nouns[stream.nextInt(_nouns.length)];

    final buffer = StringBuffer()
      ..write(adjective)
      ..write(separator)
      ..write(noun);

    if (digits > 0) {
      buffer.write(separator);
      for (var i = 0; i < digits; i++) {
        buffer.write(stream.nextInt(10));
      }
    }
    return buffer.toString();
  }

  /// Roughly how many distinct handles the scheme can produce, for surfacing
  /// collision risk honestly in the UI rather than pretending it is zero.
  static int combinations({int digits = 4}) {
    var total = _adjectives.length * _nouns.length;
    for (var i = 0; i < digits; i++) {
      total *= 10;
    }
    return total;
  }
}
