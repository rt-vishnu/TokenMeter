import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_providers_native.dart'
    if (dart.library.html) 'app_providers_native_stub.dart';
import '../models/usage_payload.dart';
import '../models/usage_record.dart';
import '../services/billing_client.dart';
import '../services/local_api_server.dart';
import '../services/network_service.dart';
import '../services/notification_service.dart';
import '../services/pricing_repository.dart';
import '../services/remote_api_client.dart';
import '../services/settings_service.dart';
import '../utils/formatters.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden');
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(
    ref.watch(sharedPreferencesProvider),
    ref.watch(secureStorageProvider),
  );
});

final pricingRepositoryProvider = Provider<PricingRepository>((ref) {
  throw UnimplementedError('PricingRepository must be initialized');
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('NotificationService must be initialized');
});

/// This calendar month's tracked (estimated) spend grouped by pricing
/// `provider` — used for the Balances "Tracked vs Actual" comparison.
final trackedMonthCostByProviderProvider = Provider<Map<String, double>>((ref) {
  final records = ref.watch(usageRecordsProvider).valueOrNull ?? [];
  final pricing = ref.watch(pricingRepositoryProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);

  final map = <String, double>{};
  for (final r in records) {
    if (r.createdAt.isBefore(startOfMonth)) continue;
    final provider = pricing.getModel(r.model)?.provider ?? 'unknown';
    map[provider] = (map[provider] ?? 0) + r.costUsd;
  }
  return map;
});

/// Pulls actual spend/balance from a provider's billing API. Returns a
/// [ProviderActuals] with a status the UI renders (connected/notConnected/
/// unsupported/error).
///
/// Skip-refetch guard: if a successful fetch is cached and younger than 1 hour,
/// returns the cached value immediately. Clear the cache
/// (`settings.setBillingActualsCacheRaw(id, null)`) before invalidating to
/// force a real network call (e.g. on manual refresh / key change).
final providerActualsProvider =
    FutureProvider.family<ProviderActuals, BillingProvider>((ref, provider) async {
  // Gemini has no public billing API — always unsupported, no key needed.
  if (provider == BillingProvider.gemini) {
    return ProviderActuals.unsupported(provider);
  }

  final settings = ref.watch(settingsServiceProvider);
  final key = settings.billingApiKey(provider.id);
  if (key == null || key.isEmpty) {
    return ProviderActuals.notConnected(provider);
  }

  // Skip-refetch guard: serve cache if it's younger than 1 hour.
  final raw = settings.billingActualsCacheRaw(provider.id);
  if (raw != null) {
    try {
      final cached = ProviderActuals.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
      if (cached.lastSynced != null &&
          DateTime.now().difference(cached.lastSynced!) <
              const Duration(hours: 1)) {
        return cached;
      }
    } catch (_) {
      // Corrupt cache — fall through to a live fetch.
    }
  }

  final actuals = await BillingClient.forProvider(provider, apiKey: key).fetch();

  // Persist successful fetches so the last-known values survive a restart.
  if (actuals.status == BillingStatus.connected) {
    await settings.setBillingActualsCacheRaw(
        provider.id, jsonEncode(actuals.toJson()));
  }

  return actuals;
});

/// Evaluates budget thresholds and fires a local notification once per
/// threshold per period window. Driven by listening to [budgetStatusProvider].
final budgetAlertServiceProvider = Provider<BudgetAlertService>((ref) {
  return BudgetAlertService(ref);
});

class BudgetAlertService {
  BudgetAlertService(this._ref);

  final Ref _ref;

