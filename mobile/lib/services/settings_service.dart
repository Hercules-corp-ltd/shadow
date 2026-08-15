import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BlindSettings {
  // General
  final bool analyticsEnabled;
  final bool telemetryEnabled;
  final bool autoUpdateEnabled;
  final String language;

  // Network
  final String network; // mainnet | devnet | testnet
  final String rpcUrl;
  final bool useTor;
  final bool ipfsEnabled;
  final bool arweaveEnabled;

  // Storage
  final int maxCacheMb;
  final int maxHistoryItems;
  final bool autoClearCache;

  // Security
  final bool requireUnlock;
  final int autoLockMinutes;
  final bool biometricsEnabled;

  // Advanced
  final bool developerMode;
  final bool experimentalFeatures;
  final String logLevel; // debug | info | warn | error

  const BlindSettings({
    this.analyticsEnabled = true,
    this.telemetryEnabled = false,
    this.autoUpdateEnabled = true,
    this.language = 'en',
    this.network = 'mainnet',
    this.rpcUrl = 'https://api.mainnet-beta.solana.com',
    this.useTor = false,
    this.ipfsEnabled = true,
    this.arweaveEnabled = true,
    this.maxCacheMb = 512,
    this.maxHistoryItems = 1000,
    this.autoClearCache = false,
    this.requireUnlock = true,
    this.autoLockMinutes = 15,
    this.biometricsEnabled = false,
    this.developerMode = false,
    this.experimentalFeatures = false,
    this.logLevel = 'info',
  });

  BlindSettings copyWith({
    bool? analyticsEnabled,
    bool? telemetryEnabled,
    bool? autoUpdateEnabled,
    String? language,
    String? network,
    String? rpcUrl,
    bool? useTor,
    bool? ipfsEnabled,
    bool? arweaveEnabled,
    int? maxCacheMb,
    int? maxHistoryItems,
    bool? autoClearCache,
    bool? requireUnlock,
    int? autoLockMinutes,
    bool? biometricsEnabled,
    bool? developerMode,
    bool? experimentalFeatures,
    String? logLevel,
  }) =>
      BlindSettings(
        analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
        telemetryEnabled: telemetryEnabled ?? this.telemetryEnabled,
        autoUpdateEnabled: autoUpdateEnabled ?? this.autoUpdateEnabled,
        language: language ?? this.language,
        network: network ?? this.network,
        rpcUrl: rpcUrl ?? this.rpcUrl,
        useTor: useTor ?? this.useTor,
        ipfsEnabled: ipfsEnabled ?? this.ipfsEnabled,
        arweaveEnabled: arweaveEnabled ?? this.arweaveEnabled,
        maxCacheMb: maxCacheMb ?? this.maxCacheMb,
        maxHistoryItems: maxHistoryItems ?? this.maxHistoryItems,
        autoClearCache: autoClearCache ?? this.autoClearCache,
        requireUnlock: requireUnlock ?? this.requireUnlock,
        autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
        biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
        developerMode: developerMode ?? this.developerMode,
        experimentalFeatures: experimentalFeatures ?? this.experimentalFeatures,
        logLevel: logLevel ?? this.logLevel,
      );

  Map<String, dynamic> toJson() => {
        'analytics_enabled': analyticsEnabled,
        'telemetry_enabled': telemetryEnabled,
        'auto_update_enabled': autoUpdateEnabled,
        'language': language,
        'network': network,
        'rpc_url': rpcUrl,
        'use_tor': useTor,
        'ipfs_enabled': ipfsEnabled,
        'arweave_enabled': arweaveEnabled,
        'max_cache_mb': maxCacheMb,
        'max_history_items': maxHistoryItems,
        'auto_clear_cache': autoClearCache,
        'require_unlock': requireUnlock,
        'auto_lock_minutes': autoLockMinutes,
        'biometrics_enabled': biometricsEnabled,
        'developer_mode': developerMode,
        'experimental_features': experimentalFeatures,
        'log_level': logLevel,
      };

  factory BlindSettings.fromJson(Map<String, dynamic> j) => BlindSettings(
        analyticsEnabled: j['analytics_enabled'] ?? true,
        telemetryEnabled: j['telemetry_enabled'] ?? false,
        autoUpdateEnabled: j['auto_update_enabled'] ?? true,
        language: j['language'] ?? 'en',
        network: j['network'] ?? 'mainnet',
        rpcUrl: j['rpc_url'] ?? 'https://api.mainnet-beta.solana.com',
        useTor: j['use_tor'] ?? false,
        ipfsEnabled: j['ipfs_enabled'] ?? true,
        arweaveEnabled: j['arweave_enabled'] ?? true,
        maxCacheMb: (j['max_cache_mb'] ?? 512) as int,
        maxHistoryItems: (j['max_history_items'] ?? 1000) as int,
        autoClearCache: j['auto_clear_cache'] ?? false,
        requireUnlock: j['require_unlock'] ?? true,
        autoLockMinutes: (j['auto_lock_minutes'] ?? 15) as int,
        biometricsEnabled: j['biometrics_enabled'] ?? false,
        developerMode: j['developer_mode'] ?? false,
        experimentalFeatures: j['experimental_features'] ?? false,
        logLevel: j['log_level'] ?? 'info',
      );
}

class SettingsService {
  static const _key = 'blind_settings_v1';

  Future<BlindSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const BlindSettings();
    try {
      return BlindSettings.fromJson(Map<String, dynamic>.from(json.decode(raw)));
    } catch (_) {
      return const BlindSettings();
    }
  }

  Future<void> save(BlindSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(settings.toJson()));
  }
}
