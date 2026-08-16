import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A list of records kept on the device.
///
/// Bookmarks, history, downloads, extensions and activity all used to be
/// fetched from server routes that were never built, so every one of them
/// failed on load and then rendered the failure as an empty list. They are
/// also, all five, things a browser has no business keeping on someone else's
/// computer — `docs/decisions/0001-postgres-on-supabase.md` says as much: a
/// privacy browser holding a server-side record of what its users looked at
/// is the contradiction at the centre of this codebase.
///
/// Follows the shape already used by `SettingsService`: a typed model, JSON,
/// SharedPreferences. Deliberately not a database. These lists are small,
/// read whole, and written whole; sqflite would be more machinery for no gain.
///
/// Note this is *not* encrypted. It is ordinary app-private storage, which is
/// the same protection the OS gives any browser's history. Secrets belong in
/// [IdentityVault], which uses the platform keystore instead.
class LocalStore<T> {
  const LocalStore({
    required this.key,
    required this.encode,
    required this.decode,
  });

  /// SharedPreferences key. Version it, so a model change can migrate rather
  /// than crash on old data.
  final String key;

  final Map<String, dynamic> Function(T value) encode;
  final T Function(Map<String, dynamic> json) decode;

  /// Always returns a growable, modifiable list.
  ///
  /// Callers sort and append in place, so returning `const []` or a
  /// fixed-length list throws "Cannot modify an unmodifiable list" — and it
  /// throws on the *empty* path, meaning it would have fired on first launch
  /// before anyone had saved anything.
  Future<List<T>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <T>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <T>[];
      return decoded.whereType<Map<String, dynamic>>().map(decode).toList();
    } on FormatException {
      // Corrupt, or written by an older schema. Empty is the right answer —
      // the alternative is throwing on every launch forever, and this data is
      // regenerable just by using the app.
      return <T>[];
    }
  }

  Future<void> writeAll(List<T> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(items.map(encode).toList(growable: false)),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