  Future<void> evaluate(BudgetStatus status) async {
    final settings = _ref.read(settingsServiceProvider);
    if (!settings.budgetAlertsEnabled) return;

    final notif = _ref.read(notificationServiceProvider);
    if (!notif.supported) return;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));

    Future<void> check(
      String name,
      int id,
      double spend,
      double? budget,
      AlertLevel level,
      String periodId,
    ) async {
      if (budget == null || budget <= 0 || level == AlertLevel.ok) return;
      final key = '${name}_$periodId';
      if (level.index <= settings.budgetNotifyLevel(key)) return;

      final exceeded = level == AlertLevel.exceeded;
      await notif.show(
        id: id,
        title: exceeded ? '$name budget exceeded 🚨' : '$name budget at 80% ⚠️',
        body: exceeded
            ? 'You\'ve spent ${Formatters.compactCurrency(spend)} of your '
                '${Formatters.compactCurrency(budget)} $name budget.'
            : 'You\'re at ${Formatters.compactCurrency(spend)} of '
                '${Formatters.compactCurrency(budget)} ($name budget).',
      );
      await settings.setBudgetNotifyLevel(key, level.index);
    }

    final dayId = startOfDay.toIso8601String().split('T').first;
    final weekId = startOfWeek.toIso8601String().split('T').first;
    final monthId = '${now.year}-${now.month}';

    await check('Daily', 1, status.dailySpend, status.dailyBudget,
        status.dailyLevel, dayId);
    await check('Weekly', 2, status.weeklySpend, status.weeklyBudget,
        status.weeklyLevel, weekId);
    await check('Monthly', 3, status.monthlySpend, status.monthlyBudget,
        status.monthlyLevel, monthId);
  }
}

final remoteSettingsRevisionProvider = StateProvider<int>((ref) => 0);

final remoteApiClientProvider = Provider<RemoteApiClient?>((ref) {
  ref.watch(remoteSettingsRevisionProvider);
  final settings = ref.watch(settingsServiceProvider);
  final host = settings.remoteHostUrl;
  if (host == null || host.isEmpty) return null;
  final apiKey = settings.remoteApiKey;
  if (apiKey == null || apiKey.isEmpty) return null;
  return RemoteApiClient(
    baseUrl: host,
    apiKey: apiKey,
    pinnedFingerprint: settings.remotePinnedFingerprint,
  );
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
    this.isStopping = false,
    this.host,
    this.port,
    this.requestedPort,
    this.scheme = 'http',
    this.fingerprint,
    this.error,
  });

  final bool isRunning;
  /// True during the graceful drain window after toggling off.
  final bool isStopping;
  final String? host;
  final int? port;
  /// Non-null when the server fell back to a different port.
  final int? requestedPort;
  /// 'https' when serving over TLS, otherwise 'http'.
  final String scheme;
  /// SHA-256 fingerprint of the served cert (HTTPS only), shared via the QR.
  final String? fingerprint;
  final String? error;

  bool get usedFallbackPort =>
      requestedPort != null && requestedPort != port;

  bool get isEncrypted => scheme == 'https';

  String? get endpoint {
    if (host == null || port == null) return null;
    return '$scheme://$host:$port';
  }

  ServerState copyWith({
    bool? isRunning,
    bool? isStopping,
    String? host,
    int? port,
    int? requestedPort,
    String? scheme,
    String? fingerprint,
    String? error,
  }) {
    return ServerState(
      isRunning: isRunning ?? this.isRunning,
      isStopping: isStopping ?? this.isStopping,
      host: host ?? this.host,
      port: port ?? this.port,
      requestedPort: requestedPort ?? this.requestedPort,
      scheme: scheme ?? this.scheme,
      fingerprint: fingerprint ?? this.fingerprint,
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
        state = const ServerState(
          error: 'Could not detect local IP address',
        );
        return;
      }
      final port = settings.apiPort;
      try {
        final boundPort =
            await server.start(ip, port, useHttps: settings.useHttps);
        await settings.setServerEnabled(true);
        state = ServerState(
          isRunning: true,
          host: ip,
          port: boundPort,
          requestedPort: boundPort != port ? port : null,
          scheme: server.scheme,
          fingerprint: server.fingerprint,
        );
      } catch (e) {
        if (LocalApiServer.isPortBindError(e)) {
          state = ServerState(
            error: 'Port $port and the next ${LocalApiServer.portFallbackCount} '
                'ports are all in use. Change the port in Settings.',
          );
        } else {
          state = ServerState(error: 'Failed to start server: $e');
        }
      }
    } else {
      state = state.copyWith(isStopping: true, isRunning: false);
      await server.stop();
      await settings.setServerEnabled(false);
      state = const ServerState();
    }
  }

  Future<void> restoreIfEnabled() async {
    final settings = _ref.read(settingsServiceProvider);
    if (settings.serverEnabled) {
      await toggle(true);
    }
  }

  /// Changes the HTTPS preference, restarting the server if it's running so
  /// the new scheme takes effect immediately.
  Future<void> setHttps(bool useHttps) async {
    final settings = _ref.read(settingsServiceProvider);
    await settings.setUseHttps(useHttps);
    if (state.isRunning) {
      await toggle(false);
      await toggle(true);
    }
  }
}

