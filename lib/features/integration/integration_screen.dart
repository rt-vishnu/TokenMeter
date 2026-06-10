import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';

class IntegrationScreen extends ConsumerStatefulWidget {
  const IntegrationScreen({super.key});

  @override
  ConsumerState<IntegrationScreen> createState() => _IntegrationScreenState();
}

class _IntegrationScreenState extends ConsumerState<IntegrationScreen> {
  bool _keyVisible = false;

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(serverStateProvider);
    final settings = ref.watch(settingsServiceProvider);
    final apiKey = settings.apiKey;
    final endpoint = serverState.endpoint;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (kIsWeb)
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Web mode: configure a remote API host in Settings to connect '
                'to a TokenMeter instance running on your phone or desktop.',
              ),
            ),
          ),
        if (!kIsWeb) ...[
          Card(
            child: SwitchListTile(
              title: const Text('Enable API Server'),
              subtitle: Text(
                serverState.isStopping
                    ? 'Stopping server…'
                    : serverState.isRunning
                        ? 'Running on ${serverState.endpoint}'
                        : 'Start server to receive usage from IDEs',
              ),
              value: serverState.isRunning,
              onChanged: serverState.isStopping
                  ? null
                  : (v) => ref.read(serverStateProvider.notifier).toggle(v),
            ),
          ),
          if (serverState.isRunning && serverState.usedFallbackPort)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Fallback port in use'),
                  subtitle: Text(
                    'Port ${serverState.requestedPort} was occupied — '
                    'started on port ${serverState.port} instead.',
                  ),
                ),
              ),
            ),
          if (serverState.isRunning)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Card(
                color: Colors.amber.shade800.withValues(alpha: 0.2),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded,
                      color: Colors.amber),
                  title: const Text('Unencrypted connection'),
                  subtitle: const Text(
                    'API server is running over HTTP. Only use on trusted networks.',
                  ),
                ),
              ),
            ),
          if (serverState.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                serverState.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
        const SizedBox(height: 16),
        _ApiKeyTile(
          apiKey: apiKey,
          visible: _keyVisible,
          onToggleVisibility: () => setState(() => _keyVisible = !_keyVisible),
          onRegenerate: () => _confirmRegenerate(context, ref),
        ),
        if (endpoint != null) ...[
          const SizedBox(height: 8),
          _InfoTile(label: 'Endpoint', value: endpoint, copyable: true),
          const SizedBox(height: 8),
          _TestConnectionTile(endpoint: endpoint, apiKey: apiKey),
          const SizedBox(height: 16),
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: '$endpoint?key=$apiKey',
                  version: QrVersions.auto,
                  size: 180,
                ),
              ),
            ),
          ),
        ],
        if (endpoint == null && settings.isWebClientMode) ...[
          const SizedBox(height: 8),
          _TestConnectionTile(
            endpoint: settings.remoteHostUrl!,
            apiKey: apiKey,
          ),
        ],
        const SizedBox(height: 16),
        Text('Code Snippets', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _SnippetCard(title: 'curl', snippet: _curlSnippet(endpoint, apiKey)),
        _SnippetCard(title: 'PowerShell', snippet: _powershellSnippet(endpoint, apiKey)),
        _SnippetCard(title: 'Python', snippet: _pythonSnippet(endpoint, apiKey)),
        _SnippetCard(title: 'JavaScript (Node.js)', snippet: _jsSnippet(endpoint, apiKey)),
        const SizedBox(height: 8),
        Text(
          'See docs/INTEGRATION.md for Cursor, VS Code, and other IDE setup.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _jsSnippet(String? endpoint, String apiKey) {
    final url = endpoint ?? 'http://<YOUR_IP>:${AppConstants.defaultApiPort}';
    return '''// Node.js (built-in fetch, Node 18+)
await fetch("$url/api/v1/usage", {
  method: "POST",
  headers: {
    "Authorization": "Bearer $apiKey",
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    model: "gpt-4o",
    input_tokens: 1200,
    output_tokens: 300,
    source: "cursor",
  }),
});''';
  }

  Future<void> _confirmRegenerate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate API Key?'),
        content: const Text(
          'This will invalidate all existing integrations using the current key. '
          'You will need to update them with the new key.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(settingsServiceProvider).regenerateApiKey();
    // Restart the server if running so it picks up the new key.
    final notifier = ref.read(serverStateProvider.notifier);
    if (ref.read(serverStateProvider).isRunning) {
      await notifier.toggle(false);
      await notifier.toggle(true);
    }
    // Refresh providers that depend on the settings.
    ref.invalidate(settingsServiceProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key regenerated')),
      );
    }
  }

  String _curlSnippet(String? endpoint, String apiKey) {
    final url = endpoint ?? 'http://<YOUR_IP>:${AppConstants.defaultApiPort}';
    return '''curl -X POST "$url/api/v1/usage" \\
  -H "Authorization: Bearer $apiKey" \\
  -H "Content-Type: application/json" \\
  -d '{"model":"gpt-4o","input_tokens":1200,"output_tokens":300,"source":"cursor"}' ''';
  }

  String _powershellSnippet(String? endpoint, String apiKey) {
    final url = endpoint ?? 'http://<YOUR_IP>:${AppConstants.defaultApiPort}';
    return r'''$headers = @{
  "Authorization" = "Bearer ''' +
        apiKey +
        r'''"
  "Content-Type" = "application/json"
}
$body = '{"model":"gpt-4o","input_tokens":1200,"output_tokens":300,"source":"cursor"}'
Invoke-RestMethod -Uri "''' +
        url +
        r'''/api/v1/usage" -Method POST -Headers $headers -Body $body''';
  }

  String _pythonSnippet(String? endpoint, String apiKey) {
    final url = endpoint ?? 'http://<YOUR_IP>:${AppConstants.defaultApiPort}';
    return '''import requests

requests.post(
    "$url/api/v1/usage",
    headers={"Authorization": "Bearer $apiKey"},
    json={
        "model": "gpt-4o",
        "input_tokens": 1200,
        "output_tokens": 300,
        "source": "cursor",
    },
)''';
  }
}

