import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/math/normal_dist.dart';
import '../../core/models/ci_result.dart';
import '../chart_visualizer/distribution_chart_widget.dart';
import '../chart_visualizer/step_by_step_card.dart';
import '../navigation/app_shell.dart';

enum _PropMode { countX, directP, sampleSize }

class ProportionCiScreen extends StatefulWidget {
  const ProportionCiScreen({super.key});

  @override
  State<ProportionCiScreen> createState() => _ProportionCiScreenState();
}

class _ProportionCiScreenState extends State<ProportionCiScreen> {
  _PropMode _mode = _PropMode.countX;
  double _confidenceLevel = 0.95;

  final _xCtrl = TextEditingController(text: '340');
  final _pHatCtrl = TextEditingController(text: '0.24');
  final _nCtrl = TextEditingController(text: '500');
  final _errorCtrl = TextEditingController(text: '0.03');

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
    _errorCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(String key) {
    setState(() {
      if (key == 'lec5_p5') {
        _mode = _PropMode.directP;
        _confidenceLevel = 0.95;
        _pHatCtrl.text = '0.24';
        _nCtrl.text = '100';
      } else if (key == 'lec5_p6') {
        _mode = _PropMode.countX;
        _confidenceLevel = 0.95;
        _xCtrl.text = '340';
        _nCtrl.text = '500';
      } else if (key == 'lec5_p7') {
        _mode = _PropMode.countX;
        _confidenceLevel = 0.95;
        _xCtrl.text = '200';
        _nCtrl.text = '1000';
      }
    });
    _calculate();
  }

