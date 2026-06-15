import 'chat_history_repository.dart';

class ChatHistoryRepositoryStub implements ChatHistoryRepository {
  @override
  Future<String?> getLatestSessionId() async => null;

  @override
  Future<List<ChatHistoryMessage>> getSessionMessages(String sessionId) async =>
      [];

  @override
  Future<void> saveMessage(ChatHistoryMessage message) async {}

  @override
  Future<void> clearAll() async {}
}
