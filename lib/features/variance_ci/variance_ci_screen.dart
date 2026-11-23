import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/math/chi_square_dist.dart';
import '../../core/models/ci_result.dart';
import '../chart_visualizer/distribution_chart_widget.dart';
import '../chart_visualizer/step_by_step_card.dart';
import '../navigation/app_shell.dart';

class VarianceCiScreen extends StatefulWidget {
  const VarianceCiScreen({super.key});

  @override
  State<VarianceCiScreen> createState() => _VarianceCiScreenState();
}

class _VarianceCiScreenState extends State<VarianceCiScreen> {
  bool _isRawData = false;
  bool _isVarianceInput = false;
  bool _useLectureApprox = false; // تقريب المحاضرة الثانية عند df > 30
  double _confidenceLevel = 0.95;

  final _nCtrl = TextEditingController(text: '30');
  final _sCtrl = TextEditingController(text: '2.4');
  final _rawCtrl = TextEditingController(
    text: '46.4, 46.1, 45.8, 47, 46.1, 45.9, 45.8, 46.9, 45.2, 46',
  );

  CiResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _nCtrl.dispose();
    _sCtrl.dispose();
    _rawCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(String key) {
    setState(() {
      if (key == 'lec5_p10') {
        _isRawData = true;
        _confidenceLevel = 0.95;
        _rawCtrl.text =
            '46.4, 46.1, 45.8, 47, 46.1, 45.9, 45.8, 46.9, 45.2, 46';
      } else if (key == 'lec5_p12') {
        _isRawData = false;
        _isVarianceInput = false;
        _confidenceLevel = 0.95;
        _nCtrl.text = '30';
        _sCtrl.text = '2.4';
      }
    });
    _calculate();
  }

