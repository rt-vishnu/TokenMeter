import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';

class IntegrationScreen extends ConsumerWidget {
  const IntegrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                serverState.isRunning
                    ? 'Running on ${serverState.endpoint}'
                    : 'Start server to receive usage from IDEs',
              ),
              value: serverState.isRunning,
              onChanged: (v) =>
                  ref.read(serverStateProvider.notifier).toggle(v),
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
        _InfoTile(label: 'API Key', value: apiKey, copyable: true),
        if (endpoint != null) ...[
          const SizedBox(height: 8),
          _InfoTile(label: 'Endpoint', value: endpoint, copyable: true),
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
        const SizedBox(height: 16),
        Text('Code Snippets', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _SnippetCard(
          title: 'curl',
          snippet: _curlSnippet(endpoint, apiKey),
        ),
        _SnippetCard(
          title: 'PowerShell',
          snippet: _powershellSnippet(endpoint, apiKey),
        ),
        _SnippetCard(
          title: 'Python',
          snippet: _pythonSnippet(endpoint, apiKey),
        ),
        const SizedBox(height: 8),
        Text(
          'See docs/INTEGRATION.md for Cursor, VS Code, and other IDE setup.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
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
        trailing: copyable
            ? IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copied')),
                  );
                },
              )
            : null,
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
