import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/model_pricing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/app_providers_common.dart';
import '../../core/services/pricing_repository.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/pairing.dart';
import '../integration/qr_scan_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _remoteHostController;
  late final TextEditingController _remoteApiKeyController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsServiceProvider);
    _remoteHostController =
        TextEditingController(text: settings.remoteHostUrl ?? '');
    _remoteApiKeyController =
        TextEditingController(text: settings.remoteApiKey ?? '');
    _portController =
        TextEditingController(text: settings.apiPort.toString());
  }

  @override
  void dispose() {
    _remoteHostController.dispose();
    _remoteApiKeyController.dispose();
    _portController.dispose();
    super.dispose();
  }

  /// Persists a parsed pairing (host + key + cert pin), reflecting the cleaned
  /// values back into the fields. [typedKey] takes precedence over a key
  /// embedded in the pairing URL (so a manually entered key isn't overwritten).
  Future<void> _applyPairing(PairingInfo pairing, String typedKey) async {
    final settings = ref.read(settingsServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final key = typedKey.isNotEmpty ? typedKey : (pairing.apiKey ?? '');

    await settings.setRemoteHostUrl(pairing.host);
    await settings.setRemoteApiKey(key);
    await settings.setRemotePinnedFingerprint(pairing.fingerprint);
    ref.read(remoteSettingsRevisionProvider.notifier).state++;
    ref.read(usageRefreshTickProvider.notifier).bump();

    _remoteHostController.text = pairing.host;
    _remoteApiKeyController.text = key;
    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(
      SnackBar(
        content: Text(pairing.fingerprint != null
            ? 'Remote connection saved (certificate pinned)'
            : 'Remote connection saved'),
      ),
    );
  }

  // Accepts either a bare host URL or the full pairing URL from the QR
  // (e.g. https://192.168.1.42:8765?key=…&fp=…) and splits out key + pin.
  Future<void> _saveRemoteConnection() => _applyPairing(
        PairingInfo.parse(_remoteHostController.text),
        _remoteApiKeyController.text.trim(),
      );

  Future<void> _scanToPair() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (result == null || !mounted) return;
    await _applyPairing(PairingInfo.parse(result), '');
  }

  /// mobile_scanner has a camera implementation on web, mobile, and macOS —
  /// but not Windows/Linux, where we keep the paste-URL fallback only.
  bool get _scannerSupported {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsServiceProvider);
    final isDark = ref.watch(themeModeProvider);
    final pricing = ref.watch(pricingRepositoryProvider);
    final customModels = pricing.sortedModels.where((m) => m.isCustom).toList();
    final lastUpdated = pricing.lastUpdated;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('Dark mode'),
            value: isDark,
            onChanged: (v) => ref.read(themeModeProvider.notifier).toggle(v),
          ),
        ),
        const SizedBox(height: 8),
        if (kIsWeb) ...[
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Copy the endpoint URL and API key from Integration on your '
                'phone (with API server enabled). Both are required. Tip: paste '
                'the full pairing URL from the QR into the host field and the '
                'key and certificate pin fill in automatically.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _remoteHostController,
            decoration: const InputDecoration(
              labelText: 'Remote API host URL',
              hintText: 'http://192.168.1.42:8765',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _remoteApiKeyController,
            decoration: const InputDecoration(
              labelText: 'Remote API key',
              hintText: 'Paste key from phone Integration screen',
            ),
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _saveRemoteConnection,
                  child: const Text('Save remote connection'),
                ),
              ),
              if (_scannerSupported) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _scanToPair,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (!kIsWeb) ...[
          Card(
            child: SwitchListTile(
              title: const Text('Use HTTPS (recommended)'),
              subtitle: const Text(
                'Encrypts API traffic with a self-signed certificate. '
                'Restarts the server if it is running.',
              ),
              value: settings.useHttps,
              onChanged: (v) async {
                await ref.read(serverStateProvider.notifier).setHttps(v);
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: 'API port',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final port = int.tryParse(_portController.text);
              if (port == null || port <= 1024 || port > 65535) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Port must be between 1025 and 65535'),
                  ),
                );
                return;
              }
              await settings.setApiPort(port);
              messenger.showSnackBar(
                const SnackBar(content: Text('Port saved')),
              );
            },
            child: const Text('Save port'),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'Custom Models',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        if (lastUpdated != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Text(
              'Bundled prices last updated: ${DateFormat.yMMMd().format(lastUpdated)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          const SizedBox(height: 8),
        for (final model in customModels)
          _CustomModelTile(
            model: model,
            bundledModel: pricing.getBundledModel(model.id),
            onDelete: () async {
              await ref
                  .read(pricingRepositoryProvider)
                  .deleteCustomModel(model.id);
              ref.invalidate(pricingRepositoryProvider);
              setState(() {});
            },
          ),
        OutlinedButton.icon(
          onPressed: () => _showAddModelDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Add custom model'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showImportDialog(context),
                icon: const Icon(Icons.upload_file),
                label: const Text('Import pricing JSON'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: customModels.isEmpty
                    ? null
                    : () => _exportCustomModels(context),
                icon: const Icon(Icons.download),
                label: const Text('Export custom models'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _BudgetControlsCard(settings: settings),
        const SizedBox(height: 16),
        Text('Privacy', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Clear chat history'),
            subtitle: const Text('Deletes all saved conversations from this device'),
            trailing: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _clearChatHistory(context),
              child: const Text('Clear'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('About', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            title: const Text(AppConstants.appName),
            subtitle: Text('Version ${AppConstants.appVersion}'),
          ),
        ),
      ],
    );
  }

  void _exportCustomModels(BuildContext context) {
    final json = ref.read(pricingRepositoryProvider).exportCustomModels();
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custom models JSON copied to clipboard'),
      ),
    );
  }

  Future<void> _showAddModelDialog(BuildContext context) async {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final inputController = TextEditingController();
    final outputController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add custom model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: 'Model ID'),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            TextField(
              controller: inputController,
              decoration: const InputDecoration(
                labelText: 'Input price per 1M tokens (USD)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: outputController,
              decoration: const InputDecoration(
                labelText: 'Output price per 1M tokens (USD)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && idController.text.isNotEmpty) {
      final model = ModelPricing(
        id: idController.text.trim(),
        provider: 'custom',
        displayName: nameController.text.trim().isEmpty
            ? idController.text.trim()
            : nameController.text.trim(),
        inputPer1M: double.tryParse(inputController.text) ?? 1.0,
        outputPer1M: double.tryParse(outputController.text) ?? 1.0,
        isCustom: true,
      );
      await ref.read(pricingRepositoryProvider).saveCustomModel(model);
      if (mounted) setState(() {});
    }
  }

  Future<void> _clearChatHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: const Text(
          'All saved conversations will be permanently deleted from this device. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final db = ref.read(appDatabaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    await db?.clearAllChatHistory();
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Chat history cleared')),
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final controller = TextEditingController();
    // Capture before first await so the reference is safe across async gaps.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import pricing JSON'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '{"my-model": {"display_name": "My Model", "input_per_1m": 1.0, "output_per_1m": 2.0}}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (result != true || controller.text.trim().isEmpty) return;

    ImportResult importResult;
    try {
      importResult = await ref
          .read(pricingRepositoryProvider)
          .importPricingJson(controller.text);
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Import failed: ${e.message}')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {});

    // Show a detailed result dialog when there were skipped models.
    if (importResult.hasSkipped) {
      await showDialog<void>(
        context: navigator.context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(importResult.summary),
              if (importResult.skippedReasons.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Skipped models:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                for (final entry in importResult.skippedReasons.entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• ${entry.key}: ${entry.value}'),
                  ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(importResult.summary)),
      );
    }
  }
}

class _CustomModelTile extends StatelessWidget {
  const _CustomModelTile({
    required this.model,
    required this.bundledModel,
    required this.onDelete,
  });

  final ModelPricing model;
  final ModelPricing? bundledModel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          title: Text(model.displayName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'In: \$${model.inputPer1M}/1M · Out: \$${model.outputPer1M}/1M',
              ),
              if (bundledModel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _DivergenceChip(
                    custom: model,
                    bundled: bundledModel!,
                  ),
                ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
          isThreeLine: bundledModel != null,
        ),
      ),
    );
  }
}