class _ApiKeyTile extends StatelessWidget {
  const _ApiKeyTile({
    required this.apiKey,
    required this.visible,
    required this.onToggleVisibility,
    required this.onRegenerate,
  });

  final String apiKey;
  final bool visible;
  final VoidCallback onToggleVisibility;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final display = visible ? apiKey : '•' * 20;
    return Card(
      child: ListTile(
        title: const Text('API Key'),
        subtitle: SelectableText(
          display,
          style: visible ? const TextStyle(fontFamily: 'monospace', fontSize: 12) : null,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
              tooltip: visible ? 'Hide key' : 'Show key',
              onPressed: onToggleVisibility,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Regenerate key',
              onPressed: onRegenerate,
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy key',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: apiKey));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API key copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TestConnectionTile extends StatefulWidget {
  const _TestConnectionTile({required this.endpoint, required this.apiKey});

  final String endpoint;
  final String apiKey;

  @override
  State<_TestConnectionTile> createState() => _TestConnectionTileState();
}

class _TestConnectionTileState extends State<_TestConnectionTile> {
  bool _testing = false;

  Future<void> _test() async {
    setState(() => _testing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final normalized = widget.endpoint.endsWith('/')
          ? widget.endpoint.substring(0, widget.endpoint.length - 1)
          : widget.endpoint;
      final response = await http
          .get(Uri.parse('$normalized/api/v1/health'))
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (response.statusCode == 200) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Connected ✓'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('Server returned ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.wifi_tethering),
        title: const Text('Test Connection'),
        subtitle: const Text('Checks /api/v1/health'),
        trailing: _testing
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FilledButton.tonal(
                onPressed: _test,
                child: const Text('Test'),
              ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: SelectableText(value),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (copyable)
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copied')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SnippetCard extends StatelessWidget {
  const _SnippetCard({required this.title, required this.snippet});

  final String title;
  final String snippet;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(title),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    snippet,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: snippet));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$title snippet copied')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