/// Records usage from inside the app (Chat, Calculator, manual entry),
/// using the local database on native or the remote API on web.
final usageRecorderProvider = Provider<UsageRecorder>((ref) {
  return UsageRecorder(ref);
});

class UsageRecorder {
  UsageRecorder(this._ref);

  final Ref _ref;

  bool get canRecord =>
      _ref.read(usageRepositoryProvider) != null ||
      _ref.read(remoteApiClientProvider) != null;

  /// Returns the saved record, or null if no storage is available
  /// (web build without a remote host configured).
  Future<UsageRecord?> record(UsagePayload payload) async {
    final repo = _ref.read(usageRepositoryProvider);
    if (repo != null) {
      // The repository bumps usageRefreshTickProvider via onUsageRecorded.
      return repo.recordUsage(payload);
    }
    final client = _ref.read(remoteApiClientProvider);
    if (client != null) {
      final saved = await client.postUsage(payload);
      _ref.read(usageRefreshTickProvider.notifier).bump();
      return saved;
    }
    return null;
  }
}

final usageRecordsProvider = StreamProvider<List<UsageRecord>>((ref) {
  ref.watch(usageRefreshTickProvider);
  final usage = ref.watch(usageRepositoryProvider);
  if (usage != null) {
    return usage.watchAll();
  }
  return _pollRemoteUsage(ref);
});

