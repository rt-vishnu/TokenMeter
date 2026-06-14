import 'package:http/http.dart' as http;

/// Web client. Certificate pinning isn't available in the browser sandbox —
/// the browser enforces TLS trust itself (the user accepts the self-signed
/// cert once). [fingerprint] is ignored.
http.Client createPinnedClient(String? fingerprint) => http.Client();
