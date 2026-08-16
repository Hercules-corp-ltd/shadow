import '../models/extension.dart';
import 'local_store.dart';

/// Installed extensions, kept on the device.
///
/// All four routes this used were absent, which is why the toggle appeared to
/// work and did nothing. Which extensions are installed on this phone is
/// device state; a server cannot know it and has no reason to.
///
/// Note that Shadow has no extension runtime yet — nothing loads or executes
/// an extension. This service is the registry only, and the screen must not
/// imply otherwise.
class ExtensionsService {
  static const _store = LocalStore<ShadowExtension>(
    key: 'shadow_extensions_v1',
    encode: _encode,
    decode: ShadowExtension.fromJson,
  );

  static Map<String, dynamic> _encode(ShadowExtension e) => e.toJson();

  Future<List<ShadowExtension>> listInstalled() async {
    final all = await _store.readAll();
    return all..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> toggle(String id, bool enabled) async {
    final all = await _store.readAll();
    await _store.writeAll([
      for (final e in all)
        if (e.id == id) e.copyWith(enabled: enabled) else e,
    ]);
  }

  Future<void> uninstall(String id) async {
    final all = await _store.readAll();
    await _store.writeAll(all.where((e) => e.id != id).toList());
  }

  Future<void> clearAll() => _store.clear();
}
