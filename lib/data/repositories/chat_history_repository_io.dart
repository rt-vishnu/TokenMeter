import 'package:drift/drift.dart' show Value;

import '../database/app_database_io.dart';
import 'chat_history_repository.dart';

class ChatHistoryRepositoryIo implements ChatHistoryRepository {
  const ChatHistoryRepositoryIo(this._db);
  final AppDatabase _db;

  @override
  Future<String?> getLatestSessionId() => _db.getLatestSessionId();

  @override
  Future<List<ChatHistoryMessage>> getSessionMessages(String sessionId) async {
    final rows = await _db.getSessionMessages(sessionId);
    return rows
        .map((r) => ChatHistoryMessage(
              id: r.id,
              sessionId: r.sessionId,
              role: r.role,
              content: r.content,
              inputTokens: r.inputTokens,
              outputTokens: r.outputTokens,
              costUsd: r.costUsd,
              model: r.model,
              interrupted: r.interrupted,
              createdAt: r.createdAt,
            ))
        .toList();
  }

  @override
  Future<void> saveMessage(ChatHistoryMessage msg) =>
      _db.insertChatMessage(ChatMessagesCompanion(
        id: Value(msg.id),
        sessionId: Value(msg.sessionId),
        role: Value(msg.role),
        content: Value(msg.content),
        inputTokens: Value(msg.inputTokens),
        outputTokens: Value(msg.outputTokens),
        costUsd: Value(msg.costUsd),
        model: Value(msg.model),
        interrupted: Value(msg.interrupted),
        createdAt: Value(msg.createdAt),
      ));

  @override
  Future<void> clearAll() => _db.clearAllChatHistory();
}
