import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const _apiKeyKey = 'api_key';
  static const _serverEnabledKey = 'server_enabled';
  static const _apiPortKey = 'api_port';
  static const _remoteHostKey = 'remote_host_url';
  static const _darkModeKey = 'dark_mode';
  static const _currencyKey = 'currency';

  String get apiKey =>
      _prefs.getString(_apiKeyKey) ?? _generateApiKey();

  Future<String> ensureApiKey() async {
    final existing = _prefs.getString(_apiKeyKey);
    if (existing != null) return existing;
    final key = _generateApiKey();
    await _prefs.setString(_apiKeyKey, key);
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
