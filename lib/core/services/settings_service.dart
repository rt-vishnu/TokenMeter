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
  static const _remoteApiKeySecureKey = 'remote_api_key';
  static const _darkModeKey = 'dark_mode';
  static const _currencyKey = 'currency';
  static const _dailyBudgetKey = 'daily_budget';
  static const _weeklyBudgetKey = 'weekly_budget';
  static const _monthlyBudgetKey = 'monthly_budget';
  static const _geminiKeySecureKey = 'gemini_api_key';
  static const _openaiKeySecureKey = 'openai_api_key';
  static const _anthropicKeySecureKey = 'anthropic_api_key';
  static const _chatProviderKey = 'chat_provider';
  static const _chatModelKey = 'chat_model';

  // Cached in memory after first load to avoid async on every read.
  String? _cachedApiKey;
  String? _cachedGeminiKey;
  String? _cachedOpenaiKey;
  String? _cachedAnthropicKey;
  String? _cachedRemoteApiKey;

  /// Call once at startup to migrate legacy key and warm the cache.
  Future<void> init() async {
    _cachedGeminiKey = await _secure.read(key: _geminiKeySecureKey);
    _cachedOpenaiKey = await _secure.read(key: _openaiKeySecureKey);
    _cachedAnthropicKey = await _secure.read(key: _anthropicKeySecureKey);
    _cachedRemoteApiKey = await _secure.read(key: _remoteApiKeySecureKey);

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

  /// API key from the phone/desktop TokenMeter instance (web client only).
  String? get remoteApiKey => _cachedRemoteApiKey;

  Future<void> setRemoteApiKey(String? key) async {
    final trimmed = key?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _secure.delete(key: _remoteApiKeySecureKey);
      _cachedRemoteApiKey = null;
    } else {
      await _secure.write(key: _remoteApiKeySecureKey, value: trimmed);
      _cachedRemoteApiKey = trimmed;
    }
  }

  bool get darkMode => _prefs.getBool(_darkModeKey) ?? true;

  Future<void> setDarkMode(bool value) => _prefs.setBool(_darkModeKey, value);

  String get currency => _prefs.getString(_currencyKey) ?? 'USD';

  Future<void> setCurrency(String value) =>
      _prefs.setString(_currencyKey, value);

  double? get dailyBudget => _prefs.getDouble(_dailyBudgetKey);
  double? get weeklyBudget => _prefs.getDouble(_weeklyBudgetKey);
  double? get monthlyBudget => _prefs.getDouble(_monthlyBudgetKey);

  Future<void> setDailyBudget(double? value) async {
    if (value == null) {
      await _prefs.remove(_dailyBudgetKey);
    } else {
      await _prefs.setDouble(_dailyBudgetKey, value);
    }
  }

  Future<void> setWeeklyBudget(double? value) async {
    if (value == null) {
      await _prefs.remove(_weeklyBudgetKey);
    } else {
      await _prefs.setDouble(_weeklyBudgetKey, value);
    }
  }

  Future<void> setMonthlyBudget(double? value) async {
    if (value == null) {
      await _prefs.remove(_monthlyBudgetKey);
    } else {
      await _prefs.setDouble(_monthlyBudgetKey, value);
    }
  }

  // ── Chat provider keys (Gemini / OpenAI / Anthropic) ──────────────────────
  // Keyed by provider id string to keep this service free of UI-layer enums.

  String? get geminiApiKey => _cachedGeminiKey;

  /// Returns the stored API key for a chat provider id, or null if unset.
  String? chatApiKey(String providerId) => switch (providerId) {
        'gemini' => _cachedGeminiKey,
        'openai' => _cachedOpenaiKey,
        'anthropic' => _cachedAnthropicKey,
        _ => null,
      };

  Future<void> setChatApiKey(String providerId, String? value) async {
    final secureKey = switch (providerId) {
      'gemini' => _geminiKeySecureKey,
      'openai' => _openaiKeySecureKey,
      'anthropic' => _anthropicKeySecureKey,
      _ => null,
    };
    if (secureKey == null) return;

    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _secure.delete(key: secureKey);
    } else {
      await _secure.write(key: secureKey, value: trimmed);
    }
    switch (providerId) {
      case 'gemini':
        _cachedGeminiKey = trimmed?.isEmpty ?? true ? null : trimmed;
      case 'openai':
        _cachedOpenaiKey = trimmed?.isEmpty ?? true ? null : trimmed;
      case 'anthropic':
        _cachedAnthropicKey = trimmed?.isEmpty ?? true ? null : trimmed;
    }
  }

  /// Selected chat provider id (gemini/openai/anthropic).
  String get chatProvider => _prefs.getString(_chatProviderKey) ?? 'gemini';

  Future<void> setChatProvider(String value) =>
      _prefs.setString(_chatProviderKey, value);

  String get chatModel =>
      _prefs.getString(_chatModelKey) ?? 'gemini-2.5-flash-lite';

  Future<void> setChatModel(String value) =>
      _prefs.setString(_chatModelKey, value);

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
