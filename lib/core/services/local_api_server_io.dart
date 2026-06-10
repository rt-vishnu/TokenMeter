import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../data/repositories/usage_repository_io.dart';
import '../constants/app_constants.dart';
import '../models/usage_payload.dart';
import 'pricing_repository.dart';
import 'settings_service.dart';

class LocalApiServer {
  LocalApiServer({
    required UsageRepository usageRepository,
    required PricingRepository pricingRepository,
    required SettingsService settingsService,
  })  : _usage = usageRepository,
        _pricing = pricingRepository,
        _settings = settingsService;

  final UsageRepository _usage;
  final PricingRepository _pricing;
  final SettingsService _settings;

  HttpServer? _server;
  String? _boundAddress;
  final _requestTimestamps = <DateTime>[];

  bool get isRunning => _server != null;
  String? get boundAddress => _boundAddress;
  int? get port => _server?.port;

  Future<void> start(String host, int port) async {
    await stop();

    final router = Router()
      ..get('/api/v1/health', _health)
      ..get('/api/v1/info', _info)
      ..get('/api/v1/models', _models)
      ..get('/api/v1/usage', _getUsage)
      ..post('/api/v1/usage', _postUsage)
      ..post('/api/v1/estimate', _postEstimate);

    final handler = Pipeline()
        .addMiddleware(_corsMiddleware)
        .addMiddleware(_rateLimitMiddleware)
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, host, port);
    _boundAddress = host;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _boundAddress = null;
  }

  Response _health(Request request) {
    return Response.ok(
      jsonEncode({'status': 'ok', 'app': AppConstants.appName}),
      headers: _jsonHeaders,
    );
  }

  Response _info(Request request) {
    return Response.ok(
      jsonEncode({
        'ip': _boundAddress,
        'port': _server?.port,
        'app_version': AppConstants.appVersion,
      }),
      headers: _jsonHeaders,
    );
  }

  Response _models(Request request) {
    return Response.ok(
      jsonEncode({'models': _pricing.toApiList()}),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _getUsage(Request request) async {
    final authError = _checkAuth(request);
    if (authError != null) return authError;

    final params = request.url.queryParameters;
    final from =
        params['from'] != null ? DateTime.tryParse(params['from']!) : null;
    final to = params['to'] != null ? DateTime.tryParse(params['to']!) : null;
    final source = params['source'];
    final model = params['model'];

    final records = await _usage.getRecords(
      from: from,
      to: to,
      source: source,
      model: model,
    );

    return Response.ok(
      jsonEncode({'records': records.map((r) => r.toJson()).toList()}),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _postUsage(Request request) async {
    final authError = _checkAuth(request);
    if (authError != null) return authError;

    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final payload = UsagePayload.fromJson(json);
      final record = await _usage.recordUsage(payload);
      return Response.ok(
        jsonEncode(record.toJson()),
        headers: _jsonHeaders,
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: _jsonHeaders,
      );
    }
  }

  Future<Response> _postEstimate(Request request) async {
    final authError = _checkAuth(request);
    if (authError != null) return authError;

    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final payload = EstimatePayload.fromJson(json);
      final result = await _usage.estimate(payload);
      return Response.ok(
        jsonEncode(result),
        headers: _jsonHeaders,
      );
    } catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.toString()}),
        headers: _jsonHeaders,
      );
    }
  }

  Response? _checkAuth(Request request) {
    final header = request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) {
      return Response.forbidden(
        jsonEncode({'error': 'Missing or invalid Authorization header'}),
        headers: _jsonHeaders,
      );
    }
    final token = header.substring(7);
    if (token != _settings.apiKey) {
      return Response.forbidden(
        jsonEncode({'error': 'Invalid API key'}),
        headers: _jsonHeaders,
      );
    }
    return null;
  }

  Middleware get _corsMiddleware => (Handler innerHandler) {
        return (Request request) async {
          final origin = request.headers['origin'] ?? '';
          // Only allow browser requests originating from localhost/127.0.0.1.
          final isLocalOrigin = origin.contains('localhost') ||
              origin.contains('127.0.0.1');
          final corsHeaders = isLocalOrigin
              ? {..._baseCorsHeaders, 'Access-Control-Allow-Origin': origin}
              : _baseCorsHeaders;

          if (request.method == 'OPTIONS') {
            return Response.ok('', headers: corsHeaders);
          }
          final response = await innerHandler(request);
          return response.change(headers: corsHeaders);
        };
      };

  Middleware get _rateLimitMiddleware => (Handler innerHandler) {
        return (Request request) async {
          final now = DateTime.now();
          _requestTimestamps.removeWhere(
            (t) => now.difference(t).inMinutes >= 1,
          );
          if (_requestTimestamps.length >= AppConstants.rateLimitPerMinute) {
            return Response(
              429,
              body: jsonEncode({'error': 'Rate limit exceeded'}),
              headers: _jsonHeaders,
            );
          }
          _requestTimestamps.add(now);
          return innerHandler(request);
        };
      };

  static const _jsonHeaders = {'Content-Type': 'application/json'};
  // Origin header is set dynamically in _corsMiddleware for localhost only.
  static const _baseCorsHeaders = {
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Content-Type': 'application/json',
  };
}
