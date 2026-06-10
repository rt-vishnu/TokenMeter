import 'package:flutter/material.dart';
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

  void _calculate() {
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
      input = int.tryParse(_inputController.text) ?? 0;
      output = int.tryParse(_outputController.text) ?? 0;
    }

    setState(() {
      _inputTokens = input;
      _outputTokens = output;
      _estimatedCost = CostCalculator.calculateCost(model, input, output);
    });
  }

  Future<void> _calculateRemote() async {
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedModel,
          decoration: const InputDecoration(labelText: 'Model'),
          items: [
            for (final m in models)
              DropdownMenuItem(value: m.id, child: Text(m.displayName)),
          ],
          onChanged: (v) => setState(() => _selectedModel = v),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Estimate from text'),
          subtitle: const Text('Approximate: tokens ≈ characters / 4'),
          value: _useTextEstimate,
          onChanged: (v) => setState(() => _useTextEstimate = v),
        ),
        const SizedBox(height: 8),
        if (_useTextEstimate) ...[
          TextField(
            controller: _promptController,
            decoration: const InputDecoration(
              labelText: 'Prompt text',
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _completionController,
            decoration: const InputDecoration(
              labelText: 'Completion text',
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
        ] else ...[
          TextField(
            controller: _inputController,
            decoration: const InputDecoration(labelText: 'Input tokens'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _outputController,
            decoration: const InputDecoration(labelText: 'Output tokens'),
            keyboardType: TextInputType.number,
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
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${Formatters.tokens(_inputTokens!)} input + '
                    '${Formatters.tokens(_outputTokens!)} output tokens',
                    style: Theme.of(context).textTheme.bodyMedium,
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
    );
  }
}
