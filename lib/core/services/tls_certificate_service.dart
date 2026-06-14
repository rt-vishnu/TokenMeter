import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';

/// TLS material for serving HTTPS: the [SecurityContext] the server binds with,
/// plus the certificate's SHA-256 fingerprint that clients pin against.
class TlsMaterial {
  TlsMaterial({
    required this.securityContext,
    required this.fingerprint,
    required this.certPem,
    required this.keyPem,
  });

  final SecurityContext securityContext;

  /// Lowercase hex SHA-256 of the certificate's DER bytes — matches
  /// `sha256(X509Certificate.der)` computed by a pinning client.
  final String fingerprint;
  final String certPem;
  final String keyPem;
}

/// Generates and rebuilds self-signed TLS certificates for the local API
/// server. The server is reached by private LAN IP, so no public CA can issue
/// a certificate; instead the app generates its own and clients pin the
/// fingerprint (delivered out-of-band via the pairing QR).
///
/// Native (dart:io) only — the API server never runs on web.
class TlsCertificateService {
  /// Rebuilds a [SecurityContext] from previously generated PEM material.
  /// Cheap — no key generation.
  TlsMaterial fromPem(String certPem, String keyPem) {
    final ctx = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(certPem))
      ..usePrivateKeyBytes(utf8.encode(keyPem));
    return TlsMaterial(
      securityContext: ctx,
      fingerprint: fingerprintOf(certPem),
      certPem: certPem,
      keyPem: keyPem,
    );
  }

  /// Generates a fresh self-signed certificate valid for ~10 years, with [ip]
  /// (and localhost) in the SAN. RSA-2048 key generation is CPU-heavy, so it
  /// runs in a background isolate to keep the UI responsive.
  Future<TlsMaterial> generate({required String ip}) async {
    final pems = await Isolate.run(() => _generatePems(ip));
    return fromPem(pems.$1, pems.$2);
  }

  /// Lowercase hex SHA-256 of the DER bytes encoded in [certPem].
  /// Uses basic_utils' decoder, which tolerates CRLF/whitespace in the PEM.
  String fingerprintOf(String certPem) =>
      sha256.convert(CryptoUtils.getBytesFromPEMString(certPem)).toString();
}

/// Top-level so it can run in an isolate. Returns (certPem, keyPem).
(String, String) _generatePems(String ip) {
  final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
  final priv = pair.privateKey as RSAPrivateKey;
  final pub = pair.publicKey as RSAPublicKey;

  const dn = {'CN': 'PromptPenny Local API', 'O': 'PromptPenny'};
  final sans = {ip, 'localhost', '127.0.0.1'}.toList();

  final csr = X509Utils.generateRsaCsrPem(dn, priv, pub, san: sans);
  final certPem = X509Utils.generateSelfSignedCertificate(
    priv,
    csr,
    3650,
    sans: sans,
  );
  final keyPem = CryptoUtils.encodeRSAPrivateKeyToPem(priv);
  return (certPem, keyPem);
}