/// Web client polling loop for the remote API. Fetches immediately (no initial
/// delay), then every 3s. Crucially it caches the last successful result and
/// keeps yielding it through transient failures — so a backgrounded/throttled
/// tab or a dropped request doesn't blank the dashboard. Only a failure with no
/// data yet surfaces an error (the "Could not reach remote server" banner).
Stream<List<UsageRecord>> _pollRemoteUsage(Ref ref) async* {
  List<UsageRecord>? last;
  while (true) {
    final client = ref.read(remoteApiClientProvider);
    if (client == null) {
      yield const <UsageRecord>[];
    } else {
      try {
        last = await client.getUsage();
        yield last;
      } catch (_) {
        if (last != null) {
          yield last; // keep the last good data visible
        } else {
          rethrow; // nothing cached → let the UI show the error banner
        }
      }
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
}

/// Calendar-based dashboard periods. "Today" means since midnight,
/// "This Week" since Monday, "This Month" since the 1st — matching the
/// budget tracker and the /api/v1/stats endpoint (not rolling windows).
enum DashboardPeriod { today, week, month }

extension DashboardPeriodLabel on DashboardPeriod {
  String get label => switch (this) {
        DashboardPeriod.today => 'Today',
        DashboardPeriod.week => 'This Week',
        DashboardPeriod.month => 'This Month',
      };
}

/// Returns the calendar start instant for [period] relative to [now].
DateTime periodStart(DashboardPeriod period, DateTime now) {
  final startOfDay = DateTime(now.year, now.month, now.day);
  return switch (period) {
    DashboardPeriod.today => startOfDay,
    DashboardPeriod.week => startOfDay.subtract(Duration(days: now.weekday - 1)),
    DashboardPeriod.month => DateTime(now.year, now.month, 1),
  };
}

DashboardStats computeDashboardStats(
    List<UsageRecord> records, DashboardPeriod period) {
  final since = periodStart(period, DateTime.now());
  final filtered =
      records.where((r) => !r.createdAt.isBefore(since)).toList();

  final byModel = <String, double>{};
  final bySource = <String, double>{};
  final requestsByModel = <String, int>{};
  final tokensByModel = <String, int>{};
  var totalCost = 0.0;
  var totalTokens = 0;

  for (final r in filtered) {
    totalCost += r.costUsd;
    totalTokens += r.totalTokens;
    byModel[r.model] = (byModel[r.model] ?? 0) + r.costUsd;
    bySource[r.source] = (bySource[r.source] ?? 0) + r.costUsd;
    requestsByModel[r.model] = (requestsByModel[r.model] ?? 0) + 1;
    tokensByModel[r.model] = (tokensByModel[r.model] ?? 0) + r.totalTokens;
  }

  return DashboardStats(
    totalCost: totalCost,
    totalTokens: totalTokens,
    recordCount: filtered.length,
    costByModel: byModel,
    costBySource: bySource,
    requestsByModel: requestsByModel,
    tokensByModel: tokensByModel,
  );
}

/// Recomputes whenever [usageRecordsProvider] emits new data.
final dashboardStatsProvider =
    Provider.family<DashboardStats, DashboardPeriod>((ref, period) {
  final recordsAsync = ref.watch(usageRecordsProvider);
  return recordsAsync.when(
    data: (records) => computeDashboardStats(records, period),
    loading: () => const DashboardStats(),
    error: (e, st) => const DashboardStats(),
  );
});

/// Number of consecutive calendar days (ending today, or yesterday if today
/// has no activity yet) that have at least one usage record. Drives the
/// "tracking streak" chip — the day stays alive until midnight.
final trackingStreakProvider = Provider<int>((ref) {
  final records = ref.watch(usageRecordsProvider).valueOrNull ?? [];
  if (records.isEmpty) return 0;

  final days = <DateTime>{
    for (final r in records)
      DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day),
  };

  final now = DateTime.now();
  var cursor = DateTime(now.year, now.month, now.day);
  if (!days.contains(cursor)) {
    // Today has no activity yet — the streak can still be intact via yesterday.
    cursor = cursor.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0;
  }

  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
});

class DashboardStats {
  const DashboardStats({
    this.totalCost = 0,
    this.totalTokens = 0,
    this.recordCount = 0,
    this.costByModel = const {},
    this.costBySource = const {},
    this.requestsByModel = const {},
    this.tokensByModel = const {},
  });

  final double totalCost;
  final int totalTokens;
  final int recordCount;
  final Map<String, double> costByModel;
  final Map<String, double> costBySource;
  final Map<String, int> requestsByModel;
  final Map<String, int> tokensByModel;
}

// ── Budget Controls ──────────────────────────────────────────────────────────

enum AlertLevel { ok, warning, exceeded }

class BudgetStatus {
  const BudgetStatus({
    required this.dailySpend,
    required this.weeklySpend,
    required this.monthlySpend,
    required this.dailyBudget,
    required this.weeklyBudget,
    required this.monthlyBudget,
  });

  final double dailySpend;
  final double weeklySpend;
  final double monthlySpend;
  final double? dailyBudget;
  final double? weeklyBudget;
  final double? monthlyBudget;

  AlertLevel get dailyLevel => _level(dailySpend, dailyBudget);
  AlertLevel get weeklyLevel => _level(weeklySpend, weeklyBudget);
  AlertLevel get monthlyLevel => _level(monthlySpend, monthlyBudget);

  bool get hasAnyAlert =>
      dailyLevel != AlertLevel.ok ||
      weeklyLevel != AlertLevel.ok ||
      monthlyLevel != AlertLevel.ok;

  AlertLevel _level(double spend, double? budget) {
    if (budget == null || budget <= 0) return AlertLevel.ok;
    final ratio = spend / budget;
    if (ratio >= 1.0) return AlertLevel.exceeded;
    if (ratio >= 0.8) return AlertLevel.warning;
    return AlertLevel.ok;
  }
}

final budgetStatusProvider = Provider<BudgetStatus>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  final recordsAsync = ref.watch(usageRecordsProvider);
  final records = recordsAsync.valueOrNull ?? [];

  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
  final startOfMonth = DateTime(now.year, now.month, 1);

  double dailySpend = 0;
  double weeklySpend = 0;
  double monthlySpend = 0;

  for (final r in records) {
    if (!r.createdAt.isBefore(startOfMonth)) monthlySpend += r.costUsd;
    if (!r.createdAt.isBefore(startOfWeek)) weeklySpend += r.costUsd;
    if (!r.createdAt.isBefore(startOfDay)) dailySpend += r.costUsd;
  }

  return BudgetStatus(
    dailySpend: dailySpend,
    weeklySpend: weeklySpend,
    monthlySpend: monthlySpend,
    dailyBudget: settings.dailyBudget,
    weeklyBudget: settings.weeklyBudget,
    monthlyBudget: settings.monthlyBudget,
  );
});

