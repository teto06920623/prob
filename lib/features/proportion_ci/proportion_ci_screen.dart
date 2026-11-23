import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/math/normal_dist.dart';
import '../../core/models/ci_result.dart';
import '../chart_visualizer/distribution_chart_widget.dart';
import '../navigation/app_shell.dart';

class ProportionCiScreen extends StatefulWidget {
  const ProportionCiScreen({super.key});

  @override
  State<ProportionCiScreen> createState() => _ProportionCiScreenState();
}

class _ProportionCiScreenState extends State<ProportionCiScreen> {
  bool _inputAsCount = true; // X and n vs P_hat and n
  double _confidenceLevel = 0.95;

  // مثال صفحة 6 من محاضرة 5 (X=340, n=500 -> P_hat = 0.68)
  final _xCtrl = TextEditingController(text: '340');
  final _pHatCtrl = TextEditingController(text: '0.24');
  final _nCtrl = TextEditingController(text: '500');

  CiResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _xCtrl.dispose();
    _pHatCtrl.dispose();
    _nCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    setState(() => _errorMessage = null);
    try {
      final n = int.parse(_nCtrl.text.trim());
      if (n <= 0) throw Exception('حجم العينة n يجب أن يكون أكبر من الصفر.');

      double pHat;
      if (_inputAsCount) {
        final x = double.parse(_xCtrl.text.trim());
        if (x < 0 || x > n) throw Exception('قيمة X يجب أن تكون بين 0 و n.');
        pHat = x / n;
      } else {
        pHat = double.parse(_pHatCtrl.text.trim());
        if (pHat <= 0 || pHat >= 1) {
          throw Exception('نسبة العينة P̂ يجب أن تكون بين 0 و 1.');
        }
      }

      final alpha = 1.0 - _confidenceLevel;
      final zCrit = NormalDist.criticalZ(alpha / 2.0);
      final se = math.sqrt((pHat * (1.0 - pHat)) / n);
      final margin = zCrit * se;

      setState(() {
        _result = CiResult(
          title:
              '${(_confidenceLevel * 100).toStringAsFixed(0)}% Confidence Interval for Proportion (P)',
          methodUsed: 'Z-Approximation for Population Proportion',
          distType: DistributionType.normal,
          alpha: alpha,
          pointEstimate: pHat,
          lowerBound: (pHat - margin).clamp(0.0, 1.0),
          upperBound: (pHat + margin).clamp(0.0, 1.0),
          standardError: se,
          leftCritical: -zCrit,
          rightCritical: zCrit,
          secondaryLabel: 'Critical Z_(α/2)',
          secondaryValue: '±${zCrit.toStringAsFixed(4)}',
        );
      });
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveCalcLayout(
      inputSection: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Population Proportion (P)',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Input using Success Count (X)'),
                subtitle: Text(
                  _inputAsCount
                      ? 'Calculates P̂ = X / n'
                      : 'Enter P̂ directly (0 to 1)',
                ),
                value: _inputAsCount,
                onChanged: (v) {
                  setState(() => _inputAsCount = v);
                  _calculate();
                },
              ),
              if (_inputAsCount)
                TextFormField(
                  controller: _xCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Number of Successes (X)',
                  ),
                  keyboardType: TextInputType.number,
                )
              else
                TextFormField(
                  controller: _pHatCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sample Proportion (P̂)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nCtrl,
                decoration: const InputDecoration(labelText: 'Sample Size (n)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [0.90, 0.95, 0.98, 0.99].map((level) {
                  return ChoiceChip(
                    label: Text('${(level * 100).toStringAsFixed(0)}%'),
                    selected: _confidenceLevel == level,
                    onSelected: (_) {
                      setState(() => _confidenceLevel = level);
                      _calculate();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: const Text('Calculate Proportion CI'),
              ),
            ],
          ),
        ),
      ),
      resultAndChartSection: _buildResult(context),
    );
  }

  Widget _buildResult(BuildContext context) {
    if (_errorMessage != null) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_errorMessage!),
        ),
      );
    }
    final res = _result;
    if (res == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  res.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withAlpha(110),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    '${res.lowerBound.toStringAsFixed(4)}  <  P  <  ${res.upperBound.toStringAsFixed(4)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _row(
                  'Sample Proportion (P̂)',
                  res.pointEstimate.toStringAsFixed(4),
                ),
                _row(res.secondaryLabel!, res.secondaryValue!),
                _row(
                  'Standard Error (SE)',
                  res.standardError!.toStringAsFixed(4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DistributionChartWidget(result: res),
      ],
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k),
        SelectableText(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
