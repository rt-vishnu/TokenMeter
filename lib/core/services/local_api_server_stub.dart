class LocalApiServer {
  LocalApiServer();

  bool get isRunning => false;
  String? get boundAddress => null;
  int? get port => null;

  Future<void> start(String host, int port) async {}

  Future<void> stop() async {}
}
