import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/usage_repository_base.dart';
import '../services/local_api_server_stub.dart';

final usageRepositoryProvider = Provider<UsageRepositoryBase?>((ref) => null);

final localApiServerProvider = Provider<LocalApiServer?>((ref) {
  return LocalApiServer();
});
