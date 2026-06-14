class LocalApiServer {
  LocalApiServer();

  static const portFallbackCount = 4;

  bool get isRunning => false;
  String? get boundAddress => null;
  int? get port => null;
  int? get requestedPort => null;
  String get scheme => 'http';
  String? get fingerprint => null;

  static bool isPortBindError(Object error) => false;

  Future<int> start(String host, int port, {bool useHttps = false}) async =>
      port;

  Future<void> stop() async {}
}
