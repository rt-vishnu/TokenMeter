import '../../core/models/usage_payload.dart';
import '../../core/models/usage_record.dart';

abstract class UsageRepositoryBase {
  Stream<List<UsageRecord>> watchAll();

  Future<List<UsageRecord>> getRecords({
    DateTime? from,
    DateTime? to,
    String? source,
    String? model,
  });

  Future<UsageRecord> recordUsage(UsagePayload payload);

  Future<Map<String, dynamic>> estimate(EstimatePayload payload);

  Future<double> totalCostSince(DateTime since);

  Future<Map<String, double>> costByModelSince(DateTime since);

  Future<Map<String, double>> costBySourceSince(DateTime since);
}
