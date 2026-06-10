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

@DriftDatabase(tables: [UsageRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

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

  Future<int> countRecords() => (select(usageRecords)).get().then((r) => r.length);

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
    if (source != null && source.isNotEmpty) query.where((t) => t.source.equals(source));
    if (model != null && model.isNotEmpty) query.where((t) => t.model.equals(model));
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'token_meter.sqlite'));
    return NativeDatabase(file);
  });
}
