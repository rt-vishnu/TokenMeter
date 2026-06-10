import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/usage_payload.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/cost_calculator.dart';
import '../../core/utils/formatters.dart';

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedModel;
  final _inputController = TextEditingController();
  final _outputController = TextEditingController();
  final _promptController = TextEditingController();
  final _completionController = TextEditingController();
  bool _useTextEstimate = false;
  double? _estimatedCost;
  int? _inputTokens;
  int? _outputTokens;

  @override
  void dispose() {
    _inputController.dispose();
    _outputController.dispose();
    _promptController.dispose();
    _completionController.dispose();
    super.dispose();
  }

  String? _validateTokenField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a $fieldName count';
    }
    final n = int.tryParse(value);
    if (n == null) return '$fieldName must be a whole number';
    if (n < 0) return '$fieldName must be non-negative';
    if (n > 2000000) return '$fieldName exceeds maximum (2,000,000)';
    return null;
  }

  String? _validateTextField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter $fieldName to estimate tokens';
    }
    return null;
  }

  void _calculate() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final pricing = ref.read(pricingRepositoryProvider);
    final modelId = _selectedModel;
    if (modelId == null) return;

    final model = pricing.getModelOrDefault(modelId);
    int input;
    int output;

    if (_useTextEstimate) {
      input = CostCalculator.estimateTokensFromText(_promptController.text);
      output =
          CostCalculator.estimateTokensFromText(_completionController.text);
    } else {
      input = int.parse(_inputController.text);
      output = int.parse(_outputController.text);
    }

    setState(() {
      _inputTokens = input;
      _outputTokens = output;
      _estimatedCost = CostCalculator.calculateCost(model, input, output);
    });
  }

  Future<void> _calculateRemote() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final modelId = _selectedModel;
    if (modelId == null) return;

    final client = ref.read(remoteApiClientProvider);
    final usage = ref.read(usageRepositoryProvider);

    final payload = EstimatePayload(
      model: modelId,
      inputTokens: _useTextEstimate
          ? null
          : int.tryParse(_inputController.text),
      outputTokens: _useTextEstimate
          ? null
          : int.tryParse(_outputController.text),
      promptText: _useTextEstimate ? _promptController.text : null,
      completionText: _useTextEstimate ? _completionController.text : null,
    );

    Map<String, dynamic> result;
    if (client != null) {
      result = await client.estimate(payload);
    } else if (usage != null) {
      result = await usage.estimate(payload);
    } else {
      _calculate();
      return;
    }

    setState(() {
      _inputTokens = result['input_tokens'] as int;
      _outputTokens = result['output_tokens'] as int;
      _estimatedCost = (result['cost_usd'] as num).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final models = ref.watch(pricingRepositoryProvider).sortedModels;
    _selectedModel ??= models.isNotEmpty ? models.first.id : null;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedModel,
            decoration: const InputDecoration(labelText: 'Model'),
            items: [
              for (final m in models)
                DropdownMenuItem(value: m.id, child: Text(m.displayName)),
            ],
            validator: (v) => v == null ? 'Select a model' : null,
            onChanged: (v) => setState(() => _selectedModel = v),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Estimate from text'),
            subtitle: const Text('Approximate: tokens ≈ characters / 4'),
            value: _useTextEstimate,
            onChanged: (v) {
              setState(() {
                _useTextEstimate = v;
                _estimatedCost = null;
              });
              _formKey.currentState?.reset();
            },
          ),
          const SizedBox(height: 8),
          if (_useTextEstimate) ...[
            TextFormField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: 'Prompt text',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              validator: (v) => _validateTextField(v, 'prompt text'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _completionController,
              decoration: const InputDecoration(
                labelText: 'Completion text',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              validator: (v) => _validateTextField(v, 'completion text'),
            ),
          ] else ...[
            TextFormField(
              controller: _inputController,
              decoration: const InputDecoration(labelText: 'Input tokens'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => _validateTokenField(v, 'input tokens'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _outputController,
              decoration: const InputDecoration(labelText: 'Output tokens'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => _validateTokenField(v, 'output tokens'),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _calculateRemote,
            icon: const Icon(Icons.calculate),
            label: const Text('Calculate Cost'),
          ),
          if (_estimatedCost != null) ...[
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      Formatters.currency(_estimatedCost!),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${Formatters.tokens(_inputTokens!)} input + '
                      '${Formatters.tokens(_outputTokens!)} output tokens',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_inputTokens == 0 && _outputTokens == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Both token counts are zero — cost is \$0.00.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_useTextEstimate)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Estimated from text — for exact counts, use IDE integration.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
