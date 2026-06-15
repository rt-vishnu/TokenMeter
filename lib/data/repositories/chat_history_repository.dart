class ChatHistoryMessage {
  const ChatHistoryMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.inputTokens,
    this.outputTokens,
    this.costUsd,
    this.model,
    this.interrupted = false,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  // 'user' | 'assistant'
  final String role;
  final String content;
  final int? inputTokens;
  final int? outputTokens;
  final double? costUsd;
  final String? model;
  final bool interrupted;
  final DateTime createdAt;
}

abstract class ChatHistoryRepository {
  Future<String?> getLatestSessionId();
  Future<List<ChatHistoryMessage>> getSessionMessages(String sessionId);
  Future<void> saveMessage(ChatHistoryMessage message);
  Future<void> clearAll();
}
