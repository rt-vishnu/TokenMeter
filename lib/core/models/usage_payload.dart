import 'dart:convert';

class UsagePayload {
  const UsagePayload({
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    this.source = 'unknown',
    this.sessionId,
    this.timestamp,
    this.metadata = const {},
  });

  final String model;
  final int inputTokens;
  final int outputTokens;
  final String source;
  final String? sessionId;
  final DateTime? timestamp;
  final Map<String, dynamic> metadata;

  static const _maxTokens = 2000000;
  static const _maxMetadataBytes = 4096;
  static const _maxMetadataValueLength = 500;
  static const _allowedMetadataKeys = {
    'prompt_preview',
    'session_label',
    'tool',
    'note',
  };
  static const _maxSourceLength = 50;
  static const _maxSessionIdLength = 100;
  static const _maxModelLength = 100;

  factory UsagePayload.fromJson(Map<String, dynamic> json) {
    final model = json['model'];
    final inputTokens = json['input_tokens'];
    final outputTokens = json['output_tokens'];

    if (model is! String) {
      throw ArgumentError('model must be a string');
    }
    if (inputTokens is! int) {
      throw ArgumentError('input_tokens must be an integer');
    }
    if (outputTokens is! int) {
      throw ArgumentError('output_tokens must be an integer');
    }

    final payload = UsagePayload(
      model: model,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      source: json['source'] as String? ?? 'unknown',
      sessionId: json['session_id'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map? ?? {},
      ),
    );
    payload._validate();
    return payload;
  }

  void _validate() {
    if (model.isEmpty) {
      throw ArgumentError('model must not be empty');
    }
    if (model.length > _maxModelLength) {
      throw ArgumentError('model must not exceed $_maxModelLength characters');
    }
    if (inputTokens < 0) {
      throw ArgumentError('input_tokens must be non-negative');
    }
    if (inputTokens > _maxTokens) {
      throw ArgumentError(
          'input_tokens exceeds maximum (${_formatInt(_maxTokens)})');
    }
    if (outputTokens < 0) {
      throw ArgumentError('output_tokens must be non-negative');
    }
    if (outputTokens > _maxTokens) {
      throw ArgumentError(
          'output_tokens exceeds maximum (${_formatInt(_maxTokens)})');
    }
    if (source.length > _maxSourceLength) {
      throw ArgumentError('source must not exceed $_maxSourceLength characters');
    }
    if (sessionId != null && sessionId!.length > _maxSessionIdLength) {
      throw ArgumentError(
          'session_id must not exceed $_maxSessionIdLength characters');
    }
    final metadataSize = utf8.encode(jsonEncode(metadata)).length;
    if (metadataSize > _maxMetadataBytes) {
      throw ArgumentError(
          'metadata must not exceed $_maxMetadataBytes bytes (got $metadataSize bytes)');
    }
    _validateMetadataKeys();
  }

  void _validateMetadataKeys() {
    for (final entry in metadata.entries) {
      if (!_allowedMetadataKeys.contains(entry.key)) {
        throw ArgumentError('metadata key "${entry.key}" is not allowed');
      }
      final value = entry.value;
      if (value is! String && value is! num && value is! bool) {
        throw ArgumentError(
            'metadata values must be strings, numbers, or booleans');
      }
      if (value is String && value.length > _maxMetadataValueLength) {
        throw ArgumentError(
            'metadata string values must not exceed $_maxMetadataValueLength characters');
      }
    }
  }

  static String _formatInt(int n) {
    // Simple comma formatting for error messages, e.g. 2000000 → "2,000,000"
    return n.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]},',
        );
  }
}

class EstimatePayload {
  const EstimatePayload({
    required this.model,
    this.inputTokens,
    this.outputTokens,
    this.promptText,
    this.completionText,
  });

  final String model;
  final int? inputTokens;
  final int? outputTokens;
  final String? promptText;
  final String? completionText;

  static const _maxTokens = 2000000;
  static const _maxModelLength = 100;

  factory EstimatePayload.fromJson(Map<String, dynamic> json) {
    final model = json['model'];
    if (model is! String) {
      throw ArgumentError('model must be a string');
    }

    final inputTokens = json['input_tokens'];
    final outputTokens = json['output_tokens'];

    if (inputTokens != null && inputTokens is! int) {
      throw ArgumentError('input_tokens must be an integer');
    }
    if (outputTokens != null && outputTokens is! int) {
      throw ArgumentError('output_tokens must be an integer');
    }

    final payload = EstimatePayload(
      model: model,
      inputTokens: inputTokens as int?,
      outputTokens: outputTokens as int?,
      promptText: json['prompt_text'] as String?,
      completionText: json['completion_text'] as String?,
    );
    payload._validate();
    return payload;
  }

  void _validate() {
    if (model.isEmpty) {
      throw ArgumentError('model must not be empty');
    }
    if (model.length > _maxModelLength) {
      throw ArgumentError('model must not exceed $_maxModelLength characters');
    }

    final hasTokens = inputTokens != null || outputTokens != null;
    final hasText = (promptText != null && promptText!.isNotEmpty) ||
        (completionText != null && completionText!.isNotEmpty);

    if (!hasTokens && !hasText) {
      throw ArgumentError(
          'Provide either token counts or prompt/completion text');
    }

    if (inputTokens != null && inputTokens! < 0) {
      throw ArgumentError('input_tokens must be non-negative');
    }
    if (inputTokens != null && inputTokens! > _maxTokens) {
      throw ArgumentError('input_tokens exceeds maximum (2,000,000)');
    }
    if (outputTokens != null && outputTokens! < 0) {
      throw ArgumentError('output_tokens must be non-negative');
    }
    if (outputTokens != null && outputTokens! > _maxTokens) {
      throw ArgumentError('output_tokens exceeds maximum (2,000,000)');
    }
  }
}
