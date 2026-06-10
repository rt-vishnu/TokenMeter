import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/model_pricing.dart';

class ImportResult {
  const ImportResult({
    required this.imported,
    required this.skipped,
    required this.skippedReasons,
  });

  final int imported;
  final int skipped;
  /// Map of model ID → reason it was skipped.
  final Map<String, String> skippedReasons;

  bool get hasSkipped => skipped > 0;

  String get summary {
    if (imported == 0 && skipped == 0) return 'No models found in JSON.';
    final parts = <String>[];
    if (imported > 0) {
      parts.add('$imported model${imported == 1 ? '' : 's'} imported');
    }
    if (skipped > 0) {
      parts.add('$skipped skipped');
    }
    return '${parts.join(', ')}.';
  }
}

class PricingRepository {
  PricingRepository(this._prefs);

  final SharedPreferences _prefs;
  Map<String, ModelPricing> _models = {};
  // Snapshot of bundled-only models (no custom overrides) for divergence checks.
  Map<String, ModelPricing> _bundledModels = {};
  DateTime? _lastUpdated;
  static const _customModelsKey = 'custom_models';

  Map<String, ModelPricing> get models => Map.unmodifiable(_models);
  DateTime? get lastUpdated => _lastUpdated;
  String? get loadError => _loadError;
  String? _loadError;

  List<ModelPricing> get sortedModels {
    final list = _models.values.toList();
    list.sort((a, b) => a.displayName.compareTo(b.displayName));
    return list;
  }

  Future<void> load() async {
    final String bundled;
    try {
      bundled = await rootBundle.loadString(AppConstants.pricingAssetPath);
    } catch (e) {
      _loadError = 'Could not load bundled pricing data: $e';
      _models = {};
      _bundledModels = Map.unmodifiable({});
      return;
    }

    final Map<String, dynamic> bundledMap;
    try {
      bundledMap = jsonDecode(bundled) as Map<String, dynamic>;
    } catch (e) {
      _loadError = 'Pricing JSON is malformed: $e';
      _models = {};
      _bundledModels = Map.unmodifiable({});
      return;
    }
    _loadError = null;

    // Read optional metadata block.
    final meta = bundledMap['_meta'] as Map<String, dynamic>?;
    if (meta != null) {
      final raw = meta['last_updated'] as String?;
      _lastUpdated = raw != null ? DateTime.tryParse(raw) : null;
    }

    _models = {};
    for (final entry in bundledMap.entries) {
      if (entry.key.startsWith('_')) continue; // skip _meta etc.
      _models[entry.key] = ModelPricing.fromJson(
        entry.key,
        entry.value as Map<String, dynamic>,
      );
    }
    // Keep a clean snapshot before custom overrides are applied.
    _bundledModels = Map.unmodifiable(Map.of(_models));

    final customJson = _prefs.getString(_customModelsKey);
    if (customJson != null) {
      final customMap = jsonDecode(customJson) as Map<String, dynamic>;
      for (final entry in customMap.entries) {
        _models[entry.key] = ModelPricing.fromJson(
          entry.key,
          (entry.value as Map<String, dynamic>)..['is_custom'] = true,
        );
      }
    }
  }

  ModelPricing? getModel(String id) => _models[id];

  /// Returns the bundled (non-custom) pricing for [id], or null if none exists.
  ModelPricing? getBundledModel(String id) => _bundledModels[id];

  ModelPricing getModelOrDefault(String id) {
    return _models[id] ??
        ModelPricing(
          id: id,
          provider: 'unknown',
          displayName: id,
          inputPer1M: 1.0,
          outputPer1M: 1.0,
        );
  }

  Future<void> saveCustomModel(ModelPricing model) async {
    final custom = _models.values.where((m) => m.isCustom).toList();
    final customMap = {
      for (final m in custom) m.id: m.toJson(),
      model.id: model.toJson(),
    };
    await _prefs.setString(_customModelsKey, jsonEncode(customMap));
    _models[model.id] = model.copyWith(isCustom: true);
  }

  Future<void> deleteCustomModel(String id) async {
    final model = _models[id];
    if (model == null || !model.isCustom) return;
    _models.remove(id);

    final customMap = {
      for (final m in _models.values.where((m) => m.isCustom))
        m.id: m.toJson(),
    };
    await _prefs.setString(_customModelsKey, jsonEncode(customMap));
  }

  /// Validates and imports models from a JSON string.
  /// Returns an [ImportResult] describing what was imported and what was skipped.
  Future<ImportResult> importPricingJson(String jsonString) async {
    final Map<String, dynamic> raw;
    try {
      raw = jsonDecode(jsonString) as Map<String, dynamic>;
    } on FormatException {
      throw ArgumentError('Invalid JSON — could not parse the pricing data.');
    }

    if (raw.isEmpty) {
      return const ImportResult(imported: 0, skipped: 0, skippedReasons: {});
    }

    final skippedReasons = <String, String>{};
    int imported = 0;

    for (final entry in raw.entries) {
      if (entry.key.startsWith('_')) continue;
      final id = entry.key;
      final value = entry.value;

      if (value is! Map<String, dynamic>) {
        skippedReasons[id] = 'value must be an object';
        continue;
      }

      final reason = _validateModelEntry(value);
      if (reason != null) {
        skippedReasons[id] = reason;
        continue;
      }

      _models[id] = ModelPricing.fromJson(id, value).copyWith(isCustom: true);
      imported++;
    }

    if (imported > 0) {
      final customMap = {
        for (final m in _models.values.where((m) => m.isCustom))
          m.id: m.toJson(),
      };
      await _prefs.setString(_customModelsKey, jsonEncode(customMap));
    }

    return ImportResult(
      imported: imported,
      skipped: skippedReasons.length,
      skippedReasons: skippedReasons,
    );
  }

  String? _validateModelEntry(Map<String, dynamic> entry) {
    final displayName = entry['display_name'];
    if (displayName == null) return 'missing display_name';
    if (displayName is! String || displayName.trim().isEmpty) {
      return 'display_name must be a non-empty string';
    }

    final inputPer1M = entry['input_per_1m'];
    if (inputPer1M == null) return 'missing input_per_1m';
    final inputVal = (inputPer1M as num?)?.toDouble();
    if (inputVal == null || inputVal < 0) {
      return 'input_per_1m must be a non-negative number';
    }

    final outputPer1M = entry['output_per_1m'];
    if (outputPer1M == null) return 'missing output_per_1m';
    final outputVal = (outputPer1M as num?)?.toDouble();
    if (outputVal == null || outputVal < 0) {
      return 'output_per_1m must be a non-negative number';
    }

    return null;
  }

  /// Exports all custom models as a JSON string suitable for re-importing.
  String exportCustomModels() {
    final customMap = {
      for (final m in _models.values.where((m) => m.isCustom))
        m.id: m.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(customMap);
  }

  List<Map<String, dynamic>> toApiList() {
    return _models.entries
        .map(
          (e) => {
            'id': e.key,
            ...e.value.toJson(),
          },
        )
        .toList();
  }
}
