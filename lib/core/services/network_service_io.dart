import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

Future<String?> getLocalIp() async {
  final info = NetworkInfo();

  try {
    if (Platform.isAndroid || Platform.isIOS) {
      return await info.getWifiIP();
    }

    for (final interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    )) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
          return addr.address;
        }
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}
