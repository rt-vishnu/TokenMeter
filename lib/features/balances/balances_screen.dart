import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/billing_client.dart';
import '../../core/utils/formatters.dart';

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class BalancesScreen extends ConsumerWidget {
  const BalancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balances')),
      body: kIsWeb
          ? const _WebUnavailable()
          : RefreshIndicator(
              onRefresh: () async {
                final settings = ref.read(settingsServiceProvider);
                for (final p in BillingProvider.values) {
                  if (p == BillingProvider.gemini) continue;
                  await settings.setBillingActualsCacheRaw(p.id, null);
                  ref.invalidate(providerActualsProvider(p));
                }
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Connect a provider to see your real spend straight from '
                    'their billing API — separate from the estimates tracked here.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  for (final provider in BillingProvider.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ProviderCard(provider: provider),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ProviderCard extends ConsumerWidget {
  const _ProviderCard({required this.provider});
  final BillingProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncActuals = ref.watch(providerActualsProvider(provider));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(provider.displayName,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                asyncActuals.maybeWhen(
                  data: (a) => a.status == BillingStatus.connected
                      ? IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh',
                          onPressed: () async {
                            await ref
                                .read(settingsServiceProvider)
                                .setBillingActualsCacheRaw(provider.id, null);
                            ref.invalidate(providerActualsProvider(provider));
                          },
                        )
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            asyncActuals.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _StatusMessage(
                icon: Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                text: 'Could not load: $e',
              ),
              data: (a) => _body(context, ref, a),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, ProviderActuals a) {
    switch (a.status) {
      case BillingStatus.connected:
        final tracked =
            ref.watch(trackedMonthCostByProviderProvider)[provider.pricingProvider] ??
                0.0;
        return _ConnectedView(
          actuals: a,
          trackedMonthCost: tracked,
          onDisconnect: () => _disconnect(context, ref),
        );
      case BillingStatus.notConnected:
        return _NotConnectedView(
          provider: provider,
          onConnect: () => _showConnectDialog(context, ref),
        );
      case BillingStatus.unsupported:
        return provider == BillingProvider.gemini
            ? const _GeminiUnsupportedView()
            : _StatusMessage(
                icon: Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                text: 'Billing data isn\'t available for this provider.',
              );
      case BillingStatus.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusMessage(
              icon: Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              text: a.errorMessage ?? 'Something went wrong.',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    await ref
                        .read(settingsServiceProvider)
                        .setBillingActualsCacheRaw(provider.id, null);
                    ref.invalidate(providerActualsProvider(provider));
                  },
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () => _showConnectDialog(context, ref),
                  child: const Text('Update key'),
                ),
              ],
            ),
          ],
        );
    }
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsServiceProvider);
    await settings.setBillingApiKey(provider.id, null);
    await settings.setBillingActualsCacheRaw(provider.id, null);
    ref.invalidate(providerActualsProvider(provider));
  }

  Future<void> _showConnectDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Connect ${provider.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(provider.keyHint,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Billing key'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(provider.keySetupUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Where do I get this?'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (action != null && action.isNotEmpty) {
      final settings = ref.read(settingsServiceProvider);
      await settings.setBillingApiKey(provider.id, action);
      // Clear stale cache so the new key triggers a fresh fetch.
      await settings.setBillingActualsCacheRaw(provider.id, null);
      ref.invalidate(providerActualsProvider(provider));
    }
  }
}

class _ConnectedView extends StatelessWidget {
  const _ConnectedView({
    required this.actuals,
    required this.trackedMonthCost,
    required this.onDisconnect,
  });

  final ProviderActuals actuals;
  final double trackedMonthCost;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasBalance = actuals.balance != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Headline: prepaid balance (OpenRouter) or month cost (OpenAI/Anthropic).
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              Formatters.currency(
                  hasBalance ? actuals.balance! : (actuals.monthCost ?? 0)),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(width: 6),
            Text(hasBalance ? 'balance' : 'this month (actual)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    )),
          ],
        ),
        const SizedBox(height: 8),
        if (hasBalance) ...[
          Row(
            children: [
              _Metric(label: 'Used', value: actuals.totalUsed),
              const SizedBox(width: 24),
              _Metric(label: 'Credited', value: actuals.totalCredits),
            ],
          ),
          if (trackedMonthCost > 0) ...[
            const SizedBox(height: 8),
            _RunwayChip(
              balance: actuals.balance!,
              trackedMonthCost: trackedMonthCost,
            ),
          ],
        ] else
          _TrackedVsActual(
            tracked: trackedMonthCost,
            actual: actuals.monthCost ?? 0,
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (actuals.lastSynced != null)
              Text(
                'Synced ${_timeAgo(actuals.lastSynced!)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            const Spacer(),
            TextButton(
              onPressed: onDisconnect,
              child: const Text('Disconnect'),
            ),
          ],
        ),
      ],
    );
  }
}

class _RunwayChip extends StatelessWidget {
  const _RunwayChip({
    required this.balance,
    required this.trackedMonthCost,
  });

  final double balance;
  final double trackedMonthCost;

  @override
  Widget build(BuildContext context) {
    final daysElapsed = DateTime.now().day; // 1-31
    final dailyRate = trackedMonthCost / daysElapsed;
    if (dailyRate <= 0) return const SizedBox.shrink();

    final runwayDays = (balance / dailyRate).round();
    final String label;
    if (runwayDays <= 0) {
      label = 'Credits nearly depleted at current rate';
    } else if (runwayDays > 365) {
      label = 'Credits last > 1 year at current rate';
    } else {
      label = 'Credits last ~$runwayDays days at current rate';
    }

    return Row(
      children: [
        Icon(Icons.schedule_outlined,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

/// Compares this app's tracked (estimated) spend vs the provider's actual,
/// for the current month. Actual is org-wide; tracked is only what this app saw.
class _TrackedVsActual extends StatelessWidget {
  const _TrackedVsActual({required this.tracked, required this.actual});
  final double tracked;
  final double actual;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String drift = '';
    if (actual > 0) {
      final pct = ((tracked - actual) / actual * 100).round();
      drift = pct == 0 ? 'matches actual' : '${pct > 0 ? '+' : ''}$pct% vs actual';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Metric(label: 'Tracked here', value: tracked),
            const SizedBox(width: 24),
            _Metric(label: 'Actual (org-wide)', value: actual),
          ],
        ),
        if (drift.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Tracked $drift',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Actual includes all usage on this key, not just this app.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        Text(
          value != null ? Formatters.currency(value!) : '—',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _NotConnectedView extends StatelessWidget {
  const _NotConnectedView({required this.provider, required this.onConnect});
  final BillingProvider provider;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Not connected. Add a billing key to see your real ${provider.displayName} spend.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onConnect,
          icon: const Icon(Icons.link),
          label: Text('Connect ${provider.displayName}'),
        ),
      ],
    );
  }
}

class _GeminiUnsupportedView extends StatelessWidget {
  const _GeminiUnsupportedView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusMessage(
          icon: Icons.info_outline,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          text: 'Google doesn\'t expose a public billing API, so this app '
              'can\'t pull your Gemini spend automatically. '
              'View it directly in the Google Cloud Billing console.',
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse('https://console.cloud.google.com/billing'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Open Google Cloud Billing'),
        ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _WebUnavailable extends StatelessWidget {
  const _WebUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.public_off,
                size: 56,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Balances aren\'t available on the web build — browser security '
              'blocks direct calls to provider billing APIs. Use the desktop '
              'or mobile app.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
