import 'dart:convert';

import 'package:http/http.dart' as http;

/// Supported chat providers. The Chat tab talks to each provider's REST API
/// directly, so the model the user picks must exist on that provider.
enum LlmProvider {
  gemini,
  openai,
  anthropic,
  ollama;

  static LlmProvider fromId(String? id) => LlmProvider.values.firstWhere(
        (p) => p.name == id,
        orElse: () => LlmProvider.gemini,
      );
}

extension LlmProviderInfo on LlmProvider {
  String get displayName => switch (this) {
        LlmProvider.gemini => 'Google Gemini',
        LlmProvider.openai => 'OpenAI',
        LlmProvider.anthropic => 'Anthropic Claude',
        LlmProvider.ollama => 'Ollama (local)',
      };

  /// The `provider` value used in the bundled pricing data, so the model
  /// picker can list the right models and look up costs.
  String get pricingProvider => switch (this) {
        LlmProvider.gemini => 'google',
        LlmProvider.openai => 'openai',
        LlmProvider.anthropic => 'anthropic',
        LlmProvider.ollama => 'meta',
      };

  /// Ollama runs locally and needs only a base URL, not an API key.
  bool get usesApiKey => this != LlmProvider.ollama;

  /// Where the user gets an API key (or installs the runtime, for Ollama).
  String get setupUrl => switch (this) {
        LlmProvider.gemini => 'https://aistudio.google.com/apikey',
        LlmProvider.openai => 'https://platform.openai.com/api-keys',
        LlmProvider.anthropic => 'https://console.anthropic.com/settings/keys',
        LlmProvider.ollama => 'https://ollama.com/download',
      };

  String get id => name;
}

/// One turn in a conversation, provider-neutral.
class ChatTurn {
  const ChatTurn({required this.isUser, required this.text});
  final bool isUser;
  final String text;
}

/// A reply with the real token counts reported by the provider.
class ChatResult {
  const ChatResult({
    required this.text,
    required this.inputTokens,
    required this.outputTokens,
  });
  final String text;
  final int inputTokens;
  final int outputTokens;
}

