import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Providers that expose a billing/usage API we can read actual spend from.
/// Gemini is listed but unsupported — Google has no public billing API.
enum BillingProvider {
  openrouter,
  openai,
  anthropic,
  gemini,
  awsBedrock;

  String get id => name;

  String get displayName => switch (this) {
        BillingProvider.openrouter => 'OpenRouter',
        BillingProvider.openai => 'OpenAI',
        BillingProvider.anthropic => 'Anthropic',
        BillingProvider.gemini => 'Google Gemini',
        BillingProvider.awsBedrock => 'AWS Bedrock',
      };

  /// The `provider` value in the pricing data, for the Tracked-vs-Actual strip.
  String get pricingProvider => switch (this) {
        BillingProvider.openrouter => 'openrouter',
        BillingProvider.openai => 'openai',
        BillingProvider.anthropic => 'anthropic',
        BillingProvider.gemini => 'google',
        BillingProvider.awsBedrock => 'aws-bedrock',
      };

  /// Where the user creates the key needed for billing reads.
  String get keySetupUrl => switch (this) {
        BillingProvider.openrouter => 'https://openrouter.ai/settings/keys',
        BillingProvider.openai =>
          'https://platform.openai.com/settings/organization/admin-keys',
        BillingProvider.anthropic =>
          'https://console.anthropic.com/settings/keys',
        BillingProvider.gemini => 'https://console.cloud.google.com/billing',
        BillingProvider.awsBedrock =>
          'https://console.aws.amazon.com/cost-management/home#/cost-explorer',
      };

  /// Short note about the kind of key required.
  String get keyHint => switch (this) {
        BillingProvider.openrouter =>
          'Create a free provisioning key at openrouter.ai → Settings → Keys. '
              'It only reads your credit balance — it can\'t spend.',
        BillingProvider.openai =>
          'Requires an organization Admin key (only an org owner can create '
              'one). Reads cost only — separate from your chat key.',
        BillingProvider.anthropic =>
          'Requires an organization Admin key (sk-ant-admin…, created by an '
              'org admin). Reads cost only — separate from your chat key.',
        BillingProvider.gemini => '',
        BillingProvider.awsBedrock =>
          'First enable Cost Explorer in your AWS Billing console (one-time). '
              'Then create an IAM user, attach the AWSBillingReadOnlyAccess '
              'managed policy, and generate an Access Key.',
      };

  /// True when this provider uses AWS-style dual credentials (key ID + secret)
  /// rather than a single API key string.
  bool get requiresAwsCredentials => this == BillingProvider.awsBedrock;
}

enum BillingStatus { connected, notConnected, unsupported, error }

/// Normalized actual-spend snapshot for one provider.
class ProviderActuals {
  const ProviderActuals({
    required this.provider,
    required this.status,
    this.balance,
    this.totalUsed,
    this.totalCredits,
    this.monthCost,
    this.currency = 'USD',
    this.lastSynced,
    this.errorMessage,
  });

  final BillingProvider provider;
  final BillingStatus status;

  /// Remaining credit = totalCredits - totalUsed (when the provider reports it).
  final double? balance;
  final double? totalUsed;
  final double? totalCredits;

  /// Actual spend for the current calendar month, in USD (when the provider
  /// reports cost rather than a prepaid balance).
  final double? monthCost;
  final String currency;
  final DateTime? lastSynced;
  final String? errorMessage;

  factory ProviderActuals.notConnected(BillingProvider p) =>
      ProviderActuals(provider: p, status: BillingStatus.notConnected);

  factory ProviderActuals.unsupported(BillingProvider p) =>
      ProviderActuals(provider: p, status: BillingStatus.unsupported);

