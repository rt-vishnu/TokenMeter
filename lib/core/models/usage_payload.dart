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

  factory UsagePayload.fromJson(Map<String, dynamic> json) {
    return UsagePayload(
      model: json['model'] as String,
      inputTokens: json['input_tokens'] as int,
      outputTokens: json['output_tokens'] as int,
      source: json['source'] as String? ?? 'unknown',
      sessionId: json['session_id'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map? ?? {},
      ),
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

  factory EstimatePayload.fromJson(Map<String, dynamic> json) {
    return EstimatePayload(
      model: json['model'] as String,
      inputTokens: json['input_tokens'] as int?,
      outputTokens: json['output_tokens'] as int?,
      promptText: json['prompt_text'] as String?,
      completionText: json['completion_text'] as String?,
    );
  }
}