class _DivergenceChip extends StatelessWidget {
  const _DivergenceChip({required this.custom, required this.bundled});

  final ModelPricing custom;
  final ModelPricing bundled;

  String _pctDiff(double customVal, double bundledVal) {
    if (bundledVal == 0) return '';
    final diff = ((customVal - bundledVal) / bundledVal * 100).round();
    return diff >= 0 ? '+$diff%' : '$diff%';
  }

  @override
  Widget build(BuildContext context) {
    final inputDiff = _pctDiff(custom.inputPer1M, bundled.inputPer1M);
    final outputDiff = _pctDiff(custom.outputPer1M, bundled.outputPer1M);

    return Wrap(
      spacing: 4,
      children: [
        _chip(
          context,
          'Bundled in: \$${bundled.inputPer1M} · yours: \$${custom.inputPer1M} ($inputDiff)',
        ),
        _chip(
          context,
          'Bundled out: \$${bundled.outputPer1M} · yours: \$${custom.outputPer1M} ($outputDiff)',
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      backgroundColor:
          Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.6),
    );
  }
}

class _BudgetControlsCard extends ConsumerStatefulWidget {
  const _BudgetControlsCard({required this.settings});
  final SettingsService settings;

  @override
  ConsumerState<_BudgetControlsCard> createState() =>
      _BudgetControlsCardState();
}

class _BudgetControlsCardState extends ConsumerState<_BudgetControlsCard> {
  late final TextEditingController _dailyCtrl;
  late final TextEditingController _weeklyCtrl;
  late final TextEditingController _monthlyCtrl;
  late bool _alertsEnabled;