  void _calculate() {
    setState(() => _errorMessage = null);
    try {
      final alpha = 1.0 - _confidenceLevel;
      final alphaOverTwo = alpha / 2.0;
      final zCrit = NormalDist.criticalZ(alphaOverTwo);

      if (_mode == _PropMode.sampleSize) {
        final pEst = double.parse(_pHatCtrl.text.trim());
        final e = double.parse(_errorCtrl.text.trim());
        if (pEst <= 0 || pEst >= 1 || e <= 0) {
          throw Exception('تأكد أن P̂ بين 0 و 1، وهامش الخطأ e > 0.');
        }
        final exactN = pEst * (1.0 - pEst) * math.pow(zCrit / e, 2);
        final reqN = exactN.ceil();

        setState(() {
          _result = CiResult(
            title: 'Required Sample Size (n) for Proportion',
            methodUsed: 'Sample Size Formula — n = P̂(1 - P̂) · (Z_(α/2) / e)²',
            distType: DistributionType.normal,
            alpha: alpha,
            pointEstimate: reqN.toDouble(),
            lowerBound: -zCrit,
            upperBound: zCrit,
            leftCritical: -zCrit,
            rightCritical: zCrit,
            isSampleSizeMode: true,
            secondaryLabel: 'Exact Value',
            secondaryValue: exactN.toStringAsFixed(2),
            steps: [
              'Given: P̂ = $pEst, Margin of Error (e) = $e, Z_(${alphaOverTwo.toStringAsFixed(4)}) = ${zCrit.toStringAsFixed(4)}',
              'Law: n = P̂(1 - P̂) · (Z_(α/2) / e)²',
              'Substitution: n = $pEst × ${(1 - pEst).toStringAsFixed(2)} × (${zCrit.toStringAsFixed(3)} / $e)² = ${exactN.toStringAsFixed(2)}',
              'Required Sample Size (rounded up): n = $reqN',
            ],
          );
        });
        return;
      }

      final n = int.parse(_nCtrl.text.trim());
      if (n <= 0) throw Exception('حجم العينة n يجب أن يكون أكبر من الصفر.');

      double pHat;
      final List<String> steps = [];
      if (_mode == _PropMode.countX) {
        final x = double.parse(_xCtrl.text.trim());
        if (x < 0 || x > n) throw Exception('قيمة X يجب أن تكون بين 0 و n.');
        pHat = x / n;
        steps.add(
          'Sample Proportion: P̂ = X / n = $x / $n = ${pHat.toStringAsFixed(4)}',
        );
      } else {
        pHat = double.parse(_pHatCtrl.text.trim());
        if (pHat <= 0 || pHat >= 1)
          throw Exception('نسبة العينة P̂ يجب أن تكون بين 0 و 1.');
        steps.add('Given: n = $n, P̂ = $pHat');
      }

      final se = math.sqrt((pHat * (1.0 - pHat)) / n);
      final margin = zCrit * se;
      final lcl = (pHat - margin).clamp(0.0, 1.0);
      final ucl = (pHat + margin).clamp(0.0, 1.0);

      steps.add(
        'Critical Value: Z_(${alphaOverTwo.toStringAsFixed(4)}) = ${zCrit.toStringAsFixed(4)}',
      );
      steps.add(
        'Law: P̂ - Z_(α/2) · √[ P̂(1 - P̂) / n ] < P < P̂ + Z_(α/2) · √[ P̂(1 - P̂) / n ]',
      );
      steps.add(
        'Substitution: ${pHat.toStringAsFixed(4)} ± ${zCrit.toStringAsFixed(3)} × ${se.toStringAsFixed(5)} = ${pHat.toStringAsFixed(4)} ± ${margin.toStringAsFixed(4)}',
      );
      steps.add(
        'Result: ${lcl.toStringAsFixed(4)} < P < ${ucl.toStringAsFixed(4)}',
      );

      setState(() {
        _result = CiResult(
          title:
              '${(_confidenceLevel * 100).toStringAsFixed(0)}% Confidence Interval for Proportion (P)',
          methodUsed: 'Z-Approximation for Population Proportion',
          distType: DistributionType.normal,
          alpha: alpha,
          pointEstimate: pHat,
          lowerBound: lcl,
          upperBound: ucl,
          standardError: se,
          leftCritical: -zCrit,
          rightCritical: zCrit,
          secondaryLabel: 'Critical Z_(α/2)',
          secondaryValue: '±${zCrit.toStringAsFixed(4)}',
          steps: steps,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Population Proportion (P)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Lecture 5 Examples',
                    icon: const Icon(Icons.auto_stories_outlined),
                    onSelected: _applyPreset,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'lec5_p5',
                        child: Text('Lec 5 (p.5): P̂ = 0.24, n = 100'),
                      ),
                      PopupMenuItem(
                        value: 'lec5_p6',
                        child: Text('Lec 5 (p.6): X = 340, n = 500'),
                      ),
                      PopupMenuItem(
                        value: 'lec5_p7',
                        child: Text('Lec 5 (p.7): X = 200, n = 1000'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<_PropMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _PropMode.countX,
                    label: Text('X & n', maxLines: 1, softWrap: false),
                  ),
                  ButtonSegment(
                    value: _PropMode.directP,
                    label: Text('P̂ & n', maxLines: 1, softWrap: false),
                  ),
                  ButtonSegment(
                    value: _PropMode.sampleSize,
                    label: Text('Find n', maxLines: 1, softWrap: false),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (v) {
                  setState(() => _mode = v.first);
                  _calculate();
                },
              ),
              const SizedBox(height: 12),
              if (_mode == _PropMode.countX)
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
                    labelText: 'Sample Proportion (P̂) [0.5 if unknown]',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              const SizedBox(height: 12),
              if (_mode == _PropMode.sampleSize)
                TextFormField(
                  controller: _errorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Desired Margin of Error (e)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                )
              else
                TextFormField(
                  controller: _nCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sample Size (n)',
                  ),
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
                label: Text(
                  _mode == _PropMode.sampleSize
                      ? 'Calculate Sample Size (n)'
                      : 'Calculate Proportion CI',
                ),
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
                    res.isSampleSizeMode
                        ? 'Required Sample Size:  n = ${res.pointEstimate.toInt()}'
                        : '${res.lowerBound.toStringAsFixed(4)}  <  P  <  ${res.upperBound.toStringAsFixed(4)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!res.isSampleSizeMode) ...[
                  _row(
                    'Sample Proportion (P̂)',
                    res.pointEstimate.toStringAsFixed(4),
                  ),
                  _row(res.secondaryLabel!, res.secondaryValue!),
                  _row(
                    'Standard Error (SE)',
                    res.standardError!.toStringAsFixed(4),
                  ),
                ] else ...[
                  _row(res.secondaryLabel!, res.secondaryValue!),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        StepByStepCard(steps: res.steps),
        const SizedBox(height: 12),
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
