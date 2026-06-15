import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/usage_payload.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/cost_calculator.dart';
import '../../core/services/llm_client.dart';
import '../../core/services/pricing_repository.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/formatters.dart';
import '../../data/database/app_database_io.dart';

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
    this.model,
    this.interrupted = false,
  });

  final bool isUser;
  final String text;
  final int? inputTokens;
  final int? outputTokens;
  final double? cost;
  final bool isError;
  /// Model that produced an assistant reply, included in abuse reports.
  final String? model;
  /// A reply that failed or was cut off mid-stream — offers a retry, and is
  /// excluded from the context sent on later turns.
  final bool interrupted;
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  final _flaggedIndices = <int>{};
  bool _sending = false;
  bool _loadingHistory = false;
  double _sessionCost = 0;
  // Partial assistant reply while a streamed response is in flight.
  String _streamingText = '';
  String? _sessionId;

  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _loadLastSession();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLastSession() async {
    final db = ref.read(appDatabaseProvider);
    if (db == null) return;
    setState(() => _loadingHistory = true);
    try {
      final sessionId = await db.getLatestSessionId();
      if (sessionId == null || !mounted) return;
      final rows = await db.getSessionMessages(sessionId);
      if (!mounted) return;
      setState(() {
        _sessionId = sessionId;
        _messages.addAll(rows.map(_messageFromDb));
        _sessionCost = rows.fold(0.0, (sum, r) => sum + (r.costUsd ?? 0));
      });
      _jumpToBottom();
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  _ChatMessage _messageFromDb(ChatMessage row) => _ChatMessage(
        isUser: row.role == 'user',
        text: row.content,
        inputTokens: row.inputTokens,
        outputTokens: row.outputTokens,
        cost: row.costUsd,
        model: row.model,
        interrupted: row.interrupted,
      );

  Future<void> _persistMessage(String role, _ChatMessage msg) async {
    final db = ref.read(appDatabaseProvider);
    if (db == null || _sessionId == null) return;
    await db.insertChatMessage(ChatMessagesCompanion(
      id: Value(_uuid.v4()),
      sessionId: Value(_sessionId!),
      role: Value(role),
      content: Value(msg.text),
      inputTokens: Value(msg.inputTokens),
      outputTokens: Value(msg.outputTokens),
      costUsd: Value(msg.cost),
      model: Value(msg.model),
      interrupted: Value(msg.interrupted),
      createdAt: Value(DateTime.now()),
    ));
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _flaggedIndices.clear();
      _sessionId = null;
      _sessionCost = 0;
      _streamingText = '';
      _sending = false;
    });
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

  /// Instant scroll used while deltas stream in (animations would queue up).
  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  /// Selectable models for [provider]: every non-deprecated model that belongs
  /// to this provider (by pricing `provider`, or a custom model whose id is
  /// owned by it). Models flagged `deprecated` in the pricing data are hidden.
  List<String> _modelsFor(LlmProvider provider, PricingRepository pricing) {
    return pricing.sortedModels
        .where((m) =>
            !m.deprecated &&
            (m.provider == provider.pricingProvider ||
                (m.isCustom && provider.ownsCustomModel(m.id))))
        .map((m) => m.id)
        .toList();
  }

  // Only the most recent messages are sent as context. This keeps each request
  // fast and bounded no matter how long the session runs — otherwise input
  // tokens (and latency) grow every turn and heavier models start timing out.
  static const _maxHistoryMessages = 16;

  /// Recent, complete turns to send as context — errors and interrupted
  /// (partial) replies are excluded, then the tail is windowed.
  List<ChatTurn> _buildHistory() {
    final valid =
        _messages.where((m) => !m.isError && !m.interrupted).toList();
    final start = valid.length > _maxHistoryMessages
        ? valid.length - _maxHistoryMessages
        : 0;
    return [
      for (final m in valid.sublist(start))
        ChatTurn(isUser: m.isUser, text: m.text),
    ];
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

    _sessionId ??= _uuid.v4();
    final userMsg = _ChatMessage(isUser: true, text: text);
    setState(() {
      _messages.add(userMsg);
      _sending = true;
    });
    _inputController.clear();
    _scrollToBottom();
    await _persistMessage('user', userMsg);

    await _runCompletion(provider, model, pricing);
  }

  /// Re-asks the latest question after a failed/interrupted reply, without
  /// duplicating the user's message.
  Future<void> _retry() async {
    if (_sending) return;
    final settings = ref.read(settingsServiceProvider);
    final pricing = ref.read(pricingRepositoryProvider);
    final provider = LlmProvider.fromId(settings.chatProvider);
    final model = _currentModel(settings, pricing, provider);
    if (model.isEmpty || settings.chatApiKey(provider.id) == null) return;

    setState(() {
      // Drop the trailing failed/interrupted assistant reply so we re-ask from
      // the last user turn.
      while (_messages.isNotEmpty && !_messages.last.isUser) {
        _messages.removeLast();
      }
      _sending = true;
    });
    _scrollToBottom();

    await _runCompletion(provider, model, pricing);
  }

  Future<void> _runCompletion(
    LlmProvider provider,
    String model,
    PricingRepository pricing,
  ) async {
    final settings = ref.read(settingsServiceProvider);
    final promptForUsage =
        _messages.lastWhere((m) => m.isUser, orElse: () => _empty).text;
    final client = LlmClient.forProvider(
      provider,
      apiKey: settings.chatApiKey(provider.id) ?? '',
    );

    try {
      final reply = await client.complete(
        model: model,
        history: _buildHistory(),
        onDelta: (delta) {
          if (!mounted) return;
          setState(() => _streamingText += delta);
          _jumpToBottom();
        },
      );

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
                'prompt_preview': promptForUsage.substring(
                    0, promptForUsage.length.clamp(0, 120)),
              },
            ),
          );

      if (!mounted) return;
      final assistantMsg = _ChatMessage(
        isUser: false,
        text: reply.text,
        inputTokens: reply.inputTokens,
        outputTokens: reply.outputTokens,
        cost: cost,
        model: model,
      );
      setState(() {
        _messages.add(assistantMsg);
        _sessionCost += cost;
        _streamingText = '';
        _sending = false;
      });
      await _persistMessage('assistant', assistantMsg);
    } on LlmException catch (e) {
      _handleFailure(e.message);
    } catch (e) {
      _handleFailure('Something went wrong: $e');
    }
    _scrollToBottom();
  }

  /// Keeps any text that already streamed in (marked interrupted, with retry)
  /// instead of discarding it; otherwise shows a concise, retryable error.
  void _handleFailure(String message) {
    if (!mounted) return;
    setState(() {
      final partial = _streamingText.trim();
      if (partial.isNotEmpty) {
        _messages.add(_ChatMessage(
          isUser: false,
          text: partial,
          interrupted: true,
        ));
      } else {
        _messages.add(_ChatMessage(
          isUser: false,
          text: message,
          isError: true,
          interrupted: true,
        ));
      }
      _streamingText = '';
      _sending = false;
    });
  }

  static const _empty = _ChatMessage(isUser: true, text: '');

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

  /// Where abuse reports for AI responses are sent.
  static const _reportEmail = 'ravi.vishnubhotla123@gmail.com';

  /// Reports an AI response as inappropriate. Confirms with the user (with an
  /// optional reason), then opens their email app pre-filled with the response
  /// so it can be reviewed. Satisfies the Generative AI content-reporting
  /// requirement for an app with no backend.
  Future<void> _reportResponse(int index) async {
    final msg = _messages[index];
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report this response?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This opens your email app with the flagged response so it can be '
              'reviewed. Nothing is sent until you press send.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final reason = reasonController.text.trim();
    final body = StringBuffer()
      ..writeln('I am reporting the following AI-generated response as '
          'inappropriate.')
      ..writeln()
      ..writeln('Reason: ${reason.isEmpty ? '(not provided)' : reason}')
      ..writeln('Model: ${msg.model ?? 'unknown'}')
      ..writeln()
      ..writeln('--- Response ---')
      ..writeln(msg.text);
    final uri = Uri.parse(
      'mailto:$_reportEmail'
      '?subject=${Uri.encodeComponent('PromptPenny — Reported AI response')}'
      '&body=${Uri.encodeComponent(body.toString())}',
    );

    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!mounted) return;
    setState(() => _flaggedIndices.add(index));
    _showSnack(launched
        ? 'Thanks for reporting — your email app is ready to send.'
        : 'Marked as reported. No email app found — contact $_reportEmail.');
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
          hasMessages: _messages.isNotEmpty,
          onProviderChanged: _changeProvider,
          onConfigure: () => _showConfigDialog(context, provider),
          onNewChat: _startNewChat,
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
              : _loadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? const _ChatEmptyHint()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          // Streamed text appears live; spinner until the
                          // first delta arrives.
                          return _streamingText.isEmpty
                              ? const _TypingIndicator()
                              : _MessageBubble(
                                  message: _ChatMessage(
                                    isUser: false,
                                    text: _streamingText,
                                  ),
                                  isFlagged: false,
                                  onFlag: null,
                                  onRetry: null,
                                );
                        }
                        final msg = _messages[index];
                        // Retry only the latest failed/interrupted reply.
                        final canRetry = msg.interrupted &&
                            !_sending &&
                            index == _messages.length - 1;
                        return _MessageBubble(
                          message: msg,
                          isFlagged: _flaggedIndices.contains(index),
                          onFlag: (!msg.isUser && !msg.isError)
                              ? () => _reportResponse(index)
                              : null,
                          onRetry: canRetry ? _retry : null,
                        );
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
                      decoration: InputDecoration(
                        hintText: 'Ask anything…',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    iconSize: 22,
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
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
    required this.hasMessages,
    required this.onProviderChanged,
    required this.onConfigure,
    required this.onNewChat,
  });

  final LlmProvider provider;
  final double sessionCost;
  final bool hasMessages;
  final ValueChanged<LlmProvider> onProviderChanged;
  final VoidCallback onConfigure;
  final VoidCallback onNewChat;

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
          if (hasMessages)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: 'New chat',
              onPressed: onNewChat,
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

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    required this.isFlagged,
    required this.onFlag,
    this.onRetry,
  });

  final _ChatMessage message;
  final bool isFlagged;
  final VoidCallback? onFlag;
  final VoidCallback? onRetry;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.message.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final scheme = Theme.of(context).colorScheme;
    final bg = message.isError
        ? scheme.errorContainer
        : message.isUser
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest;

    // Speech-bubble feel: round everywhere except the sender's corner.
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(message.isUser ? 20 : 6),
      bottomRight: Radius.circular(message.isUser ? 6 : 20),
    );

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assistant replies are markdown; user/error text stays plain.
            if (message.isUser || message.isError)
              SelectableText(message.text)
            else
              _MarkdownReply(text: message.text),
            if (message.interrupted && !message.isError) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Response was interrupted',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
            if (widget.onRetry != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onRetry,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.cost != null) ...[
                  Expanded(
                    child: Text(
                      '${Formatters.tokens(message.inputTokens!)} in · '
                      '${Formatters.tokens(message.outputTokens!)} out · '
                      '${Formatters.currency(message.cost!)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ] else
                  const Spacer(),
                GestureDetector(
                  onTap: _copy,
                  child: Tooltip(
                    message: 'Copy',
                    child: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_outlined,
                      size: 14,
                      color: _copied
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                if (widget.onFlag != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onFlag,
                    child: Tooltip(
                      message: widget.isFlagged ? 'Reported' : 'Report response',
                      child: Icon(
                        widget.isFlagged ? Icons.flag : Icons.flag_outlined,
                        size: 14,
                        color: widget.isFlagged
                            ? scheme.error
                            : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders an assistant reply as markdown (bold, headings, lists, code),
/// styled to sit naturally inside the chat bubble.
class _MarkdownReply extends StatelessWidget {
  const _MarkdownReply({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium!;
    final codeBg = theme.colorScheme.surfaceContainerHighest;

    return MarkdownBody(
      data: text,
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: base,
        // Headings shrink to bubble-friendly sizes (no giant h1/h2).
        h1: base.copyWith(fontSize: 19, fontWeight: FontWeight.w800),
        h2: base.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
        h3: base.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        listBullet: base,
        strong: base.copyWith(fontWeight: FontWeight.w800),
        em: base.copyWith(fontStyle: FontStyle.italic),
        code: base.copyWith(
          fontFamily: 'monospace',
          fontSize: 13,
          backgroundColor: codeBg,
        ),
        codeblockDecoration: BoxDecoration(
          color: codeBg,
          borderRadius: BorderRadius.circular(10),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        blockSpacing: 10,
        pPadding: EdgeInsets.zero,
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
