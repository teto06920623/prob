import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/math/chi_square_dist.dart';
import '../../core/models/ci_result.dart';
import '../chart_visualizer/distribution_chart_widget.dart';
import '../navigation/app_shell.dart';

class VarianceCiScreen extends StatefulWidget {
  const VarianceCiScreen({super.key});

  @override
  State<VarianceCiScreen> createState() => _VarianceCiScreenState();
}

class _VarianceCiScreenState extends State<VarianceCiScreen> {
  bool _isRawData = false;
  bool _isVarianceInput = false; // هل المدخل s^2 أم s؟
  double _confidenceLevel = 0.95;

  // مثال صفحة 12 من محاضرة 5 (n=30, s=2.4)
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

  void _calculate() {
    setState(() => _errorMessage = null);
    try {
      int n;
      double s2;

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
      } else {
        n = int.parse(_nCtrl.text.trim());
        final val = double.parse(_sCtrl.text.trim());
        if (n < 2 || val <= 0) throw Exception('تأكد أن n ≥ 2 والقيمة > 0.');
        s2 = _isVarianceInput ? val : val * val;
      }

      final df = n - 1;
      final alpha = 1.0 - _confidenceLevel;
      final alphaOverTwo = alpha / 2.0;

      // القيم الحرجة من جدول Chi-Square (اليمين واليسار)
      final chiRight = ChiSquareDist.criticalChiSquare(alphaOverTwo, df);
      final chiLeft = ChiSquareDist.criticalChiSquare(1.0 - alphaOverTwo, df);

      final double lclVar = (df * s2) / chiRight;
      final double uclVar = (df * s2) / chiLeft;

      final double lclStd = math.sqrt(lclVar);
      final double uclStd = math.sqrt(uclVar);

      setState(() {
        _result = CiResult(
          title:
              '${(_confidenceLevel * 100).toStringAsFixed(0)}% CI for Variance (σ²) & Std Dev (σ)',
          methodUsed: 'Chi-Square Distribution — χ²(df = $df)',
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
                'Variance (σ²) & Std Dev (σ)',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
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