  factory ProviderActuals.error(BillingProvider p, String message) =>
      ProviderActuals(
        provider: p,
        status: BillingStatus.error,
        errorMessage: message,
      );

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'status': status.name,
        if (balance != null) 'balance': balance,
        if (totalUsed != null) 'totalUsed': totalUsed,
        if (totalCredits != null) 'totalCredits': totalCredits,
        if (monthCost != null) 'monthCost': monthCost,
        'currency': currency,
        if (lastSynced != null) 'lastSynced': lastSynced!.toIso8601String(),
        if (errorMessage != null) 'errorMessage': errorMessage,
      };

  factory ProviderActuals.fromJson(Map<String, dynamic> json) {
    final provider = BillingProvider.values.firstWhere(
      (p) => p.name == json['provider'],
      orElse: () => BillingProvider.openrouter,
    );
    final status = BillingStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => BillingStatus.error,
    );
    return ProviderActuals(
      provider: provider,
      status: status,
      balance: (json['balance'] as num?)?.toDouble(),
      totalUsed: (json['totalUsed'] as num?)?.toDouble(),
      totalCredits: (json['totalCredits'] as num?)?.toDouble(),
      monthCost: (json['monthCost'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      lastSynced: json['lastSynced'] != null
          ? DateTime.tryParse(json['lastSynced'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

abstract class BillingClient {
  Future<ProviderActuals> fetch();

  factory BillingClient.forProvider(
    BillingProvider provider, {
    required String apiKey,
  }) {
    switch (provider) {
      case BillingProvider.openrouter:
        return _OpenRouterBillingClient(apiKey);
      case BillingProvider.openai:
        return _OpenAiBillingClient(apiKey);
      case BillingProvider.anthropic:
        return _AnthropicBillingClient(apiKey);
      case BillingProvider.gemini:
        return _UnsupportedBillingClient(BillingProvider.gemini);
      case BillingProvider.awsBedrock:
        return _AwsBedrockBillingClient(apiKey);
    }
  }
}

class _UnsupportedBillingClient implements BillingClient {
  _UnsupportedBillingClient(this.provider);
  final BillingProvider provider;

  @override
  Future<ProviderActuals> fetch() async => ProviderActuals.unsupported(provider);
}

/// Unix seconds for the start of the current calendar month (UTC).
int _startOfMonthUnix() {
  final now = DateTime.now().toUtc();
  return DateTime.utc(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
}

/// RFC 3339 timestamp for the start of the current calendar month (UTC).
String _startOfMonthIso() {
  final now = DateTime.now().toUtc();
  return DateTime.utc(now.year, now.month, 1).toIso8601String();
}

// ── OpenRouter ────────────────────────────────────────────────────────────────

class _OpenRouterBillingClient implements BillingClient {
  _OpenRouterBillingClient(this.apiKey);
  final String apiKey;

  static final _uri = Uri.parse('https://openrouter.ai/api/v1/credits');

  @override
  Future<ProviderActuals> fetch() async {
    final http.Response res;
    try {
      res = await http.get(
        _uri,
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      return ProviderActuals.error(
        BillingProvider.openrouter,
        'Network error — could not reach OpenRouter.',
      );
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      return ProviderActuals.error(
        BillingProvider.openrouter,
        'Key rejected. Use a provisioning key that can read credits '
        '(openrouter.ai → Settings → Keys).',
      );
    }
    if (res.statusCode != 200) {
      return ProviderActuals.error(
        BillingProvider.openrouter,
        'OpenRouter error ${res.statusCode}.',
      );
    }

    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>;
      final credits = (data['total_credits'] as num?)?.toDouble() ?? 0;
      final used = (data['total_usage'] as num?)?.toDouble() ?? 0;
      return ProviderActuals(
        provider: BillingProvider.openrouter,
        status: BillingStatus.connected,
        totalCredits: credits,
        totalUsed: used,
        balance: credits - used,
        lastSynced: DateTime.now(),
      );
    } catch (_) {
      return ProviderActuals.error(
        BillingProvider.openrouter,
        'Unexpected response from OpenRouter.',
      );
    }
  }
}

// ── OpenAI (organization Costs API, admin key) ─────────────────────────────────

class _OpenAiBillingClient implements BillingClient {
  _OpenAiBillingClient(this.apiKey);
  final String apiKey;

  @override
  Future<ProviderActuals> fetch() async {
    final uri = Uri.parse('https://api.openai.com/v1/organization/costs')
        .replace(queryParameters: {
      'start_time': '${_startOfMonthUnix()}',
      'bucket_width': '1d',
      'limit': '31',
    });

    final http.Response res;
    try {
      res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 25));
    } catch (_) {
      return ProviderActuals.error(
          BillingProvider.openai, 'Network error — could not reach OpenAI.');
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      return ProviderActuals.error(
        BillingProvider.openai,
        'Key rejected. The Costs API needs an organization Admin key.',
      );
    }
    if (res.statusCode == 404) {
      return ProviderActuals.error(
        BillingProvider.openai,
        'Costs API not available for this account/key.',
      );
    }
    if (res.statusCode != 200) {
      return ProviderActuals.error(
          BillingProvider.openai, 'OpenAI error ${res.statusCode}.');
    }

    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final buckets = json['data'] as List<dynamic>? ?? [];
      var total = 0.0;
      for (final b in buckets) {
        final results = (b as Map<String, dynamic>)['results'] as List? ?? [];
        for (final r in results) {
          final amount = (r as Map<String, dynamic>)['amount'] as Map?;
          total += (amount?['value'] as num?)?.toDouble() ?? 0;
        }
      }
      return ProviderActuals(
        provider: BillingProvider.openai,
        status: BillingStatus.connected,
        monthCost: total,
        lastSynced: DateTime.now(),
      );
    } catch (_) {
      return ProviderActuals.error(
          BillingProvider.openai, 'Unexpected response from OpenAI.');
    }
  }
}

// ── Anthropic (organization Cost Report, admin key) ────────────────────────────

class _AnthropicBillingClient implements BillingClient {
  _AnthropicBillingClient(this.apiKey);
  final String apiKey;

  @override
  Future<ProviderActuals> fetch() async {
    final uri = Uri.parse('https://api.anthropic.com/v1/organizations/cost_report')
        .replace(queryParameters: {
      'starting_at': _startOfMonthIso(),
      'bucket_width': '1d',
      'limit': '31',
    });

    final http.Response res;
    try {
      res = await http.get(uri, headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      }).timeout(const Duration(seconds: 25));
    } catch (_) {
      return ProviderActuals.error(
          BillingProvider.anthropic, 'Network error — could not reach Anthropic.');
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      return ProviderActuals.error(
        BillingProvider.anthropic,
        'Key rejected. The Cost Report needs an organization Admin key '
        '(sk-ant-admin…).',
      );
    }
    if (res.statusCode != 200) {
      return ProviderActuals.error(
          BillingProvider.anthropic, 'Anthropic error ${res.statusCode}.');
    }

    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final buckets = json['data'] as List<dynamic>? ?? [];
      var totalCents = 0.0;
      for (final b in buckets) {
        final results = (b as Map<String, dynamic>)['results'] as List? ?? [];
        for (final r in results) {
          // Anthropic reports amount in cents as a decimal string.
          final raw = (r as Map<String, dynamic>)['amount'];
          totalCents += double.tryParse('$raw') ?? 0;
        }
      }
      return ProviderActuals(
        provider: BillingProvider.anthropic,
        status: BillingStatus.connected,
        monthCost: totalCents / 100,
        lastSynced: DateTime.now(),
      );
    } catch (_) {
      return ProviderActuals.error(
          BillingProvider.anthropic, 'Unexpected response from Anthropic.');
    }
  }
}

// ── AWS SigV4 (minimal, Cost Explorer only) ───────────────────────────────────

class _AwsSigV4 {
  static const _region = 'us-east-1';
  static const _service = 'ce';
  static const _host = 'ce.us-east-1.amazonaws.com';

  static List<int> _hmac(List<int> key, List<int> data) =>
      Hmac(sha256, key).convert(data).bytes;

  static String _hexEncode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static String _sha256Hex(String s) =>
      _hexEncode(sha256.convert(utf8.encode(s)).bytes);

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  static String _dateStamp(DateTime utc) =>
      '${utc.year.toString().padLeft(4, '0')}${_pad2(utc.month)}${_pad2(utc.day)}';

  static String _amzDate(DateTime utc) =>
      '${_dateStamp(utc)}T${_pad2(utc.hour)}${_pad2(utc.minute)}${_pad2(utc.second)}Z';

  /// Returns signed headers for a POST to the Cost Explorer endpoint.
  static Map<String, String> signCeRequest({
    required String accessKeyId,
    required String secretKey,
    required String body,
    DateTime? now,
  }) {
    final utc = (now ?? DateTime.now()).toUtc();
    final dateStamp = _dateStamp(utc);
    final amzDate = _amzDate(utc);
    const contentType = 'application/x-amz-json-1.1';
    const target = 'AWSInsightsIndexService.GetCostAndUsage';

    final payloadHash = _sha256Hex(body);

    // Canonical headers must be sorted alphabetically by header name (lowercase).
    final canonicalHeaders =
        'content-type:$contentType\n'
        'host:$_host\n'
        'x-amz-date:$amzDate\n'
        'x-amz-target:$target\n';
    const signedHeaders = 'content-type;host;x-amz-date;x-amz-target';

    final canonicalRequest = [
      'POST', '/', '',
      canonicalHeaders, signedHeaders, payloadHash,
    ].join('\n');

    final credScope = '$dateStamp/$_region/$_service/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credScope,
      _sha256Hex(canonicalRequest),
    ].join('\n');

    final kDate = _hmac(utf8.encode('AWS4$secretKey'), utf8.encode(dateStamp));
    final kRegion = _hmac(kDate, utf8.encode(_region));
    final kService = _hmac(kRegion, utf8.encode(_service));
    final kSigning = _hmac(kService, utf8.encode('aws4_request'));
    final signature = _hexEncode(_hmac(kSigning, utf8.encode(stringToSign)));

    return {
      'Content-Type': contentType,
      'X-Amz-Date': amzDate,
      'X-Amz-Target': target,
      'Authorization':
          'AWS4-HMAC-SHA256 '
          'Credential=$accessKeyId/$credScope, '
          'SignedHeaders=$signedHeaders, '
          'Signature=$signature',
    };
  }
}

