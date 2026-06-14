import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Native client. When [fingerprint] is set, accepts the server's self-signed
/// certificate only if its SHA-256 matches — defeating MITM despite the cert
/// not being CA-signed. With no fingerprint, returns a default client.
http.Client createPinnedClient(String? fingerprint) {
  if (fingerprint == null || fingerprint.isEmpty) return http.Client();
  final expected = fingerprint.toLowerCase();
  final inner = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      return sha256.convert(cert.der).toString() == expected;
    };
  return IOClient(inner);
}
