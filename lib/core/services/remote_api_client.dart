import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/usage_payload.dart';
import '../models/usage_record.dart';

class RemoteApiClient {
  RemoteApiClient({
    required this.baseUrl,
    required this.apiKey,
  });

  final String baseUrl;
  final String apiKey;

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalized$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

  Future<bool> healthCheck() async {
    try {
      final response = await http.get(_uri('/api/v1/health'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<UsageRecord>> getUsage({
    DateTime? from,
    DateTime? to,
    String? source,
    String? model,
  }) async {
    final query = <String, String>{};
    if (from != null) query['from'] = from.toUtc().toIso8601String();
    if (to != null) query['to'] = to.toUtc().toIso8601String();
    if (source != null) query['source'] = source;
    if (model != null) query['model'] = model;

    final response = await http.get(
      _uri('/api/v1/usage', query.isEmpty ? null : query),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch usage: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final records = json['records'] as List<dynamic>;
    return records
        .map((r) => UsageRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<UsageRecord> postUsage(UsagePayload payload) async {
    final response = await http.post(
      _uri('/api/v1/usage'),
      headers: _headers,
      body: jsonEncode({
        'model': payload.model,
        'input_tokens': payload.inputTokens,
        'output_tokens': payload.outputTokens,
        'source': payload.source,
        if (payload.sessionId != null) 'session_id': payload.sessionId,
        if (payload.timestamp != null)
          'timestamp': payload.timestamp!.toUtc().toIso8601String(),
        'metadata': payload.metadata,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to post usage: ${response.statusCode}');
    }
    return UsageRecord.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> estimate(EstimatePayload payload) async {
    final response = await http.post(
      _uri('/api/v1/estimate'),
      headers: _headers,
      body: jsonEncode({
        'model': payload.model,
        if (payload.inputTokens != null)
          'input_tokens': payload.inputTokens,
        if (payload.outputTokens != null)
          'output_tokens': payload.outputTokens,
        if (payload.promptText != null) 'prompt_text': payload.promptText,
        if (payload.completionText != null)
          'completion_text': payload.completionText,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to estimate: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getModels() async {
    final response = await http.get(_uri('/api/v1/models'));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch models: ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return (json['models'] as List<dynamic>)
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
  }
}
