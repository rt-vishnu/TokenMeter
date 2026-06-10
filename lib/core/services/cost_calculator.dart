import '../models/model_pricing.dart';

class CostCalculator {
  static double calculateCost(
    ModelPricing model,
    int inputTokens,
    int outputTokens,
  ) {
    final inputCost = inputTokens * model.inputPer1M / 1000000;
    final outputCost = outputTokens * model.outputPer1M / 1000000;
    return inputCost + outputCost;
  }

  static int estimateTokensFromText(String text) {
    if (text.isEmpty) return 0;
    return (text.length / 4).ceil();
  }
}