class LlmException implements Exception {
  const LlmException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class LlmClient {
  Future<ChatResult> complete({
    required String model,
    required List<ChatTurn> history,
  });

  factory LlmClient.forProvider(
    LlmProvider provider, {
    String apiKey = '',
    String baseUrl = 'http://localhost:11434',
  }) {
    switch (provider) {
      case LlmProvider.gemini:
        return _GeminiClient(apiKey);
      case LlmProvider.openai:
        return _OpenAiClient(apiKey);
      case LlmProvider.anthropic:
        return _AnthropicClient(apiKey);
      case LlmProvider.ollama:
        return _OllamaClient(baseUrl);
    }
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Future<http.Response> _post(
  Uri uri,
  Map<String, String> headers,
  Object body,
) async {
  try {
    return await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 90));
  } catch (_) {
    throw const LlmException(
        'Network error — check your internet connection or local server.');
  }
}

String _apiErrorMessage(String body) {
  try {
    final json = jsonDecode(body);
    if (json is Map) {
      final err = json['error'];
      if (err is Map && err['message'] is String) return err['message'] as String;
      if (err is String) return err;
      if (json['message'] is String) return json['message'] as String;
    }
  } catch (_) {}
  return body.length > 200 ? '${body.substring(0, 200)}…' : body;
}

// ── Gemini ────────────────────────────────────────────────────────────────────

class _GeminiClient implements LlmClient {
  _GeminiClient(this.apiKey);
  final String apiKey;

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  @override
  Future<ChatResult> complete({
    required String model,
    required List<ChatTurn> history,
  }) async {
    final res = await _post(
      Uri.parse('$_base/models/$model:generateContent'),
      {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
      {
        'contents': [
          for (final t in history)
            {
              'role': t.isUser ? 'user' : 'model',
              'parts': [
                {'text': t.text},
              ],
            },
        ],
      },
    );

    if (res.statusCode != 200) {
      final msg = _apiErrorMessage(res.body);
      if (res.statusCode == 400 && msg.contains('API key not valid')) {
        throw const LlmException(
            'Invalid Gemini API key — get one at aistudio.google.com/apikey.');
      }
      if (res.statusCode == 404) {
        throw const LlmException('Model not found or retired — pick another.');
      }
      if (res.statusCode == 429) {
        throw const LlmException(
            'Gemini quota exceeded — wait a minute or use a lighter model.');
      }
      throw LlmException('Gemini error ${res.statusCode}: $msg');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    String text;
    try {
      final parts = ((json['candidates'] as List).first as Map)['content']
          ['parts'] as List;
      text = parts.map((p) => (p as Map)['text'] as String? ?? '').join().trim();
    } catch (_) {
      text = '(no text in response)';
    }
    final usage = json['usageMetadata'] as Map<String, dynamic>? ?? {};
    return ChatResult(
      text: text,
      inputTokens: (usage['promptTokenCount'] as num?)?.toInt() ?? 0,
      outputTokens: (usage['candidatesTokenCount'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── OpenAI ──────────────────────────────────────────────────────────────────

class _OpenAiClient implements LlmClient {
  _OpenAiClient(this.apiKey);
  final String apiKey;

  @override
  Future<ChatResult> complete({
    required String model,
    required List<ChatTurn> history,
  }) async {
    final res = await _post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
      {
        'model': model,
        'messages': [
          for (final t in history)
            {'role': t.isUser ? 'user' : 'assistant', 'content': t.text},
        ],
      },
    );

    if (res.statusCode != 200) {
      final msg = _apiErrorMessage(res.body);
      if (res.statusCode == 401) {
        throw const LlmException(
            'Invalid OpenAI API key — check platform.openai.com/api-keys.');
      }
      if (res.statusCode == 404) {
        throw const LlmException(
            'Model not available to your account — pick another.');
      }
      if (res.statusCode == 429) {
        throw const LlmException(
            'OpenAI rate limit or no credit — check your billing.');
      }
      throw LlmException('OpenAI error ${res.statusCode}: $msg');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final text = (((json['choices'] as List).first as Map)['message']
            as Map)['content'] as String? ??
        '(no text in response)';
    final usage = json['usage'] as Map<String, dynamic>? ?? {};
    return ChatResult(
      text: text.trim(),
      inputTokens: (usage['prompt_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (usage['completion_tokens'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── Anthropic ─────────────────────────────────────────────────────────────────

class _AnthropicClient implements LlmClient {
  _AnthropicClient(this.apiKey);
  final String apiKey;

  @override
  Future<ChatResult> complete({
    required String model,
    required List<ChatTurn> history,
  }) async {
    final res = await _post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        // Allows direct calls from the Flutter web build (CORS).
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      {
        'model': model,
        'max_tokens': 2048,
        'messages': [
          for (final t in history)
            {'role': t.isUser ? 'user' : 'assistant', 'content': t.text},
        ],
      },
    );

    if (res.statusCode != 200) {
      final msg = _apiErrorMessage(res.body);
      if (res.statusCode == 401) {
        throw const LlmException(
            'Invalid Anthropic API key — check console.anthropic.com.');
      }
      if (res.statusCode == 404) {
        throw const LlmException('Model not found — pick another.');
      }
      if (res.statusCode == 429) {
        throw const LlmException('Anthropic rate limit — wait and try again.');
      }
      throw LlmException('Anthropic error ${res.statusCode}: $msg');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    String text;
    try {
      final blocks = json['content'] as List;
      text = blocks
          .where((b) => (b as Map)['type'] == 'text')
          .map((b) => (b as Map)['text'] as String? ?? '')
          .join()
          .trim();
    } catch (_) {
      text = '(no text in response)';
    }
    final usage = json['usage'] as Map<String, dynamic>? ?? {};
    return ChatResult(
      text: text,
      inputTokens: (usage['input_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (usage['output_tokens'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── Ollama (local) ────────────────────────────────────────────────────────────

class _OllamaClient implements LlmClient {
  _OllamaClient(this.baseUrl);
  final String baseUrl;

  @override
  Future<ChatResult> complete({
    required String model,
    required List<ChatTurn> history,
  }) async {
    final normalized =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

    final res = await _post(
      Uri.parse('$normalized/api/chat'),
      {'Content-Type': 'application/json'},
      {
        'model': model,
        'stream': false,
        'messages': [
          for (final t in history)
            {'role': t.isUser ? 'user' : 'assistant', 'content': t.text},
        ],
      },
    );

    if (res.statusCode != 200) {
      final msg = _apiErrorMessage(res.body);
      if (res.statusCode == 404) {
        throw LlmException(
            'Model "$model" not pulled. Run: ollama pull $model');
      }
      throw LlmException('Ollama error ${res.statusCode}: $msg');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final text = (json['message'] as Map?)?['content'] as String? ??
        '(no text in response)';
    return ChatResult(
      text: text.trim(),
      inputTokens: (json['prompt_eval_count'] as num?)?.toInt() ?? 0,
      outputTokens: (json['eval_count'] as num?)?.toInt() ?? 0,
    );
  }
}
