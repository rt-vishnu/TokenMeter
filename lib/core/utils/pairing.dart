/// Connection details for a remote PromptPenny API server, parsed from either
/// a bare host URL or the full pairing string encoded in the Connect-screen QR
/// (e.g. `https://192.168.0.108:8765?key=<API_KEY>&fp=<FINGERPRINT>`).
class PairingInfo {
  const PairingInfo({required this.host, this.apiKey, this.fingerprint});

  /// Scheme + host + port only, with any query string stripped.
  final String host;

  /// API key from the `key` query param, if present.
  final String? apiKey;

  /// Pinned certificate fingerprint from the `fp` query param, if present.
  final String? fingerprint;

  static PairingInfo parse(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.queryParameters.isEmpty) {
      return PairingInfo(host: trimmed);
    }
    final host = Uri(
      scheme: uri.scheme.isEmpty ? null : uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
    return PairingInfo(
      host: host.isEmpty ? trimmed : host,
      apiKey: uri.queryParameters['key'],
      fingerprint: uri.queryParameters['fp'],
    );
  }
}
