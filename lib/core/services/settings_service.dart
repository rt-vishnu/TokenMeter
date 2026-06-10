import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class SettingsService {
  SettingsService(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _apiKeyPrefKey = 'api_key'; // legacy SharedPreferences key
  static const _apiKeySecureKey = 'token_meter_api_key';
  static const _serverEnabledKey = 'server_enabled';
  static const _apiPortKey = 'api_port';
  static const _remoteHostKey = 'remote_host_url';
  static const _darkModeKey = 'dark_mode';
  static const _currencyKey = 'currency';

  // Cached in memory after first load to avoid async on every read.
  String? _cachedApiKey;

  /// Call once at startup to migrate legacy key and warm the cache.
  Future<void> init() async {
    final existing = await _secure.read(key: _apiKeySecureKey);
    if (existing != null) {
      _cachedApiKey = existing;
      return;
    }

    // One-time migration: move key from SharedPreferences → secure storage.
    final legacy = _prefs.getString(_apiKeyPrefKey);
    final key = legacy ?? _generateApiKey();
    await _secure.write(key: _apiKeySecureKey, value: key);
    if (legacy != null) {
      await _prefs.remove(_apiKeyPrefKey);
    }
    _cachedApiKey = key;
  }

  /// Synchronous read from cache. Call [init] before using.
  String get apiKey => _cachedApiKey ?? _generateApiKey();

  Future<String> ensureApiKey() async {
    if (_cachedApiKey != null) return _cachedApiKey!;
    await init();
    return _cachedApiKey!;
  }

  /// Generates a new random API key, persists it, and returns it.
  Future<String> regenerateApiKey() async {
    final key = _generateApiKey();
    await _secure.write(key: _apiKeySecureKey, value: key);
    _cachedApiKey = key;
    return key;
  }

  bool get serverEnabled => _prefs.getBool(_serverEnabledKey) ?? false;

  Future<void> setServerEnabled(bool value) =>
      _prefs.setBool(_serverEnabledKey, value);

  int get apiPort => _prefs.getInt(_apiPortKey) ?? AppConstants.defaultApiPort;

  Future<void> setApiPort(int port) => _prefs.setInt(_apiPortKey, port);

  String? get remoteHostUrl => _prefs.getString(_remoteHostKey);

  Future<void> setRemoteHostUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _prefs.remove(_remoteHostKey);
    } else {
      await _prefs.setString(_remoteHostKey, url);
    }
  }

  bool get darkMode => _prefs.getBool(_darkModeKey) ?? true;

  Future<void> setDarkMode(bool value) => _prefs.setBool(_darkModeKey, value);

  String get currency => _prefs.getString(_currencyKey) ?? 'USD';

  Future<void> setCurrency(String value) =>
      _prefs.setString(_currencyKey, value);

  bool get isWebClientMode {
    final host = remoteHostUrl;
    return host != null && host.isNotEmpty;
  }

  String _generateApiKey() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
