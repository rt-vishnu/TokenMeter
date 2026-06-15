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
import 'tls_certificate_service.dart';

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
  final _requestTimestampsByClient = <String, List<DateTime>>{};
  final _tls = TlsCertificateService();

  static const portFallbackCount = 4;
  // 2-second window to drain in-flight requests before force-closing.
  static const _drainTimeout = Duration(seconds: 2);

  static bool isPortBindError(Object error) => error is SocketException;

  bool get isRunning => _server != null;
  String? get boundAddress => _boundAddress;
  int? get port => _server?.port;
  // Set when a fallback port was used instead of the requested one.
  int? get requestedPort => _requestedPort;
  int? _requestedPort;

  /// 'https' when serving with TLS, otherwise 'http'.
  String get scheme => _scheme;
  String _scheme = 'http';

  /// SHA-256 fingerprint of the served certificate (HTTPS only), for pinning.
  String? get fingerprint => _fingerprint;
  String? _fingerprint;

  /// Tries [port] first, then up to [_portFallbackCount] successive ports.
  /// Returns the port actually bound, or throws if all attempts fail.
  ///
  /// When [useHttps] is set, serves over TLS using a cached self-signed
  /// certificate (minting and persisting one on first use).
  Future<int> start(String host, int port, {bool useHttps = false}) async {
    await stop();

    SecurityContext? securityContext;
    if (useHttps) {
      final tls = await _loadOrCreateTls(host);
      securityContext = tls.securityContext;
      _scheme = 'https';
      _fingerprint = tls.fingerprint;
    } else {
      _scheme = 'http';
      _fingerprint = null;
    }

    final router = Router()
      ..get('/', _root)
      ..get('/api/v1/health', _health)
      ..get('/api/v1/info', _info)
      ..get('/api/v1/models', _models)
      ..get('/api/v1/usage', _getUsage)
      ..post('/api/v1/usage', _postUsage)
      ..delete('/api/v1/usage/<id>', _deleteUsage)
      ..get('/api/v1/stats', _getStats)
      ..post('/api/v1/estimate', _postEstimate);

    final handler = Pipeline()
        .addMiddleware(_corsMiddleware)
        .addMiddleware(_rateLimitMiddleware)
        .addMiddleware(_authMiddleware)
        .addHandler(router.call);

    Object? lastError;
    for (var attempt = 0; attempt <= portFallbackCount; attempt++) {
      final candidate = port + attempt;
      try {
        _server = await shelf_io.serve(
          handler,
          host,
          candidate,
          securityContext: securityContext,
        );
        _boundAddress = host;
        _requestedPort = (attempt == 0) ? null : port;
        return candidate;
      } on SocketException catch (e) {
        lastError = e;
      }
    }
    throw lastError!;
  }

  /// Reuses the cached cert/key when present (so the pinned fingerprint stays
  /// stable across restarts); otherwise mints a fresh one and persists it.
  Future<TlsMaterial> _loadOrCreateTls(String host) async {
    final certPem = _settings.tlsCertPem;
    final keyPem = _settings.tlsKeyPem;
    if (certPem != null && keyPem != null) {
      return _tls.fromPem(certPem, keyPem);
    }
    final material = await _tls.generate(ip: host);
    await _settings.setTlsMaterial(material.certPem, material.keyPem);
    return material;
  }

  /// Gracefully drains in-flight requests before closing.
  Future<void> stop() async {
    final server = _server;
    if (server == null) return;
    // Try graceful drain first; fall back to force after timeout.
    await server.close(force: false).timeout(
      _drainTimeout,
      onTimeout: () => server.close(force: true),
    );
    _server = null;
    _boundAddress = null;
    _requestedPort = null;
  }

  Response _root(Request request) {
    final port = _server?.port ?? '';
    final scheme = _scheme;
    final html = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${AppConstants.appName} – API Server</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 480px; margin: 80px auto; padding: 0 24px; color: #1c1c1e; background: #f2f2f7; }
    .card { background: white; border-radius: 18px; padding: 32px; box-shadow: 0 2px 12px rgba(0,0,0,.08); }
    h1 { font-size: 22px; margin: 0 0 4px; }
    .badge { display: inline-block; background: #d1fae5; color: #065f46; font-size: 12px; font-weight: 700; padding: 3px 10px; border-radius: 99px; margin-bottom: 20px; }
    p { margin: 0 0 12px; font-size: 15px; line-height: 1.5; color: #3c3c43; }
    code { background: #f2f2f7; border-radius: 6px; padding: 2px 6px; font-size: 13px; }
    .step { display: flex; gap: 12px; margin-bottom: 10px; align-items: flex-start; }
    .num { background: #10b981; color: white; border-radius: 50%; width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 800; flex-shrink: 0; margin-top: 1px; }
    .note { font-size: 13px; color: #8e8e93; margin-top: 20px; border-top: 1px solid #f2f2f7; padding-top: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>${AppConstants.appName}</h1>
    <div class="badge">API Server Running</div>
    <p>This device is sharing token-usage data over your local network on <code>$scheme://&lt;device-ip&gt;:$port</code>.</p>
    <p>This is not a website — it is a local REST API meant to be used with the <strong>${AppConstants.appName} app</strong>, not a browser.</p>
    <p style="margin-top:20px; font-weight:700;">How to connect from another device:</p>
    <div class="step"><div class="num">1</div><p style="margin:0">Install <strong>${AppConstants.appName}</strong> on the other device.</p></div>
    <div class="step"><div class="num">2</div><p style="margin:0">Open the <strong>Connect</strong> screen and tap <strong>Scan QR to connect</strong>.</p></div>
    <div class="step"><div class="num">3</div><p style="margin:0">Point it at the QR on this device — then enter the API key shown on this device's Connect screen.</p></div>
    <p class="note">API key is required via <code>Authorization: Bearer &lt;key&gt;</code> on all endpoints except <code>/api/v1/health</code>. The QR does <em>not</em> contain the key.</p>
  </div>
</body>
</html>''';
    return Response.ok(html, headers: {'Content-Type': 'text/html; charset=utf-8'});
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
    final params = request.url.queryParameters;
    final from = params['from'] != null ? DateTime.tryParse(params['from']!) : null;
    final to = params['to'] != null ? DateTime.tryParse(params['to']!) : null;
    final source = params['source'];
    final model = params['model'];
    final limit = int.tryParse(params['limit'] ?? '') ?? 200;
    final offset = int.tryParse(params['offset'] ?? '') ?? 0;

    if (limit < 1 || limit > 1000 || offset < 0) {
      return Response.badRequest(
        body: jsonEncode({'error': 'limit must be 1–1000 and offset ≥ 0'}),
        headers: _jsonHeaders,
      );
    }

    final records = await _usage.getRecordsPaged(
      from: from,
      to: to,
      source: source,
      model: model,
      limit: limit,
      offset: offset,
    );
    final total = await _usage.countRecords();

    return Response.ok(
      jsonEncode({
        'records': records.map((r) => r.toJson()).toList(),
        'total': total,
        'limit': limit,
        'offset': offset,
      }),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _deleteUsage(Request request, String id) async {
    final deleted = await _usage.deleteRecord(id);
    if (!deleted) {
      return Response.notFound(
        jsonEncode({'error': 'Record not found'}),
        headers: _jsonHeaders,
      );
    }
    return Response.ok(
      jsonEncode({'deleted': true, 'id': id}),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _getStats(Request request) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    final allRecords = await _usage.getRecords();

    double todayCost = 0, weekCost = 0, monthCost = 0;
    int todayTokens = 0, weekTokens = 0, monthTokens = 0;
    int todayReqs = 0, weekReqs = 0, monthReqs = 0;

    for (final r in allRecords) {
      if (!r.createdAt.isBefore(startOfMonth)) {
        monthCost += r.costUsd;
        monthTokens += r.totalTokens;
        monthReqs++;
      }
      if (!r.createdAt.isBefore(startOfWeek)) {
        weekCost += r.costUsd;
        weekTokens += r.totalTokens;
        weekReqs++;
      }
      if (!r.createdAt.isBefore(startOfDay)) {
        todayCost += r.costUsd;
        todayTokens += r.totalTokens;
        todayReqs++;
      }
    }

    return Response.ok(
      jsonEncode({
        'today': {'cost': todayCost, 'tokens': todayTokens, 'requests': todayReqs},
        'week': {'cost': weekCost, 'tokens': weekTokens, 'requests': weekReqs},
        'month': {'cost': monthCost, 'tokens': monthTokens, 'requests': monthReqs},
      }),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _postUsage(Request request) async {
    try {
      final body = await request.readAsString();
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } on FormatException {
        return Response.badRequest(
          body: jsonEncode({'error': 'Invalid JSON body'}),
          headers: _jsonHeaders,
        );
      }
      final payload = UsagePayload.fromJson(json);
      final record = await _usage.recordUsage(payload);
      return Response.ok(
        jsonEncode(record.toJson()),
        headers: _jsonHeaders,
      );
    } on ArgumentError catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.message}),
        headers: _jsonHeaders,
      );
    } catch (_) {
      return Response.badRequest(
        body: jsonEncode({'error': 'An unexpected error occurred'}),
        headers: _jsonHeaders,
      );
    }
  }

  Future<Response> _postEstimate(Request request) async {
    try {
      final body = await request.readAsString();
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } on FormatException {
        return Response.badRequest(
          body: jsonEncode({'error': 'Invalid JSON body'}),
          headers: _jsonHeaders,
        );
      }
      final payload = EstimatePayload.fromJson(json);
      final result = await _usage.estimate(payload);
      return Response.ok(
        jsonEncode(result),
        headers: _jsonHeaders,
      );
    } on ArgumentError catch (e) {
      return Response.badRequest(
        body: jsonEncode({'error': e.message}),
        headers: _jsonHeaders,
      );
    } catch (_) {
      return Response.badRequest(
        body: jsonEncode({'error': 'An unexpected error occurred'}),
        headers: _jsonHeaders,
      );
    }
  }

  /// Length-independent-result comparison to avoid leaking the API key via
  /// response timing. (The length itself isn't secret.)
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  // Root and health are public; all other routes require the API key.
  static const _publicPaths = {'', 'api/v1/health'};

  Middleware get _authMiddleware => (Handler innerHandler) {
        return (Request request) async {
          if (_publicPaths.contains(request.url.path)) {
            return innerHandler(request);
          }
          final header = request.headers['authorization'];
          if (header == null || !header.startsWith('Bearer ')) {
            return Response.forbidden(
              jsonEncode({'error': 'Missing or invalid Authorization header'}),
              headers: _jsonHeaders,
            );
          }
          final token = header.substring(7);
          if (!_constantTimeEquals(token, _settings.apiKey)) {
            return Response.forbidden(
              jsonEncode({'error': 'Invalid API key'}),
              headers: _jsonHeaders,
            );
          }
          return innerHandler(request);
        };
      };

  Middleware get _corsMiddleware => (Handler innerHandler) {
        return (Request request) async {
          final origin = request.headers['origin'] ?? '';
          // Only reflect a real localhost origin — exact host match, not a
          // substring (which "http://evil.com/#localhost" would satisfy).
          final originUri = Uri.tryParse(origin);
          final isLocalOrigin = originUri != null &&
              (originUri.scheme == 'http' || originUri.scheme == 'https') &&
              (originUri.host == 'localhost' || originUri.host == '127.0.0.1');
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
          final clientId = _clientId(request);
          final timestamps =
              _requestTimestampsByClient.putIfAbsent(clientId, () => []);
          timestamps.removeWhere(
            (t) => now.difference(t).inMinutes >= 1,
          );
          if (timestamps.length >= AppConstants.rateLimitPerMinute) {
            return Response(
              429,
              body: jsonEncode({'error': 'Rate limit exceeded'}),
              headers: _jsonHeaders,
            );
          }
          timestamps.add(now);
          return innerHandler(request);
        };
      };

  static String _clientId(Request request) {
    final info = request.context['shelf.io.connection_info'];
    if (info is HttpConnectionInfo) {
      return info.remoteAddress.address;
    }
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.isNotEmpty) {
      return forwarded.split(',').first.trim();
    }
    return 'unknown';
  }

  static const _jsonHeaders = {'Content-Type': 'application/json'};
  // Content-Type is NOT included here — each handler sets its own.
  // Origin header is set dynamically in _corsMiddleware for localhost only.
  static const _baseCorsHeaders = {
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  };
}
