import 'dart:convert';

import 'package:http/http.dart' as http;

/// Lightweight client for reporting token usage to PromptPenny.
class PromptPennyClient {
  PromptPennyClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _http;

  Uri _uri(String path) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalized$path');
  }

  Future<Map<String, dynamic>> reportUsage({
    required String model,
    required int inputTokens,
    required int outputTokens,
    String source = 'dart',
    String? sessionId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final response = await _http.post(
      _uri('/api/v1/usage'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'input_tokens': inputTokens,
        'output_tokens': outputTokens,
        'source': source,
        if (sessionId != null) 'session_id': sessionId,
        'metadata': metadata,
      }),
    );

    if (response.statusCode != 200) {
      throw PromptPennyException(
        'Failed to report usage: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> estimate({
    required String model,
    int? inputTokens,
    int? outputTokens,
    String? promptText,
    String? completionText,
  }) async {
    final response = await _http.post(
      _uri('/api/v1/estimate'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        if (inputTokens != null) 'input_tokens': inputTokens,
        if (outputTokens != null) 'output_tokens': outputTokens,
        if (promptText != null) 'prompt_text': promptText,
        if (completionText != null) 'completion_text': completionText,
      }),
    );

    if (response.statusCode != 200) {
      throw PromptPennyException(
        'Failed to estimate: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _http.get(_uri('/api/v1/health'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class PromptPennyException implements Exception {
  PromptPennyException(this.message);
  final String message;

  @override
  String toString() => 'PromptPennyException: $message';
}