  void _calculate() {
    setState(() => _errorMessage = null);
    try {
      int n;
      double s2;
      final List<String> steps = [];

      if (_isRawData) {
        final values = _rawCtrl.text
            .split(RegExp(r'[,\s]+'))
            .where((e) => e.trim().isNotEmpty)
            .map(double.parse)
            .toList();
        if (values.length < 2) throw Exception('أدخل قيمتين على الأقل.');
        n = values.length;
        final mean = values.reduce((a, b) => a + b) / n;
        s2 =
            values.fold(0.0, (sum, x) => sum + math.pow(x - mean, 2)) / (n - 1);
        steps.add(
          'From $n raw values: X̄ = ${mean.toStringAsFixed(4)}, Sample Variance s² = ${s2.toStringAsFixed(5)}',
        );
      } else {
        n = int.parse(_nCtrl.text.trim());
        final val = double.parse(_sCtrl.text.trim());
        if (n < 2 || val <= 0) throw Exception('تأكد أن n ≥ 2 والقيمة > 0.');
        s2 = _isVarianceInput ? val : val * val;
        steps.add(
          'Given: n = $n ⇒ df = n - 1 = ${n - 1}, s² = ${s2.toStringAsFixed(5)}',
        );
      }

      final df = n - 1;
      final alpha = 1.0 - _confidenceLevel;
      final alphaOverTwo = alpha / 2.0;

      final chiRight = ChiSquareDist.criticalChiSquare(
        alphaOverTwo,
        df,
        useLectureNormalApprox: _useLectureApprox,
      );
      final chiLeft = ChiSquareDist.criticalChiSquare(
        1.0 - alphaOverTwo,
        df,
        useLectureNormalApprox: _useLectureApprox,
      );

      final double lclVar = (df * s2) / chiRight;
      final double uclVar = (df * s2) / chiLeft;
      final double lclStd = math.sqrt(lclVar);
      final double uclStd = math.sqrt(uclVar);

      steps.add(
        'α = ${alpha.toStringAsFixed(3)} ⇒ α/2 = ${alphaOverTwo.toStringAsFixed(4)} and 1 - α/2 = ${(1 - alphaOverTwo).toStringAsFixed(4)}',
      );
      steps.add(
        'Critical Values (df = $df): χ²_(${alphaOverTwo.toStringAsFixed(4)}, $df) = ${chiRight.toStringAsFixed(3)},  χ²_(${(1 - alphaOverTwo).toStringAsFixed(4)}, $df) = ${chiLeft.toStringAsFixed(3)}',
      );
      steps.add(
        'Law: [ (n - 1)s² / χ²_(α/2, df) ] < σ² < [ (n - 1)s² / χ²_(1 - α/2, df) ]',
      );
      steps.add(
        'Substitution: [ ($df × ${s2.toStringAsFixed(4)}) / ${chiRight.toStringAsFixed(3)} ] < σ² < [ ($df × ${s2.toStringAsFixed(4)}) / ${chiLeft.toStringAsFixed(3)} ]',
      );
      steps.add(
        'Variance CI: ${lclVar.toStringAsFixed(4)} < σ² < ${uclVar.toStringAsFixed(4)}  ⇒  Std Dev CI: ${lclStd.toStringAsFixed(4)} < σ < ${uclStd.toStringAsFixed(4)}',
      );

      setState(() {
        _result = CiResult(
          title:
              '${(_confidenceLevel * 100).toStringAsFixed(0)}% CI for Variance (σ²) & Std Dev (σ)',
          methodUsed: _useLectureApprox && df > 30
              ? 'Chi-Square Normal Approx (df = $df > 30)'
              : 'Chi-Square Distribution — χ²(df = $df)',
          distType: DistributionType.chiSquare,
          degreesOfFreedom: df,
          alpha: alpha,
          pointEstimate: s2,
          lowerBound: lclVar,
          upperBound: uclVar,
          leftCritical: chiLeft,
          rightCritical: chiRight,
          secondaryLabel: 'Std Dev CI (σ)',
          secondaryValue:
              '${lclStd.toStringAsFixed(4)} < σ < ${uclStd.toStringAsFixed(4)}',
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
                      'Variance (σ²) & Std Dev (σ)',
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
                        value: 'lec5_p10',
                        child: Text('Lec 5 (p.10): 10 Seed Packages'),
                      ),
                      PopupMenuItem(
                        value: 'lec5_p12',
                        child: Text('Lec 5 (p.12): 30 Men Heights'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enter Raw Sample Values'),
                value: _isRawData,
                onChanged: (v) {
                  setState(() => _isRawData = v);
                  _calculate();
                },
              ),
              if (_isRawData)
                TextFormField(
                  controller: _rawCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Sample Values (comma/space separated)',
                  ),
                )
              else ...[
                TextFormField(
                  controller: _nCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sample Size (n)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sCtrl,
                  decoration: InputDecoration(
                    labelText: _isVarianceInput
                        ? 'Sample Variance (s²)'
                        : 'Sample Std Dev (s)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Input is already Variance (s²)'),
                  value: _isVarianceInput,
                  onChanged: (v) {
                    setState(() => _isVarianceInput = v ?? false);
                    _calculate();
                  },
                ),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use Lec 2 Normal Approx when df > 30'),
                subtitle: const Text('χ² ≈ 0.5 · (Z + √(2v - 1))²'),
                value: _useLectureApprox,
                onChanged: (v) {
                  setState(() => _useLectureApprox = v ?? false);
                  _calculate();
                },
              ),
              const SizedBox(height: 8),
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
                label: const Text('Calculate Variance CI'),
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
                    '${res.lowerBound.toStringAsFixed(4)}  <  σ²  <  ${res.upperBound.toStringAsFixed(4)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _row(
                  'Sample Variance (s²)',
                  res.pointEstimate.toStringAsFixed(5),
                ),
                _row(
                  'χ²_(1 - α/2, df) [Left]',
                  res.leftCritical.toStringAsFixed(3),
                ),
                _row(
                  'χ²_(α/2, df) [Right]',
                  res.rightCritical.toStringAsFixed(3),
                ),
                _row(res.secondaryLabel!, res.secondaryValue!),
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
