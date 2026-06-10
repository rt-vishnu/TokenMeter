import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/model_pricing.dart';
import '../../core/providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _remoteHostController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsServiceProvider);
    _remoteHostController =
        TextEditingController(text: settings.remoteHostUrl ?? '');
    _portController =
        TextEditingController(text: settings.apiPort.toString());
  }

  @override
  void dispose() {
    _remoteHostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsServiceProvider);
    final isDark = ref.watch(themeModeProvider);
    final customModels = ref
        .watch(pricingRepositoryProvider)
        .sortedModels
        .where((m) => m.isCustom)
        .toList();

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
          TextField(
            controller: _remoteHostController,
            decoration: const InputDecoration(
              labelText: 'Remote API host URL',
              hintText: 'http://192.168.1.42:8765',
            ),
            onSubmitted: (v) => settings.setRemoteHostUrl(v),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () =>
                settings.setRemoteHostUrl(_remoteHostController.text),
            child: const Text('Save remote host'),
          ),
          const SizedBox(height: 16),
        ],
        if (!kIsWeb) ...[
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
              final port = int.tryParse(_portController.text);
              if (port != null && port > 1024) {
                await settings.setApiPort(port);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Port saved')),
                  );
                }
              }
            },
            child: const Text('Save port'),
          ),
          const SizedBox(height: 16),
        ],
        Text('Custom Models', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final model in customModels)
          Card(
            child: ListTile(
              title: Text(model.displayName),
              subtitle: Text(
                'In: \$${model.inputPer1M}/1M · Out: \$${model.outputPer1M}/1M',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ref
                      .read(pricingRepositoryProvider)
                      .deleteCustomModel(model.id);
                  ref.invalidate(pricingRepositoryProvider);
                  setState(() {});
                },
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _showAddModelDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Add custom model'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showImportDialog(context),
          icon: const Icon(Icons.upload_file),
          label: const Text('Import pricing JSON'),
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

  Future<void> _showImportDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import pricing JSON'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '{"my-model": {"input_per_1m": 1.0, ...}}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      try {
        await ref
            .read(pricingRepositoryProvider)
            .importPricingJson(controller.text);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pricing imported')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import failed: $e')),
          );
        }
      }
    }
  }
}
