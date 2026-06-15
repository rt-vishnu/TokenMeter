import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared secure-storage options for API keys, TLS material, and DB encryption.
const appSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
