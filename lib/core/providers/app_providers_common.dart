import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_providers_native.dart'
    if (dart.library.html) 'app_providers_native_stub.dart';
import '../models/usage_record.dart';
import '../services/network_service.dart';
import '../services/pricing_repository.dart';
import '../services/remote_api_client.dart';
import '../services/settings_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden');
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.watch(sharedPreferencesProvider));
});

final pricingRepositoryProvider = Provider<PricingRepository>((ref) {
  throw UnimplementedError('PricingRepository must be initialized');
});

final remoteApiClientProvider = Provider<RemoteApiClient?>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  final host = settings.remoteHostUrl;
  if (host == null || host.isEmpty) return null;
  return RemoteApiClient(baseUrl: host, apiKey: settings.apiKey);
});

final networkServiceProvider = Provider<NetworkService>((ref) {
  return NetworkService();
});

/// Bumped when usage is recorded via API so UI streams refresh immediately.
final usageRefreshTickProvider =
    StateNotifierProvider<UsageRefreshTick, int>((ref) {
  return UsageRefreshTick();
});

class UsageRefreshTick extends StateNotifier<int> {
  UsageRefreshTick() : super(0);

  void bump() => state++;
}

final serverStateProvider =
    StateNotifierProvider<ServerStateNotifier, ServerState>((ref) {
  return ServerStateNotifier(ref);
});

class ServerState {
  const ServerState({
    this.isRunning = false,
    this.host,
    this.port,
    this.error,
  });

  final bool isRunning;
  final String? host;
  final int? port;
  final String? error;

  String? get endpoint {
    if (host == null || port == null) return null;
    return 'http://$host:$port';
  }

  ServerState copyWith({
    bool? isRunning,
    String? host,
    int? port,
    String? error,
  }) {
    return ServerState(
      isRunning: isRunning ?? this.isRunning,
      host: host ?? this.host,
      port: port ?? this.port,
      error: error,
    );
  }
}

class ServerStateNotifier extends StateNotifier<ServerState> {
  ServerStateNotifier(this._ref) : super(const ServerState());

  final Ref _ref;

  Future<void> toggle(bool enabled) async {
    final settings = _ref.read(settingsServiceProvider);
    final server = _ref.read(localApiServerProvider);
    final network = _ref.read(networkServiceProvider);

    if (server == null) return;

    if (enabled) {
      final ip = await network.getLocalIp();
      if (ip == null) {
        state = state.copyWith(
          isRunning: false,
          error: 'Could not detect local IP address',
        );
        return;
      }
      final port = settings.apiPort;
      try {
        await server.start(ip, port);
        await settings.setServerEnabled(true);
        state = ServerState(isRunning: true, host: ip, port: port);
      } catch (e) {
        state = state.copyWith(
          isRunning: false,
          error: 'Failed to start server: $e',
        );
      }
    } else {
      await server.stop();
      await settings.setServerEnabled(false);
      state = const ServerState(isRunning: false);
    }
  }

  Future<void> restoreIfEnabled() async {
    final settings = _ref.read(settingsServiceProvider);
    if (settings.serverEnabled) {
      await toggle(true);
    }
  }
}

final usageRecordsProvider = StreamProvider<List<UsageRecord>>((ref) {
  ref.watch(usageRefreshTickProvider);
  final usage = ref.watch(usageRepositoryProvider);
  if (usage != null) {
    return usage.watchAll();
  }

  return Stream.periodic(const Duration(seconds: 3)).asyncMap((_) async {
    final client = ref.read(remoteApiClientProvider);
    if (client == null) return <UsageRecord>[];
    return client.getUsage();
  });
});

DashboardStats computeDashboardStats(List<UsageRecord> records, Duration period) {
  final since = DateTime.now().subtract(period);
  final filtered =
      records.where((r) => !r.createdAt.isBefore(since)).toList();

  final byModel = <String, double>{};
  final bySource = <String, double>{};
  var totalCost = 0.0;
  var totalTokens = 0;

  for (final r in filtered) {
    totalCost += r.costUsd;
    totalTokens += r.totalTokens;
    byModel[r.model] = (byModel[r.model] ?? 0) + r.costUsd;
    bySource[r.source] = (bySource[r.source] ?? 0) + r.costUsd;
  }

  return DashboardStats(
    totalCost: totalCost,
    totalTokens: totalTokens,
    recordCount: filtered.length,
    costByModel: byModel,
    costBySource: bySource,
  );
}

/// Recomputes whenever [usageRecordsProvider] emits new data.
final dashboardStatsProvider =
    Provider.family<DashboardStats, Duration>((ref, period) {
  final recordsAsync = ref.watch(usageRecordsProvider);
  return recordsAsync.when(
    data: (records) => computeDashboardStats(records, period),
    loading: () => const DashboardStats(),
    error: (_, __) => const DashboardStats(),
  );
});

class DashboardStats {
  const DashboardStats({
    this.totalCost = 0,
    this.totalTokens = 0,
    this.recordCount = 0,
    this.costByModel = const {},
    this.costBySource = const {},
  });

  final double totalCost;
  final int totalTokens;
  final int recordCount;
  final Map<String, double> costByModel;
  final Map<String, double> costBySource;
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, bool>((ref) {
  return ThemeModeNotifier(ref.watch(settingsServiceProvider));
});

class ThemeModeNotifier extends StateNotifier<bool> {
  ThemeModeNotifier(this._settings) : super(_settings.darkMode);

  final SettingsService _settings;

  Future<void> toggle(bool dark) async {
    state = dark;
    await _settings.setDarkMode(dark);
  }
}
