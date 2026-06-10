import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(usageRecordsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
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

              if (filtered.isEmpty) {
                return const Center(child: Text('No usage records found.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _UsageTile(record: filtered[index]),
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
    return Card(
      child: ListTile(
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
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