// ── AWS Bedrock (Cost Explorer) ───────────────────────────────────────────────

/// Credentials are stored as JSON: {"accessKeyId":"AKIA…","secretAccessKey":"…"}
class _AwsBedrockBillingClient implements BillingClient {
  _AwsBedrockBillingClient(this._credJson);
  final String _credJson;

  static final _uri = Uri.https(_AwsSigV4._host, '/');

  @override
  Future<ProviderActuals> fetch() async {
    final Map<String, dynamic> creds;
    try {
      creds = jsonDecode(_credJson) as Map<String, dynamic>;
    } catch (_) {
      return ProviderActuals.error(
          BillingProvider.awsBedrock, 'Invalid credentials — reconnect AWS Bedrock.');
    }

    final accessKeyId = (creds['accessKeyId'] as String? ?? '').trim();
    final secretKey = (creds['secretAccessKey'] as String? ?? '').trim();
    if (accessKeyId.isEmpty || secretKey.isEmpty) {
      return ProviderActuals.error(
          BillingProvider.awsBedrock,
          'Missing Access Key ID or Secret Access Key — reconnect.');
    }

    // Request the current calendar month. End is the first of next month
    // (exclusive), so we always capture the full partial month.
    final now = DateTime.now().toUtc();
    final nextMonth = DateTime.utc(now.year, now.month + 1, 1);
    String fmtDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}'
        '-${d.month.toString().padLeft(2, '0')}'
        '-${d.day.toString().padLeft(2, '0')}';