  @override
  void initState() {
    super.initState();
    _dailyCtrl = TextEditingController(
        text: widget.settings.dailyBudget?.toStringAsFixed(2) ?? '');
    _weeklyCtrl = TextEditingController(
        text: widget.settings.weeklyBudget?.toStringAsFixed(2) ?? '');
    _monthlyCtrl = TextEditingController(
        text: widget.settings.monthlyBudget?.toStringAsFixed(2) ?? '');
    _alertsEnabled = widget.settings.budgetAlertsEnabled;
  }

  Future<void> _toggleAlerts(bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final notif = ref.read(notificationServiceProvider);
    if (value) {
      final granted = await notif.requestPermissions();
      if (!granted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission denied. Enable it in system '
              'settings to receive budget alerts.',
            ),
          ),
        );
        return; // leave the toggle off
      }
    }
    await widget.settings.setBudgetAlertsEnabled(value);
    if (mounted) setState(() => _alertsEnabled = value);
  }

  @override
  void dispose() {
    _dailyCtrl.dispose();
    _weeklyCtrl.dispose();
    _monthlyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(
    BuildContext context,
    String raw,
    Future<void> Function(double?) setter,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (raw.trim().isEmpty) {
      await setter(null);
      _refreshBudgetDependents();
      messenger.showSnackBar(const SnackBar(content: Text('Budget cleared')));
      return;
    }
    final value = double.tryParse(raw.trim());
    if (value == null || value <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a positive number or leave blank to clear')),
      );
      return;
    }
    await setter(value);
    _refreshBudgetDependents();
    messenger.showSnackBar(const SnackBar(content: Text('Budget saved')));
  }

  /// Budgets live in the [SettingsService] singleton, which Riverpod can't
  /// observe for mutations — so nudge the providers that read them to recompute
  /// with the new values without needing an app restart.
  void _refreshBudgetDependents() {
    ref.invalidate(budgetStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Budget Controls',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Set spending limits. A warning appears at 80%, an alert at 100%.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            _BudgetField(
              label: 'Daily budget (USD)',
              controller: _dailyCtrl,
              onSave: (v) =>
                  _save(context, v, widget.settings.setDailyBudget),
            ),
            const SizedBox(height: 8),
            _BudgetField(
              label: 'Weekly budget (USD)',
              controller: _weeklyCtrl,
              onSave: (v) =>
                  _save(context, v, widget.settings.setWeeklyBudget),
            ),
            const SizedBox(height: 8),
            _BudgetField(
              label: 'Monthly budget (USD)',
              controller: _monthlyCtrl,
              onSave: (v) =>
                  _save(context, v, widget.settings.setMonthlyBudget),
            ),
            const Divider(height: 28),
            if (ref.read(notificationServiceProvider).supported)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Budget alert notifications'),
                subtitle: const Text(
                    'Get notified at 80% and 100% of a budget.'),
                value: _alertsEnabled,
                onChanged: _toggleAlerts,
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('Budget alert notifications'),
                subtitle: const Text('Available on Android & iOS.'),
                enabled: false,
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetField extends StatelessWidget {
  const _BudgetField({
    required this.label,
    required this.controller,
    required this.onSave,
  });

  final String label;
  final TextEditingController controller;
  final void Function(String) onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'e.g. 5.00',
              isDense: true,
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        controller.clear();
                        onSave('');
                      },
                    )
                  : null,
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => onSave(controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
