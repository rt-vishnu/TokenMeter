class ModelPricing {
  const ModelPricing({
    required this.id,
    required this.provider,
    required this.displayName,
    required this.inputPer1M,
    required this.outputPer1M,
    this.isCustom = false,
    this.deprecated = false,
  });

  final String id;
  final String provider;
  final String displayName;
  final double inputPer1M;
  final double outputPer1M;
  final bool isCustom;

  /// Retired by the provider — kept for costing historical records, but
  /// hidden from model pickers so users can't select it.
  final bool deprecated;

  factory ModelPricing.fromJson(String id, Map<String, dynamic> json) {
    return ModelPricing(
      id: id,
      provider: json['provider'] as String? ?? 'custom',
      displayName: json['display_name'] as String? ?? id,
      inputPer1M: (json['input_per_1m'] as num).toDouble(),
      outputPer1M: (json['output_per_1m'] as num).toDouble(),
      isCustom: json['is_custom'] as bool? ?? false,
      deprecated: json['deprecated'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'display_name': displayName,
        'input_per_1m': inputPer1M,
        'output_per_1m': outputPer1M,
        'is_custom': isCustom,
        if (deprecated) 'deprecated': true,
      };

  ModelPricing copyWith({
    String? id,
    String? provider,
    String? displayName,
    double? inputPer1M,
    double? outputPer1M,
    bool? isCustom,
    bool? deprecated,
  }) {
    return ModelPricing(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      displayName: displayName ?? this.displayName,
      inputPer1M: inputPer1M ?? this.inputPer1M,
      outputPer1M: outputPer1M ?? this.outputPer1M,
      isCustom: isCustom ?? this.isCustom,
      deprecated: deprecated ?? this.deprecated,
    );
  }
}
