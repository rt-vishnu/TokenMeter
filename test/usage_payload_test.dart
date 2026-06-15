import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_penny/core/models/usage_payload.dart';
import 'package:prompt_penny/core/utils/pairing.dart';

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

  test('UsagePayload rejects unknown metadata keys', () {
    expect(
      () => UsagePayload.fromJson({
        'model': 'gpt-4o',
        'input_tokens': 1,
        'output_tokens': 1,
        'metadata': {'evil': 'payload'},
      }),
      throwsArgumentError,
    );
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

  test('PairingInfo.buildLink omits API key', () {
    final link = PairingInfo.buildLink(
      'https://192.168.1.10:8765',
      fingerprint: 'abc123',
    );
    expect(link, 'https://192.168.1.10:8765?fp=abc123');
    expect(link.contains('key='), isFalse);
  });

  test('PairingInfo.parse rejects legacy key in URL', () {
    expect(
      () => PairingInfo.parse('https://192.168.1.10:8765?key=secret&fp=abc'),
      throwsA(isA<PairingValidationException>()),
    );
  });

  test('PairingInfo.parse accepts private LAN host', () {
    final info = PairingInfo.parse('https://10.0.0.5:8765?fp=abc');
    expect(info.host, 'https://10.0.0.5:8765');
    expect(info.fingerprint, 'abc');
  });
}
