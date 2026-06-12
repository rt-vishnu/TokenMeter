import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Supported chat providers. The Chat tab talks to each provider's REST API
/// directly, so the model the user picks must exist on that provider.
enum LlmProvider {
  gemini,
  openai,
  anthropic;

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
      };

  /// The `provider` value used in the bundled pricing data, so the model
  /// picker can list the right models and look up costs.
  String get pricingProvider => switch (this) {
        LlmProvider.gemini => 'google',
        LlmProvider.openai => 'openai',
        LlmProvider.anthropic => 'anthropic',
      };

  /// Where the user gets an API key.
  String get setupUrl => switch (this) {
        LlmProvider.gemini => 'https://aistudio.google.com/apikey',
        LlmProvider.openai => 'https://platform.openai.com/api-keys',
        LlmProvider.anthropic => 'https://console.anthropic.com/settings/keys',
      };

  /// Whether a user-added custom model id belongs to this provider, so custom
  /// models surface under the right provider in the picker.
  bool ownsCustomModel(String id) => switch (this) {
        LlmProvider.gemini => id.startsWith('gemini'),
        LlmProvider.openai =>
          id.startsWith('gpt') || RegExp(r'^o\d').hasMatch(id),
        LlmProvider.anthropic => id.startsWith('claude'),
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
  /// Completes a chat turn. When [onDelta] is provided, the response is
  /// streamed via SSE and [onDelta] is called with each text fragment as it
  /// arrives; the returned [ChatResult] still carries the full text and the
  /// real token counts reported by the provider.
  Future<ChatResult> complete({
    required String model,
    required List<ChatTurn> history,
    void Function(String delta)? onDelta,
  });

  factory LlmClient.forProvider(LlmProvider provider, {String apiKey = ''}) {
    switch (provider) {
      case LlmProvider.gemini:
        return _GeminiClient(apiKey);
      case LlmProvider.openai:
        return _OpenAiClient(apiKey);
      case LlmProvider.anthropic:
        return _AnthropicClient(apiKey);
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
        'Network error — check your internet connection.');
  }
}

/// Opens a streaming POST. The caller owns [client] and must close it.
Future<http.StreamedResponse> _postStream(
  http.Client client,
  Uri uri,
  Map<String, String> headers,
  Object body,
) async {
  final request = http.Request('POST', uri)
    ..headers.addAll(headers)
    ..body = jsonEncode(body);
  try {
    return await client.send(request).timeout(const Duration(seconds: 30));
  } catch (_) {
    throw const LlmException(
        'Network error — check your internet connection.');
  }
}

