class UsageRecord {
  const UsageRecord({
    required this.id,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.costUsd,
    required this.source,
    required this.createdAt,
    this.sessionId,
    this.metadata = const {},
  });

  final String id;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final double costUsd;
  final String source;
  final String? sessionId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  int get totalTokens => inputTokens + outputTokens;

  factory UsageRecord.fromJson(Map<String, dynamic> json) {
    return UsageRecord(
      id: json['id'] as String,
      model: json['model'] as String,
      inputTokens: json['input_tokens'] as int,
      outputTokens: json['output_tokens'] as int,
      costUsd: (json['cost_usd'] as num).toDouble(),
      source: json['source'] as String? ?? 'unknown',
      sessionId: json['session_id'] as String?,
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map? ?? {},
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'model': model,
        'input_tokens': inputTokens,
        'output_tokens': outputTokens,
        'cost_usd': costUsd,
        'source': source,
        if (sessionId != null) 'session_id': sessionId,
        'metadata': metadata,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
