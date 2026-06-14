// Returns an http.Client that pins the local API server's self-signed
// certificate by SHA-256 fingerprint. Platform-specific: native pins via
// dart:io, web falls back to a plain client (the browser handles TLS trust).
export 'pinned_http_client_stub.dart'
    if (dart.library.io) 'pinned_http_client_io.dart';
