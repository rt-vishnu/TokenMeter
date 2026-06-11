import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/usage_payload.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/cost_calculator.dart';
import '../../core/services/llm_client.dart';
import '../../core/services/pricing_repository.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/formatters.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatMessage {
  const _ChatMessage({
    required this.isUser,
    required this.text,
    this.inputTokens,
    this.outputTokens,
    this.cost,
    this.isError = false,
  });

  final bool isUser;
  final String text;
  final int? inputTokens;
  final int? outputTokens;
  final double? cost;
  final bool isError;
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;
  double _sessionCost = 0;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Models available for [provider], taken from the pricing data.
  List<String> _modelsFor(LlmProvider provider, PricingRepository pricing) {
    return pricing.sortedModels
        .where((m) => m.provider == provider.pricingProvider)
        .map((m) => m.id)
        .toList();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    final settings = ref.read(settingsServiceProvider);
    final pricing = ref.read(pricingRepositoryProvider);
    final provider = LlmProvider.fromId(settings.chatProvider);
    final model = _currentModel(settings, pricing, provider);

    if (model.isEmpty) {
      _showSnack('Pick a model first.');
      return;
    }
    if (settings.chatApiKey(provider.id) == null) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: text));
      _sending = true;
    });
    _inputController.clear();
    _scrollToBottom();

    final history = [
      for (final m in _messages.where((m) => !m.isError))
        ChatTurn(isUser: m.isUser, text: m.text),
    ];

    final client = LlmClient.forProvider(
      provider,
      apiKey: settings.chatApiKey(provider.id) ?? '',
    );

    try {
      final reply = await client.complete(model: model, history: history);

      final cost = CostCalculator.calculateCost(
        pricing.getModelOrDefault(model),
        reply.inputTokens,
        reply.outputTokens,
      );

      await ref.read(usageRecorderProvider).record(
            UsagePayload(
              model: model,
              inputTokens: reply.inputTokens,
              outputTokens: reply.outputTokens,
              source: 'chat',
              metadata: {
                'provider': provider.id,
                'prompt_preview': text.substring(0, text.length.clamp(0, 120)),
              },
            ),
          );

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          isUser: false,
          text: reply.text,
          inputTokens: reply.inputTokens,
          outputTokens: reply.outputTokens,
          cost: cost,
        ));
        _sessionCost += cost;
        _sending = false;
      });
    } on LlmException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(isUser: false, text: e.message, isError: true));
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          isUser: false,
          text: 'Something went wrong: $e',
          isError: true,
        ));
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  String _currentModel(
    SettingsService settings,
    PricingRepository pricing,
    LlmProvider provider,
  ) {
    final models = _modelsFor(provider, pricing);
    if (models.contains(settings.chatModel)) return settings.chatModel;
    return models.isNotEmpty ? models.first : '';
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _changeProvider(LlmProvider provider) async {
    final settings = ref.read(settingsServiceProvider);
    final pricing = ref.read(pricingRepositoryProvider);
    await settings.setChatProvider(provider.id);
    // Reset the model to a sensible default for the new provider.
    final models = _modelsFor(provider, pricing);
    if (models.isNotEmpty) await settings.setChatModel(models.first);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsServiceProvider);
    final pricing = ref.watch(pricingRepositoryProvider);
    final provider = LlmProvider.fromId(settings.chatProvider);
    final needsKey = settings.chatApiKey(provider.id) == null;

    return Column(
      children: [
        _ProviderBar(
          provider: provider,
          sessionCost: _sessionCost,
          onProviderChanged: _changeProvider,
          onConfigure: () => _showConfigDialog(context, provider),
        ),
        if (!needsKey)
          _ModelSelector(
            provider: provider,
            models: _modelsFor(provider, pricing),
            pricing: pricing,
            selected: _currentModel(settings, pricing, provider),
            onModelChanged: (id) async {
              await settings.setChatModel(id);
              if (mounted) setState(() {});
            },
          ),
        const Divider(height: 1),
        Expanded(
          child: needsKey
              ? _ProviderSetupView(
                  provider: provider,
                  onSaved: () => setState(() {}),
                )
              : _messages.isEmpty
                  ? const _ChatEmptyHint()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const _TypingIndicator();
                        }
                        return _MessageBubble(message: _messages[index]);
                      },
                    ),
        ),
        if (!needsKey)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: 'Ask anything…',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showConfigDialog(
      BuildContext context, LlmProvider provider) async {
    final settings = ref.read(settingsServiceProvider);
    final controller = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${provider.displayName} API key'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Paste new key',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'remove'),
            child: const Text('Remove key'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (action == 'remove') {
      await settings.setChatApiKey(provider.id, null);
    } else if (action == 'save' && controller.text.trim().isNotEmpty) {
      await settings.setChatApiKey(provider.id, controller.text);
    }
    if (mounted) setState(() {});
  }
}

