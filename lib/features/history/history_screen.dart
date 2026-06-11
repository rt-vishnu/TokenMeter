import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/models/usage_payload.dart';
import '../../core/models/usage_record.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _sourceFilter = '';
  String _modelFilter = '';
  List<UsageRecord> _filtered = [];

  String _buildCsv(List<UsageRecord> records) {
    final buf = StringBuffer();
    buf.writeln('id,model,source,input_tokens,output_tokens,cost_usd,created_at');
    for (final r in records) {
      buf.writeln(
        '${_csvField(r.id)},'
        '${_csvField(r.model)},'
        '${_csvField(r.source)},'
        '${r.inputTokens},'
        '${r.outputTokens},'
        '${r.costUsd},'
        '${r.createdAt.toUtc().toIso8601String()}',
      );
    }
    return buf.toString();
  }

  String _csvField(String v) =>
      v.contains(',') || v.contains('"') || v.contains('\n')
          ? '"${v.replaceAll('"', '""')}"'
          : v;

  Future<void> _exportCsv(BuildContext context, List<UsageRecord> records) async {
    final csv = _buildCsv(records);
    final messenger = ScaffoldMessenger.of(context);

    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: csv));
      messenger.showSnackBar(
        SnackBar(content: Text('${records.length} records copied to clipboard as CSV')),
      );
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${dir.path}/tokenmeter_export_$ts.csv');
      await file.writeAsString(csv);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Exported ${records.length} records'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFile.open(file.path),
          ),
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: csv));
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${records.length} records copied to clipboard as CSV')),
      );
    }
  }

  Future<void> _showAddRecordDialog(BuildContext context) async {
    final pricing = ref.read(pricingRepositoryProvider);
    final models = pricing.sortedModels;
    if (models.isEmpty) return;

    String selectedModel = models.first.id;
    final inputCtrl = TextEditingController();
    final outputCtrl = TextEditingController();
    final sourceCtrl = TextEditingController(text: 'manual');
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add usage record'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedModel,
                decoration: const InputDecoration(labelText: 'Model'),
                items: [
                  for (final m in models)
                    DropdownMenuItem(value: m.id, child: Text(m.displayName)),
                ],
                onChanged: (v) {
                  if (v != null) selectedModel = v;
                },
              ),
              TextField(
                controller: inputCtrl,
                decoration: const InputDecoration(labelText: 'Input tokens'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              TextField(
                controller: outputCtrl,
                decoration: const InputDecoration(labelText: 'Output tokens'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              TextField(
                controller: sourceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  hintText: 'e.g. chatgpt-web, manual',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final input = int.tryParse(inputCtrl.text);
    final output = int.tryParse(outputCtrl.text);
    if (input == null || output == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter both token counts.')),
      );
      return;
    }

    final recorder = ref.read(usageRecorderProvider);
    if (!recorder.canRecord) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No storage available — configure a remote host in Settings.',
          ),
        ),
      );
      return;
    }

    try {
      final source = sourceCtrl.text.trim().isEmpty
          ? 'manual'
          : sourceCtrl.text.trim();
      final saved = await recorder.record(
        UsagePayload(
          model: selectedModel,
          inputTokens: input,
          outputTokens: output,
          source: source,
        ),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saved != null
                ? 'Record added — ${Formatters.currency(saved.costUsd)}'
                : 'Could not add the record.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not add: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(usageRecordsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Filter by source',
                    hintText: 'cursor, vscode...',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _sourceFilter = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Filter by model',
                    hintText: 'gpt-4o...',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _modelFilter = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add record manually',
                onPressed: () => _showAddRecordDialog(context),
              ),
              IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Export as CSV',
                onPressed: _filtered.isEmpty
                    ? null
                    : () => _exportCsv(context, _filtered),
              ),
            ],
          ),
        ),
        Expanded(
          child: recordsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (records) {
              final filtered = records.where((r) {
                if (_sourceFilter.isNotEmpty &&
                    !r.source.toLowerCase().contains(_sourceFilter)) {
                  return false;
                }
                if (_modelFilter.isNotEmpty &&
                    !r.model.toLowerCase().contains(_modelFilter)) {
                  return false;
                }
                return true;
              }).toList();

              // Keep a reference so the export button can act on it.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _filtered = filtered);
              });

              if (filtered.isEmpty) {
                return const Center(child: Text('No usage records found.'));
              }

              final totalCost =
                  filtered.fold<double>(0.0, (sum, r) => sum + r.costUsd);

              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _UsageTile(record: filtered[index]),
                    ),
                  ),
                  Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Text(
                          '${filtered.length} record${filtered.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        Text(
                          'Total: ${Formatters.currency(totalCost)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UsageTile extends StatelessWidget {
  const _UsageTile({required this.record});

  final UsageRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        title: Text(record.model),
        subtitle: Text(
          '${record.source} · ${Formatters.dateTime(record.createdAt)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Formatters.currency(record.costUsd),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${Formatters.tokens(record.totalTokens)} tokens',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _DetailChip(
                  label: 'Input',
                  value: '${Formatters.tokens(record.inputTokens)} tokens',
                ),
                const SizedBox(width: 8),
                _DetailChip(
                  label: 'Output',
                  value: '${Formatters.tokens(record.outputTokens)} tokens',
                ),
                if (record.sessionId != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: _DetailChip(
                      label: 'Session',
                      value: record.sessionId!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
