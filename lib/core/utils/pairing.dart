/// Connection details for a remote PromptPenny API server, parsed from either
/// a bare host URL or a pairing string from the Connect-screen QR
/// (e.g. `https://192.168.0.108:8765?fp=<FINGERPRINT>`).
///
/// API keys are **not** embedded in pairing URLs. Enter the key separately on
/// the web client's Settings screen.
class PairingInfo {
  const PairingInfo({required this.host, this.apiKey, this.fingerprint});

  /// Scheme + host + port only, with any query string stripped.
  final String host;

  /// Legacy: API key from an old `key` query param (rejected by [parse]).
  final String? apiKey;

  /// Pinned certificate fingerprint from the `fp` query param, if present.
  final String? fingerprint;

  /// Builds a pairing URL/QR payload (endpoint + optional cert fingerprint).
  static String buildLink(String endpoint, {String? fingerprint}) {
    final base = Uri.parse(endpoint.trim());
    return base
        .replace(
          queryParameters: fingerprint != null && fingerprint.isNotEmpty
              ? {'fp': fingerprint}
              : {},
        )
        .toString();
  }

  static PairingInfo parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw PairingValidationException('URL is empty');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      throw PairingValidationException('Invalid URL');
    }

    if (uri.queryParameters.containsKey('key')) {
      throw PairingValidationException(
        'This pairing link includes an API key in the URL (old format). '
        'Copy the endpoint from Integration and enter the API key separately.',
      );
    }

    _validateSchemeAndHost(uri);

    final host = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();

    return PairingInfo(
      host: host,
      fingerprint: uri.queryParameters['fp'],
    );
  }

  static void _validateSchemeAndHost(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' &&
        !(scheme == 'http' &&
            (uri.host == '127.0.0.1' || uri.host == 'localhost'))) {
      throw PairingValidationException(
        'Only https:// URLs are allowed (http://127.0.0.1 or localhost for local dev)',
      );
    }

    final host = uri.host.toLowerCase();
    if (!_isPrivateOrLocalHost(host)) {
      throw PairingValidationException(
        'Host must be a private LAN address or localhost',
      );
    }
  }

  static bool _isPrivateOrLocalHost(String host) {
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList();
    if (octets.any((o) => o == null || o < 0 || o > 255)) return false;
    final a = octets[0]!;
    final b = octets[1]!;
    // 10.0.0.0/8
    if (a == 10) return true;
    // 172.16.0.0/12
    if (a == 172 && b >= 16 && b <= 31) return true;
    // 192.168.0.0/16
    if (a == 192 && b == 168) return true;
    return false;
  }
}

class PairingValidationException implements Exception {
  PairingValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}
