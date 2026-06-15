import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database_io.g.dart';

class UsageRecords extends Table {
  TextColumn get id => text()();
  TextColumn get model => text()();
  IntColumn get inputTokens => integer()();
  IntColumn get outputTokens => integer()();
  RealColumn get costUsd => real()();
  TextColumn get source => text()();
  TextColumn get sessionId => text().nullable()();
  TextColumn get metadata => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  // 'user' | 'assistant' | 'error'
  TextColumn get role => text()();
  TextColumn get content => text()();
  IntColumn get inputTokens => integer().nullable()();
  IntColumn get outputTokens => integer().nullable()();
  RealColumn get costUsd => real().nullable()();
  TextColumn get model => text().nullable()();
  BoolColumn get interrupted =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [UsageRecords, ChatMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(chatMessages);
          }
        },
      );

  // ── UsageRecords ─────────────────────────────────────────────────────────

  Future<void> insertRecord(UsageRecordsCompanion record) =>
      into(usageRecords).insert(record);

  Stream<List<UsageRecord>> watchAllRecords() {
    return (select(usageRecords)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<UsageRecord>> getRecords({
    DateTime? from,
    DateTime? to,
    String? source,
    String? model,
  }) {
    final query = select(usageRecords);
    if (from != null) {
      query.where((t) => t.createdAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where((t) => t.createdAt.isSmallerOrEqualValue(to));
    }
    if (source != null && source.isNotEmpty) {
      query.where((t) => t.source.equals(source));
    }
    if (model != null && model.isNotEmpty) {
      query.where((t) => t.model.equals(model));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Future<double> getTotalCostSince(DateTime since) async {
    final records = await (select(usageRecords)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(since)))
        .get();
    return records.fold<double>(0, (sum, r) => sum + r.costUsd);
  }

  Future<Map<String, double>> getCostByModelSince(DateTime since) async {
    final records = await (select(usageRecords)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(since)))
        .get();
    final result = <String, double>{};
    for (final r in records) {
      result[r.model] = (result[r.model] ?? 0) + r.costUsd;
    }
    return result;
  }

  Future<Map<String, double>> getCostBySourceSince(DateTime since) async {
    final records = await (select(usageRecords)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(since)))
        .get();
    final result = <String, double>{};
    for (final r in records) {
      result[r.source] = (result[r.source] ?? 0) + r.costUsd;
    }
    return result;
  }

  Future<int> countRecords() =>
      (select(usageRecords)).get().then((r) => r.length);

  Future<List<UsageRecord>> getRecordsPaged({
    DateTime? from,
    DateTime? to,
    String? source,
    String? model,
    int limit = 200,
    int offset = 0,
  }) {
    final query = select(usageRecords);
    if (from != null) query.where((t) => t.createdAt.isBiggerOrEqualValue(from));
    if (to != null) query.where((t) => t.createdAt.isSmallerOrEqualValue(to));
    if (source != null && source.isNotEmpty) {
      query.where((t) => t.source.equals(source));
    }
    if (model != null && model.isNotEmpty) {
      query.where((t) => t.model.equals(model));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    query.limit(limit, offset: offset);
    return query.get();
  }

  Future<bool> deleteRecord(String id) async {
    final count = await (delete(usageRecords)
          ..where((t) => t.id.equals(id)))
        .go();
    return count > 0;
  }

  // ── ChatMessages ──────────────────────────────────────────────────────────

  Future<void> insertChatMessage(ChatMessagesCompanion msg) =>
      into(chatMessages).insert(msg);

  /// All messages for a session, oldest first.
  Future<List<ChatMessage>> getSessionMessages(String sessionId) =>
      (select(chatMessages)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// Returns distinct (sessionId, firstCreatedAt) pairs, newest session first.
  /// Used to build the sessions list.
  Future<List<({String sessionId, DateTime startedAt})>>
      getChatSessions() async {
    final rows = await (select(chatMessages)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    // Collect the earliest message time per session while preserving order.
    final seen = <String, DateTime>{};
    for (final r in rows) {
      seen.putIfAbsent(r.sessionId, () => r.createdAt);
    }
    // Sort sessions newest-first by their first message.
    final sessions = seen.entries
        .map((e) => (sessionId: e.key, startedAt: e.value))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  /// Most-recently-started session ID, or null if no chat history.
  Future<String?> getLatestSessionId() async {
    final sessions = await getChatSessions();
    return sessions.isEmpty ? null : sessions.first.sessionId;
  }

  Future<void> deleteSession(String sessionId) =>
      (delete(chatMessages)..where((t) => t.sessionId.equals(sessionId))).go();

  Future<void> clearAllChatHistory() => delete(chatMessages).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'token_meter.sqlite'));
    return NativeDatabase(file);
  });
}
