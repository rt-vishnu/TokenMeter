import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_penny/core/models/usage_payload.dart';

void main() {
  test('UsagePayload.fromJson parses required fields', () {
    final payload = UsagePayload.fromJson({
      'model': 'gpt-4o',
      'input_tokens': 100,
      'output_tokens': 50,
      'source': 'cursor',
    });

    expect(payload.model, 'gpt-4o');
    expect(payload.inputTokens, 100);
    expect(payload.outputTokens, 50);
    expect(payload.source, 'cursor');
  });

  test('EstimatePayload.fromJson parses text fields', () {
    final payload = EstimatePayload.fromJson({
      'model': 'gpt-4o',
      'prompt_text': 'hello',
      'completion_text': 'world',
    });

    expect(payload.model, 'gpt-4o');
    expect(payload.promptText, 'hello');
    expect(payload.completionText, 'world');
    expect(payload.inputTokens, isNull);
  });
}