// ── Weekly recap ──────────────────────────────────────────────────────────────

class WeeklyRecap {
  const WeeklyRecap({required this.thisWeek, required this.lastWeek});

  final double thisWeek;
  final double lastWeek;

  bool get hasComparison => lastWeek > 0;

  /// Signed percent change vs last week (negative = spending went down).
  double? get percentChange =>
      lastWeek > 0 ? (thisWeek - lastWeek) / lastWeek * 100 : null;

  bool get isDown => (percentChange ?? 0) < 0;
}

/// This calendar week's spend (since Monday) vs the previous week's.
final weeklyRecapProvider = Provider<WeeklyRecap>((ref) {
  final records = ref.watch(usageRecordsProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
  final startOfLastWeek = startOfWeek.subtract(const Duration(days: 7));

  double thisWeek = 0;
  double lastWeek = 0;
  for (final r in records) {
    if (!r.createdAt.isBefore(startOfWeek)) {
      thisWeek += r.costUsd;
    } else if (!r.createdAt.isBefore(startOfLastWeek)) {
      lastWeek += r.costUsd;
    }
  }
  return WeeklyRecap(thisWeek: thisWeek, lastWeek: lastWeek);
});

// ── Analytics: daily trend ───────────────────────────────────────────────────

class TrendPoint {
  const TrendPoint({required this.label, required this.cost, required this.index});
  final String label;
  final double cost;
  final int index;
}

final trendDataProvider =
    Provider.family<List<TrendPoint>, DashboardPeriod>((ref, period) {
  final recordsAsync = ref.watch(usageRecordsProvider);
  final records = recordsAsync.valueOrNull ?? [];
  final now = DateTime.now();

  if (period == DashboardPeriod.today) {
    // Hourly buckets for Today (0–23)
    final buckets = List.filled(24, 0.0);
    final start = periodStart(period, now);
    for (final r in records) {
      if (!r.createdAt.isBefore(start)) {
        buckets[r.createdAt.hour] += r.costUsd;
      }
    }
    return List.generate(
      24,
      (i) => TrendPoint(label: '${i.toString().padLeft(2, '0')}h', cost: buckets[i], index: i),
    );
  }

  // Daily buckets from the calendar start (Monday / 1st) through today.
  final start = periodStart(period, now);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(start).inDays + 1;
  final buckets = List.filled(days, 0.0);
  for (final r in records) {
    if (!r.createdAt.isBefore(start)) {
      final dayIndex = r.createdAt.difference(start).inDays.clamp(0, days - 1);
      buckets[dayIndex] += r.costUsd;
    }
  }
  return List.generate(days, (i) {
    final d = start.add(Duration(days: i));
    return TrendPoint(label: '${d.month}/${d.day}', cost: buckets[i], index: i);
  });
});

// ── Analytics: heatmap ───────────────────────────────────────────────────────

/// Returns a grid [day][hour 0..23] = total cost for the given [period].
/// Today: 1×24 (single row). Week/Month: one row per calendar day so far.
final heatmapDataProvider =
    Provider.family<List<List<double>>, DashboardPeriod>((ref, period) {
  final recordsAsync = ref.watch(usageRecordsProvider);
  final records = recordsAsync.valueOrNull ?? [];
  final now = DateTime.now();

  if (period == DashboardPeriod.today) {
    final buckets = [List.filled(24, 0.0)];
    final start = periodStart(period, now);
    for (final r in records) {
      if (!r.createdAt.isBefore(start)) {
        buckets[0][r.createdAt.hour] += r.costUsd;
      }
    }
    return buckets;
  }

  final start = periodStart(period, now);
  final today = DateTime(now.year, now.month, now.day);
  final days = (today.difference(start).inDays + 1).clamp(1, 31);
  final grid = List.generate(days, (_) => List.filled(24, 0.0));
  for (final r in records) {
    if (!r.createdAt.isBefore(start)) {
      final dayIndex = r.createdAt.difference(start).inDays.clamp(0, days - 1);
      grid[dayIndex][r.createdAt.hour] += r.costUsd;
    }
  }
  return grid;
});

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
