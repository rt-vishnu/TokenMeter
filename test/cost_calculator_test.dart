import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_penny/core/models/model_pricing.dart';
import 'package:prompt_penny/core/services/cost_calculator.dart';

void main() {
  const gpt4o = ModelPricing(
    id: 'gpt-4o',
    provider: 'openai',
    displayName: 'GPT-4o',
    inputPer1M: 2.50,
    outputPer1M: 10.00,
  );

  test('calculateCost computes input and output correctly', () {
    final cost = CostCalculator.calculateCost(gpt4o, 1_000_000, 500_000);
    expect(cost, closeTo(2.50 + 5.00, 0.001));
  });

  test('calculateCost handles small token counts', () {
    final cost = CostCalculator.calculateCost(gpt4o, 1000, 500);
    expect(cost, closeTo(0.0025 + 0.005, 0.0001));
  });

  test('estimateTokensFromText uses chars/4 rule', () {
    expect(CostCalculator.estimateTokensFromText(''), 0);
    expect(CostCalculator.estimateTokensFromText('abcd'), 1);
    expect(CostCalculator.estimateTokensFromText('abcde'), 2);
    expect(CostCalculator.estimateTokensFromText('a' * 100), 25);
  });
}
