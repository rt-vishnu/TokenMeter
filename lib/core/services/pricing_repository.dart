import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/model_pricing.dart';

class PricingRepository {
  PricingRepository(this._prefs);

  final SharedPreferences _prefs;
  Map<String, ModelPricing> _models = {};
  static const _customModelsKey = 'custom_models';

  Map<String, ModelPricing> get models => Map.unmodifiable(_models);

  List<ModelPricing> get sortedModels {
    final list = _models.values.toList();
    list.sort((a, b) => a.displayName.compareTo(b.displayName));
    return list;
  }

  Future<void> load() async {
    final bundled = await rootBundle.loadString(AppConstants.pricingAssetPath);
    final bundledMap = jsonDecode(bundled) as Map<String, dynamic>;
    _models = bundledMap.map(
      (id, value) => MapEntry(
        id,
        ModelPricing.fromJson(id, value as Map<String, dynamic>),
      ),
    );

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

  Future<void> importPricingJson(String jsonString) async {
    final imported = jsonDecode(jsonString) as Map<String, dynamic>;
    for (final entry in imported.entries) {
      _models[entry.key] = ModelPricing.fromJson(
        entry.key,
        entry.value as Map<String, dynamic>,
      ).copyWith(isCustom: true);
    }

    final customMap = {
      for (final m in _models.values.where((m) => m.isCustom))
        m.id: m.toJson(),
    };
    await _prefs.setString(_customModelsKey, jsonEncode(customMap));
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
