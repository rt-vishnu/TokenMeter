import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _periodIndex = 0;

  static const _periods = [
    ('Today', Duration(days: 1)),
    ('This Week', Duration(days: 7)),
    ('This Month', Duration(days: 30)),
  ];

  @override
  Widget build(BuildContext context) {
    final period = _periods[_periodIndex].$2;
    final recordsAsync = ref.watch(usageRecordsProvider);
    final stats = ref.watch(dashboardStatsProvider(period));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<int>(
          segments: [
            for (var i = 0; i < _periods.length; i++)
              ButtonSegment(value: i, label: Text(_periods[i].$1)),
          ],
          selected: {_periodIndex},
          onSelectionChanged: (s) => setState(() => _periodIndex = s.first),
        ),
        const SizedBox(height: 16),
        if (recordsAsync.isLoading && recordsAsync.valueOrNull == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (recordsAsync.hasError)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  Icons.cloud_off,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                title: Text(
                  'Could not reach remote server — retrying…',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                subtitle: Text(
                  'Check the host URL in Settings.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryCards(stats: stats),
              const SizedBox(height: 16),
              if (stats.costByModel.isNotEmpty) ...[
                Text(
                  'Cost by Model',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _ModelChart(costByModel: stats.costByModel),
                const SizedBox(height: 16),
              ],
              if (stats.costBySource.isNotEmpty) ...[
                Text(
                  'Cost by Source',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _SourceBreakdown(costBySource: stats.costBySource),
              ],
              if (stats.recordCount == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No usage recorded yet.\nEnable the API server in Integration to start tracking.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Cost',
            value: Formatters.compactCurrency(stats.totalCost),
            icon: Icons.attach_money,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Total Tokens',
            value: Formatters.tokens(stats.totalTokens),
            icon: Icons.token,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Requests',
            value: '${stats.recordCount}',
            icon: Icons.swap_horiz,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelChart extends StatelessWidget {
  const _ModelChart({required this.costByModel});

  final Map<String, double> costByModel;

  @override
  Widget build(BuildContext context) {
    final entries = costByModel.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      for (var i = 0; i < entries.length; i++)
                        PieChartSectionData(
                          value: entries[i].value,
                          title: total > 0
                              ? '${(entries[i].value / total * 100).toStringAsFixed(0)}%'
                              : '',
                          color: _chartColor(i),
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < entries.length && i < 5; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _chartColor(i),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entries[i].key,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              Formatters.compactCurrency(entries[i].value),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _chartColor(int index) {
    const colors = [
      Color(0xFF2563EB),
      Color(0xFF7C3AED),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFFDC2626),
      Color(0xFF0891B2),
    ];
    return colors[index % colors.length];
  }
}

class _SourceBreakdown extends StatelessWidget {
  const _SourceBreakdown({required this.costBySource});

  final Map<String, double> costBySource;

  @override
  Widget build(BuildContext context) {
    final entries = costBySource.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Column(
        children: [
          for (final entry in entries)
            ListTile(
              leading: const Icon(Icons.terminal),
              title: Text(entry.key),
              trailing: Text(Formatters.compactCurrency(entry.value)),
            ),
        ],
      ),
    );
  }
}