// ── Provider bar (provider picker + session cost + config) ──────────────────

class _ProviderBar extends StatelessWidget {
  const _ProviderBar({
    required this.provider,
    required this.sessionCost,
    required this.onProviderChanged,
    required this.onConfigure,
  });

  final LlmProvider provider;
  final double sessionCost;
  final ValueChanged<LlmProvider> onProviderChanged;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<LlmProvider>(
              isExpanded: true,
              initialValue: provider,
              decoration: const InputDecoration(
                labelText: 'Provider',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final p in LlmProvider.values)
                  DropdownMenuItem(value: p, child: Text(p.displayName)),
              ],
              onChanged: (p) {
                if (p != null) onProviderChanged(p);
              },
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Session',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
              Text(Formatters.currency(sessionCost),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.key),
            tooltip: 'Change API key',
            onPressed: onConfigure,
          ),
        ],
      ),
    );
  }
}

// ── Model selector ────────────────────────────────────────────────────────

class _ModelSelector extends StatelessWidget {
  const _ModelSelector({
    required this.provider,
    required this.models,
    required this.pricing,
    required this.selected,
    required this.onModelChanged,
  });

  final LlmProvider provider;
  final List<String> models;
  final PricingRepository pricing;
  final String selected;
  final ValueChanged<String> onModelChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: models.contains(selected) ? selected : null,
        decoration: const InputDecoration(
          labelText: 'Model',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: [
          for (final id in models)
            DropdownMenuItem(
              value: id,
              child: Text(pricing.getModelOrDefault(id).displayName),
            ),
        ],
        onChanged: (v) {
          if (v != null) onModelChanged(v);
        },
      ),
    );
  }
}

// ── Message bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = message.isError
        ? scheme.errorContainer
        : message.isUser
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(message.text),
            if (message.cost != null) ...[
              const SizedBox(height: 6),
              Text(
                '${Formatters.tokens(message.inputTokens!)} in · '
                '${Formatters.tokens(message.outputTokens!)} out · '
                '${Formatters.currency(message.cost!)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ChatEmptyHint extends StatelessWidget {
  const _ChatEmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 56,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Ask anything — every reply\'s real token usage\n'
            'is tracked automatically in your Dashboard.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Per-provider setup (shown when a key is required but missing) ────────────

class _ProviderSetupView extends ConsumerStatefulWidget {
  const _ProviderSetupView({required this.provider, required this.onSaved});

  final LlmProvider provider;
  final VoidCallback onSaved;

  @override
  ConsumerState<_ProviderSetupView> createState() => _ProviderSetupViewState();
}

class _ProviderSetupViewState extends ConsumerState<_ProviderSetupView> {
  final _keyController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    setState(() => _saving = true);
    await ref
        .read(settingsServiceProvider)
        .setChatApiKey(widget.provider.id, key);
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connect ${p.displayName}',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Paste your ${p.displayName} API key to chat here. Every '
                  'message\'s real token usage and cost is tracked '
                  'automatically in your Dashboard and History.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(p.setupUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text('Get a ${p.displayName} key'),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _keyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API key',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check),
                  label: Text(_saving ? 'Saving…' : 'Start chatting'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your key is stored securely on this device only and is '
                  'sent only to ${p.displayName}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
