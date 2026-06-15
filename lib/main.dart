import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers/app_providers.dart';
import 'core/providers/app_providers_common.dart';
import 'core/services/notification_service.dart';
import 'core/services/pricing_repository.dart';
import 'core/services/secure_storage_config.dart';
import 'core/services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final pricing = PricingRepository(prefs);
  await pricing.load();

  // Init settings on the single shared instance so the API key cache is warm
  // before the provider is read anywhere in the widget tree.
  final settings = SettingsService(prefs, appSecureStorage);
  await settings.init();

  final notifications = NotificationService();
  await notifications.init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        pricingRepositoryProvider.overrideWithValue(pricing),
        settingsServiceProvider.overrideWithValue(settings),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const _AppBootstrap(),
    ),
  );
}

class _AppBootstrap extends ConsumerStatefulWidget {
  const _AppBootstrap();

  @override
  ConsumerState<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<_AppBootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(serverStateProvider.notifier).restoreIfEnabled();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(usageRefreshTickProvider.notifier).bump();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fire budget notifications whenever the computed spend/limits change.
    ref.listen<BudgetStatus>(budgetStatusProvider, (_, next) {
      ref.read(budgetAlertServiceProvider).evaluate(next);
    });
    return const PromptPennyApp();
  }
}
