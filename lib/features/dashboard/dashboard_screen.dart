import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/app_providers_common.dart';
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
    final budget = ref.watch(budgetStatusProvider);
    final trendData = ref.watch(trendDataProvider(period));
    final heatmap = ref.watch(heatmapDataProvider(period));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (recordsAsync.hasError)
          _ErrorBanner(message: 'Could not reach remote server — retrying…'),
        _BudgetAlertBanners(budget: budget),
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
        else if (stats.recordCount == 0)
          _EmptyState(
            periodLabel: _periods[_periodIndex].$1,
            onGoToIntegration: () => context.go('/integration'),
          )
        else ...[
          _SummaryCards(stats: stats),
          const SizedBox(height: 12),
          _BudgetProgressBars(budget: budget),
          const SizedBox(height: 16),
          Text('Cost Trend — ${_periods[_periodIndex].$1}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _TrendChart(points: trendData),
          const SizedBox(height: 16),
          if (stats.costByModel.isNotEmpty) ...[
            Text('Top Models',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _TopModelsTable(stats: stats),
            const SizedBox(height: 16),
          ],
          if (stats.costByModel.isNotEmpty) ...[
            Text('Cost by Model',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _ModelChart(costByModel: stats.costByModel),
            const SizedBox(height: 16),
          ],
          if (stats.costBySource.isNotEmpty) ...[
            Text('Cost by Source',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _SourceBreakdown(costBySource: stats.costBySource),
            const SizedBox(height: 16),
          ],
          Text('Activity Heatmap — ${_periods[_periodIndex].$1}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _ActivityHeatmap(grid: heatmap),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// ── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.cloud_off,
            color: Theme.of(context).colorScheme.onErrorContainer),
        title: Text(message,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer)),
        subtitle: Text('Check the host URL in Settings.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer)),
      ),
    );
  }
}

// ── Budget alert banners ──────────────────────────────────────────────────────

class _BudgetAlertBanners extends StatelessWidget {
  const _BudgetAlertBanners({required this.budget});
  final BudgetStatus budget;

  @override
  Widget build(BuildContext context) {
    final banners = <Widget>[];
    void addBanner(String period, double spend, double? limit, AlertLevel level) {
      if (level == AlertLevel.ok) return;
      final isExceeded = level == AlertLevel.exceeded;
      final color = isExceeded
          ? Theme.of(context).colorScheme.errorContainer
          : const Color(0xFFFFF3CD);
      final textColor = isExceeded
          ? Theme.of(context).colorScheme.onErrorContainer
          : const Color(0xFF664D03);
      banners.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isExceeded ? Icons.warning_rounded : Icons.warning_amber_rounded,
                color: textColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isExceeded
                      ? '$period budget exceeded: ${Formatters.compactCurrency(spend)} / ${Formatters.compactCurrency(limit!)}'
                      : '$period budget at ${(spend / limit! * 100).toStringAsFixed(0)}%: ${Formatters.compactCurrency(spend)} / ${Formatters.compactCurrency(limit)}',
                  style: TextStyle(color: textColor, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    addBanner('Daily', budget.dailySpend, budget.dailyBudget, budget.dailyLevel);
    addBanner('Weekly', budget.weeklySpend, budget.weeklyBudget, budget.weeklyLevel);
    addBanner('Monthly', budget.monthlySpend, budget.monthlyBudget, budget.monthlyLevel);

    if (banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [...banners, const SizedBox(height: 4)],
    );
  }
}

// ── Budget progress bars ──────────────────────────────────────────────────────

class _BudgetProgressBars extends StatelessWidget {
  const _BudgetProgressBars({required this.budget});
  final BudgetStatus budget;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addBar(String label, double spend, double? limit) {
      if (limit == null || limit <= 0) return;
      final ratio = (spend / limit).clamp(0.0, 1.0);
      final Color barColor;
      if (ratio >= 1.0) {
        barColor = Theme.of(context).colorScheme.error;
      } else if (ratio >= 0.8) {
        barColor = Colors.amber.shade700;
      } else {
        barColor = Colors.green.shade600;
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  '${Formatters.compactCurrency(spend)} / ${Formatters.compactCurrency(limit)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        ),
      ));
    }

    addBar('Daily', budget.dailySpend, budget.dailyBudget);
    addBar('Weekly', budget.weeklySpend, budget.weeklyBudget);
    addBar('Monthly', budget.monthlySpend, budget.monthlyBudget);

    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Budget',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            ...rows,
          ],
        ),
      ),
    );
  }
}

// ── Summary cards ─────────────────────────────────────────────────────────────

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

// ── Trend line chart ──────────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});
  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxCost = points.fold(0.0, (m, p) => p.cost > m ? p.cost : m);
    final spots = points
        .map((p) => FlSpot(p.index.toDouble(), p.cost))
        .toList();

    // Show every nth label so they don't overlap
    final labelStep = points.length <= 8
        ? 1
        : points.length <= 16
            ? 2
            : 4;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxCost > 0 ? maxCost * 1.2 : 1.0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.4),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (v, _) => Text(
                      '\$${v.toStringAsFixed(v >= 1 ? 1 : 3)}',
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: labelStep.toDouble(),
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= points.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(points[i].label,
                            style: const TextStyle(fontSize: 9)),
                      );
                    },
                  ),
                ),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: points.length <= 10,
                    getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                      radius: 3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Top models table ──────────────────────────────────────────────────────────