    final body = jsonEncode({
      'TimePeriod': {
        'Start': fmtDate(DateTime.utc(now.year, now.month, 1)),
        'End': fmtDate(nextMonth),
      },
      'Granularity': 'MONTHLY',
      'Filter': {
        'Dimensions': {
          'Key': 'SERVICE',
          'Values': ['Amazon Bedrock'],
        },
      },
      'Metrics': ['UnblendedCost'],
    });

    final headers = _AwsSigV4.signCeRequest(
      accessKeyId: accessKeyId,
      secretKey: secretKey,
      body: body,
    );

    final http.Response res;
    try {
      res = await http
          .post(_uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      return ProviderActuals.error(
          BillingProvider.awsBedrock, 'Network error — could not reach AWS.');
    }

    if (res.statusCode == 400 || res.statusCode == 401) {
      String? msg;
      try {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        msg = j['message'] as String? ?? j['Message'] as String?;
      } catch (_) {}
      return ProviderActuals.error(
          BillingProvider.awsBedrock,
          msg != null ? 'AWS: $msg' : 'Invalid credentials (${res.statusCode}).');
    }
    if (res.statusCode == 403) {
      return ProviderActuals.error(
          BillingProvider.awsBedrock,
          'Access denied. Ensure the IAM user has the ce:GetCostAndUsage permission.');
    }
    if (res.statusCode != 200) {
      return ProviderActuals.error(
          BillingProvider.awsBedrock, 'AWS error ${res.statusCode}.');
    }

    try {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final results = j['ResultsByTime'] as List<dynamic>? ?? [];
      var total = 0.0;
      for (final r in results) {
        final totalMap = (r as Map<String, dynamic>)['Total'] as Map?;
        final cost = totalMap?['UnblendedCost'] as Map?;
        total += double.tryParse(cost?['Amount'] as String? ?? '') ?? 0;
      }
      return ProviderActuals(
        provider: BillingProvider.awsBedrock,
        status: BillingStatus.connected,
        monthCost: total,
        lastSynced: DateTime.now(),
      );
    } catch (_) {
      return ProviderActuals.error(
          BillingProvider.awsBedrock,
          'Unexpected response from AWS Cost Explorer.');
    }
  }
}
