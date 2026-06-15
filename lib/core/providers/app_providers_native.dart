import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database_io.dart';
import '../../data/repositories/chat_history_repository.dart';
import '../../data/repositories/chat_history_repository_io.dart';
import '../../data/repositories/usage_repository_base.dart';
import '../../data/repositories/usage_repository_io.dart';
import '../services/local_api_server_io.dart';
import 'app_providers_common.dart';

final appDatabaseProvider = Provider<AppDatabase?>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final usageRepositoryProvider = Provider<UsageRepositoryBase?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  if (db == null) return null;
  return UsageRepository(
    database: db,
    pricingRepository: ref.watch(pricingRepositoryProvider),
    onUsageRecorded: () {
      ref.read(usageRefreshTickProvider.notifier).bump();
    },
  );
});

final chatHistoryRepositoryProvider = Provider<ChatHistoryRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ChatHistoryRepositoryIo(db!);
});

final localApiServerProvider = Provider<LocalApiServer?>((ref) {
  final usage = ref.watch(usageRepositoryProvider);
  if (usage is! UsageRepository) return null;
  return LocalApiServer(
    usageRepository: usage,
    pricingRepository: ref.watch(pricingRepositoryProvider),
    settingsService: ref.watch(settingsServiceProvider),
  );
});