/// Decodes an SSE byte stream into the payload of each `data:` line.
/// Throws [TimeoutException] if the provider goes silent for 60 s.
Stream<String> _sseDataLines(http.StreamedResponse res) {
  return res.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .timeout(const Duration(seconds: 60))
      .where((line) => line.startsWith('data:'))
      .map((line) => line.substring(5).trim())
      .where((data) => data.isNotEmpty);
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

  Map<String, String> get _headers =>
      {'Content-Type': 'application/json', 'x-goog-api-key': apiKey};

  Map<String, Object> _payload(List<ChatTurn> history) => {
        'contents': [
          for (final t in history)
            {
              'role': t.isUser ? 'user' : 'model',
              'parts': [
                {'text': t.text},
              ],
            },
        ],
      };

  Never _fail(int code, String body) {
    final msg = _apiErrorMessage(body);
    if (code == 400 && msg.contains('API key not valid')) {
      throw const LlmException(
          'Invalid Gemini API key — get one at aistudio.google.com/apikey.');
    }
    if (code == 404) {
      throw const LlmException('Model not found or retired — pick another.');
    }
    if (code == 429) {
      throw const LlmException(
          'Gemini quota exceeded — wait a minute or use a lighter model.');
    }
    throw LlmException('Gemini error $code: $msg');
  }

  @override
  Future<ChatResult> complete({
    required String model,
    required List<ChatTurn> history,
    void Function(String delta)? onDelta,
  }) async {
    if (onDelta != null) return _streamed(model, history, onDelta);

    final res = await _post(
      Uri.parse('$_base/models/$model:generateContent'),
      _headers,
      _payload(history),
    );
    if (res.statusCode != 200) _fail(res.statusCode, res.body);

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

  Future<ChatResult> _streamed(
    String model,
    List<ChatTurn> history,
    void Function(String delta) onDelta,
  ) async {
    final client = http.Client();
    try {
      final res = await _postStream(
        client,
        Uri.parse('$_base/models/$model:streamGenerateContent?alt=sse'),
        _headers,
        _payload(history),
      );
      if (res.statusCode != 200) {
        _fail(res.statusCode, await res.stream.bytesToString());
      }

      final buf = StringBuffer();
      var input = 0;
      var output = 0;
      await for (final data in _sseDataLines(res)) {
        final Map<String, dynamic> json;
        try {
          json = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        try {
          final parts = ((json['candidates'] as List).first as Map)['content']
              ['parts'] as List;
          final t =
              parts.map((p) => (p as Map)['text'] as String? ?? '').join();
          if (t.isNotEmpty) {
            buf.write(t);
            onDelta(t);
          }
        } catch (_) {}
        final usage = json['usageMetadata'] as Map<String, dynamic>?;
        if (usage != null) {
          input = (usage['promptTokenCount'] as num?)?.toInt() ?? input;
          output = (usage['candidatesTokenCount'] as num?)?.toInt() ?? output;
        }
      }
      return ChatResult(
        text: buf.toString().trim(),
        inputTokens: input,
        outputTokens: output,
      );
    } on TimeoutException {
      throw const LlmException('The response stream stalled — try again.');
    } finally {
      client.close();
    }
  }
}

// ── OpenAI ──────────────────────────────────────────────────────────────────

class _OpenAiClient implements LlmClient {
  _OpenAiClient(this.apiKey);
  final String apiKey;

  static final _uri = Uri.parse('https://api.openai.com/v1/chat/completions');

  Map<String, String> get _headers =>
      {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'};

  List<Map<String, String>> _messages(List<ChatTurn> history) => [
        for (final t in history)
          {'role': t.isUser ? 'user' : 'assistant', 'content': t.text},
      ];

  Never _fail(int code, String body) {
    final msg = _apiErrorMessage(body);
    if (code == 401) {
      throw const LlmException(
          'Invalid OpenAI API key — check platform.openai.com/api-keys.');
    }
    if (code == 404) {
      throw const LlmException(
          'Model not available to your account — pick another.');
    }
    if (code == 429) {
      throw const LlmException(
          'OpenAI rate limit or no credit — check your billing.');
    }
    throw LlmException('OpenAI error $code: $msg');
  }

  @override
  Future<ChatResult> complete({
    required String model,
    required List<ChatTurn> history,
    void Function(String delta)? onDelta,
  }) async {
    if (onDelta != null) return _streamed(model, history, onDelta);

    final res = await _post(_uri, _headers, {
      'model': model,
      'messages': _messages(history),
    });
    if (res.statusCode != 200) _fail(res.statusCode, res.body);

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

  Future<ChatResult> _streamed(
    String model,
    List<ChatTurn> history,
    void Function(String delta) onDelta,
  ) async {
    final client = http.Client();
    try {
      final res = await _postStream(client, _uri, _headers, {
        'model': model,
        'messages': _messages(history),
        'stream': true,
        // Asks OpenAI to attach real token usage to the final chunk.
        'stream_options': {'include_usage': true},
      });
      if (res.statusCode != 200) {
        _fail(res.statusCode, await res.stream.bytesToString());
      }

      final buf = StringBuffer();
      var input = 0;
      var output = 0;
      await for (final data in _sseDataLines(res)) {
        if (data == '[DONE]') break;
        final Map<String, dynamic> json;
        try {
          json = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final choices = json['choices'] as List? ?? [];
        if (choices.isNotEmpty) {
          final delta =
              ((choices.first as Map)['delta'] as Map?)?['content'] as String?;
          if (delta != null && delta.isNotEmpty) {
            buf.write(delta);
            onDelta(delta);
          }
        }
        final usage = json['usage'] as Map<String, dynamic>?;
        if (usage != null) {
          input = (usage['prompt_tokens'] as num?)?.toInt() ?? input;
          output = (usage['completion_tokens'] as num?)?.toInt() ?? output;
        }
      }
      return ChatResult(
        text: buf.toString().trim(),
        inputTokens: input,
        outputTokens: output,
      );
    } on TimeoutException {
      throw const LlmException('The response stream stalled — try again.');
    } finally {
      client.close();
    }
  }
}

// ── Anthropic ─────────────────────────────────────────────────────────────────

class _AnthropicClient implements LlmClient {
  _AnthropicClient(this.apiKey);
  final String apiKey;

  static final _uri = Uri.parse('https://api.anthropic.com/v1/messages');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        // Allows direct calls from the Flutter web build (CORS).
        'anthropic-dangerous-direct-browser-access': 'true',
      };

  Map<String, Object> _payload(String model, List<ChatTurn> history) => {
        'model': model,
        'max_tokens': 2048,
        'messages': [
          for (final t in history)
            {'role': t.isUser ? 'user' : 'assistant', 'content': t.text},
        ],
      };

  Never _fail(int code, String body) {
    final msg = _apiErrorMessage(body);
    if (code == 401) {
      throw const LlmException(
          'Invalid Anthropic API key — check console.anthropic.com.');
    }
    if (code == 404) {
      throw const LlmException('Model not found — pick another.');
    }
    if (code == 429) {
      throw const LlmException('Anthropic rate limit — wait and try again.');
    }
    throw LlmException('Anthropic error $code: $msg');
  }

  @override
  Future<ChatResult> complete({
    required String model,
    required List<ChatTurn> history,
    void Function(String delta)? onDelta,
  }) async {
    if (onDelta != null) return _streamed(model, history, onDelta);

    final res = await _post(_uri, _headers, _payload(model, history));
    if (res.statusCode != 200) _fail(res.statusCode, res.body);

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

  Future<ChatResult> _streamed(
    String model,
    List<ChatTurn> history,
    void Function(String delta) onDelta,
  ) async {
    final client = http.Client();
    try {
      final res = await _postStream(client, _uri, _headers, {
        ..._payload(model, history),
        'stream': true,
      });
      if (res.statusCode != 200) {
        _fail(res.statusCode, await res.stream.bytesToString());
      }

      final buf = StringBuffer();
      var input = 0;
      var output = 0;
      await for (final data in _sseDataLines(res)) {
        final Map<String, dynamic> json;
        try {
          json = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        switch (json['type']) {
          case 'message_start':
            final usage =
                ((json['message'] as Map?)?['usage'] as Map?) ?? {};
            input = (usage['input_tokens'] as num?)?.toInt() ?? input;
          case 'content_block_delta':
            final d = (json['delta'] as Map?)?['text'] as String?;
            if (d != null && d.isNotEmpty) {
              buf.write(d);
              onDelta(d);
            }
          case 'message_delta':
            final usage = json['usage'] as Map?;
            output = (usage?['output_tokens'] as num?)?.toInt() ?? output;
          case 'error':
            throw LlmException(
                'Anthropic error: ${(json['error'] as Map?)?['message'] ?? 'unknown'}');
        }
      }
      return ChatResult(
        text: buf.toString().trim(),
        inputTokens: input,
        outputTokens: output,
      );
    } on TimeoutException {
      throw const LlmException('The response stream stalled — try again.');
    } finally {
      client.close();
    }
  }
}
