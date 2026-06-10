import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/usage_payload.dart';
import '../../core/models/usage_record.dart' as domain;
import '../../core/services/cost_calculator.dart';
import '../../core/services/pricing_repository.dart';
import '../database/app_database_io.dart';
import 'usage_repository_base.dart';

class UsageRepository implements UsageRepositoryBase {
  UsageRepository({
    required AppDatabase database,
    required PricingRepository pricingRepository,
    this.onUsageRecorded,
  })  : _db = database,
        _pricing = pricingRepository;

  final AppDatabase _db;
  final PricingRepository _pricing;
  final void Function()? onUsageRecorded;
  final _uuid = const Uuid();

  @override
  Stream<List<domain.UsageRecord>> watchAll() {
    return _db.watchAllRecords().map(
          (rows) => rows.map(_toDomain).toList(),
        );
  }

  @override
  Future<List<domain.UsageRecord>> getRecords({
    DateTime? from,
    DateTime? to,
    String? source,
    String? model,
  }) async {
    final rows = await _db.getRecords(
      from: from,
      to: to,
      source: source,
      model: model,
    );
    return rows.map(_toDomain).toList();
  }

  @override
  Future<domain.UsageRecord> recordUsage(UsagePayload payload) async {
    final model = _pricing.getModelOrDefault(payload.model);
    final cost = CostCalculator.calculateCost(
      model,
      payload.inputTokens,
      payload.outputTokens,
    );
    final id = _uuid.v4();
    final createdAt = payload.timestamp ?? DateTime.now();

    await _db.insertRecord(
      UsageRecordsCompanion.insert(
        id: id,
        model: payload.model,
        inputTokens: payload.inputTokens,
        outputTokens: payload.outputTokens,
        costUsd: cost,
        source: payload.source,
        sessionId: Value(payload.sessionId),
        metadata: Value(jsonEncode(payload.metadata)),
        createdAt: createdAt,
      ),
    );

    onUsageRecorded?.call();

    return domain.UsageRecord(
      id: id,
      model: payload.model,
      inputTokens: payload.inputTokens,
      outputTokens: payload.outputTokens,
      costUsd: cost,
      source: payload.source,
      sessionId: payload.sessionId,
      metadata: payload.metadata,
      createdAt: createdAt,
    );
  }

  @override
  Future<Map<String, dynamic>> estimate(EstimatePayload payload) async {
    final model = _pricing.getModelOrDefault(payload.model);
    final inputTokens = payload.inputTokens ??
        (payload.promptText != null
            ? CostCalculator.estimateTokensFromText(payload.promptText!)
            : 0);
    final outputTokens = payload.outputTokens ??
        (payload.completionText != null
            ? CostCalculator.estimateTokensFromText(payload.completionText!)
            : 0);
    final cost = CostCalculator.calculateCost(
      model,
      inputTokens,
      outputTokens,
    );

    return {
      'model': payload.model,
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
      'total_tokens': inputTokens + outputTokens,
      'cost_usd': cost,
      'estimated_from_text': payload.promptText != null ||
          payload.completionText != null,
    };
  }

  @override
  Future<double> totalCostSince(DateTime since) => _db.getTotalCostSince(since);

  @override
  Future<Map<String, double>> costByModelSince(DateTime since) =>
      _db.getCostByModelSince(since);

  @override
  Future<Map<String, double>> costBySourceSince(DateTime since) =>
      _db.getCostBySourceSince(since);

  domain.UsageRecord _toDomain(UsageRecord row) {
    return domain.UsageRecord(
      id: row.id,
      model: row.model,
      inputTokens: row.inputTokens,
      outputTokens: row.outputTokens,
      costUsd: row.costUsd,
      source: row.source,
      sessionId: row.sessionId,
      metadata: Map<String, dynamic>.from(
        jsonDecode(row.metadata) as Map? ?? {},
      ),
      createdAt: row.createdAt,
    );
  }
}