enum _ModelSort { cost, requests, tokens }

class _TopModelsTable extends StatefulWidget {
  const _TopModelsTable({required this.stats});
  final DashboardStats stats;

  @override
  State<_TopModelsTable> createState() => _TopModelsTableState();
}

class _TopModelsTableState extends State<_TopModelsTable> {
  _ModelSort _sort = _ModelSort.cost;
  bool _ascending = false;

  @override
  Widget build(BuildContext context) {
    final models = widget.stats.costByModel.keys.toList();
    models.sort((a, b) {
      int cmp;
      switch (_sort) {
        case _ModelSort.cost:
          cmp = (widget.stats.costByModel[a] ?? 0)
              .compareTo(widget.stats.costByModel[b] ?? 0);
        case _ModelSort.requests:
          cmp = (widget.stats.requestsByModel[a] ?? 0)
              .compareTo(widget.stats.requestsByModel[b] ?? 0);
        case _ModelSort.tokens:
          cmp = (widget.stats.tokensByModel[a] ?? 0)
              .compareTo(widget.stats.tokensByModel[b] ?? 0);
      }
      return _ascending ? cmp : -cmp;
    });

    Widget header(String label, _ModelSort sort) {
      final active = _sort == sort;
      return InkWell(
        onTap: () => setState(() {
          if (_sort == sort) {
            _ascending = !_ascending;
          } else {
            _sort = sort;
            _ascending = false;
          }
        }),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : null,
                )),
            if (active)
              Icon(
                _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Expanded(
                      child: Text('Model',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12))),
                  SizedBox(width: 72, child: header('Cost', _ModelSort.cost)),
                  SizedBox(
                      width: 56, child: header('Reqs', _ModelSort.requests)),
                  SizedBox(
                      width: 72, child: header('Tokens', _ModelSort.tokens)),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final model in models)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(model,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        Formatters.compactCurrency(
                            widget.stats.costByModel[model] ?? 0),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        '${widget.stats.requestsByModel[model] ?? 0}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        Formatters.tokens(widget.stats.tokensByModel[model] ?? 0),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Pie chart ─────────────────────────────────────────────────────────────────

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

// ── Source breakdown ──────────────────────────────────────────────────────────

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

// ── Activity heatmap ──────────────────────────────────────────────────────────

class _ActivityHeatmap extends StatelessWidget {
  const _ActivityHeatmap({required this.grid});
  final List<List<double>> grid;

  static const _shortDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Builds row labels: for a 1-row grid (Today) show "Today";
  /// for multi-row grids use Mon–Sun labels offset to align with today.
  String _rowLabel(int rowIndex, int totalRows) {
    if (totalRows == 1) return 'Today';
    // For 7-day view: row 0 = oldest day, row (totalRows-1) = today.
    // Compute weekday of that row.
    final today = DateTime.now();
    final date = today.subtract(Duration(days: totalRows - 1 - rowIndex));
    return _shortDays[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = grid
        .expand((row) => row)
        .fold(0.0, (m, v) => v > m ? v : m);
    final rows = grid.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hour labels
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Row(
                children: [
                  for (var h = 0; h < 24; h++)
                    Expanded(
                      child: h % 6 == 0
                          ? Text('${h}h',
                              style: const TextStyle(fontSize: 8),
                              textAlign: TextAlign.center)
                          : const SizedBox(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (var d = 0; d < rows; d++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(_rowLabel(d, rows),
                          style: const TextStyle(fontSize: 9)),
                    ),
                    for (var h = 0; h < 24; h++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(1),
                          child: _HeatCell(
                            value: grid[d][h],
                            maxValue: maxVal,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Less', style: TextStyle(fontSize: 9)),
                const SizedBox(width: 4),
                for (var i = 0; i <= 4; i++)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: _heatColor(i / 4, context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                const Text('More', style: TextStyle(fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _heatColor(double intensity, BuildContext context) {
    if (intensity <= 0) {
      return Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.4);
    }
    return Color.lerp(
      const Color(0xFFBBEFC4),
      const Color(0xFF1A7F37),
      intensity,
    )!;
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.value, required this.maxValue});
  final double value;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final intensity = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    return Tooltip(
      message: value > 0 ? Formatters.currency(value) : '',
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: _ActivityHeatmap._heatColor(intensity, context),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onGoToIntegration,
    this.periodLabel,
  });

  final VoidCallback onGoToIntegration;
  final String? periodLabel;

  @override
  Widget build(BuildContext context) {
    final isFiltered = periodLabel != null;
    final title = isFiltered
        ? 'No usage recorded — $periodLabel'
        : 'No usage recorded yet';
    final subtitle = isFiltered
        ? 'No token usage was recorded in this period.\nSwitch period or connect your AI tools.'
        : 'Enable the API server and connect your AI tools\nto start tracking token costs.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 72,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          if (!isFiltered)
            FilledButton.icon(
              onPressed: onGoToIntegration,
              icon: const Icon(Icons.cable),
              label: const Text('Go to Integration'),
            ),
        ],
      ),
    );
  }
}
