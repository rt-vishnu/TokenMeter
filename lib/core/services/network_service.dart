import 'network_service_io.dart'
    if (dart.library.html) 'network_service_web.dart' as platform;

class NetworkService {
  Future<String?> getLocalIp() => platform.getLocalIp();
}
