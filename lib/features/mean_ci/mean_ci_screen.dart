import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/math/normal_dist.dart';
import '../../core/math/student_t_dist.dart';
import '../../core/models/ci_result.dart';
import '../chart_visualizer/distribution_chart_widget.dart';
import '../chart_visualizer/step_by_step_card.dart';
import '../navigation/app_shell.dart';

enum _MeanInputMode { summary, rawList, sums, sampleSize }

class MeanCiScreen extends StatefulWidget {
  const MeanCiScreen({super.key});

  @override
  State<MeanCiScreen> createState() => _MeanCiScreenState();
}

class _MeanCiScreenState extends State<MeanCiScreen> {
  _MeanInputMode _inputMode = _MeanInputMode.summary;
  bool _isSigmaKnown = true;
  double _confidenceLevel = 0.95;

  final _meanCtrl = TextEditingController(text: '15');
  final _stdCtrl = TextEditingController(text: '4');
  final _nCtrl = TextEditingController(text: '25');
  final _errorCtrl = TextEditingController(text: '0.05');
  final _rawCtrl = TextEditingController(
    text: '46.4, 46.1, 45.8, 47, 46.1, 45.9, 45.8, 46.9, 45.2, 46',
  );
  final _sumXCtrl = TextEditingController(text: '280');
  final _sumX2Ctrl = TextEditingController(text: '2100');

  CiResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _meanCtrl.dispose();
    _stdCtrl.dispose();
    _nCtrl.dispose();
    _errorCtrl.dispose();
    _rawCtrl.dispose();
    _sumXCtrl.dispose();
    _sumX2Ctrl.dispose();
    super.dispose();
  }

  void _applyPreset(String presetKey) {
    setState(() {
      switch (presetKey) {
        case 'lec4_p8': // مثال ص 8: n=25, var=16 (sigma=4), mean=15, 95%
          _inputMode = _MeanInputMode.summary;
          _isSigmaKnown = true;
          _confidenceLevel = 0.95;
          _meanCtrl.text = '15';
          _stdCtrl.text = '4';
          _nCtrl.text = '25';
          break;
        case 'lec4_p10': // مثال ص 10: n=40, sumX=280, sumX2=2100, 95%
          _inputMode = _MeanInputMode.sums;
          _isSigmaKnown = false;
          _confidenceLevel = 0.95;
          _nCtrl.text = '40';
          _sumXCtrl.text = '280';
          _sumX2Ctrl.text = '2100';
          break;
        case 'lec4_p11': // مثال ص 11 (Student-t): n=12, mean=7.38, s=1.24, 95%
          _inputMode = _MeanInputMode.summary;
          _isSigmaKnown = false;
          _confidenceLevel = 0.95;
          _meanCtrl.text = '7.38';
          _stdCtrl.text = '1.24';
          _nCtrl.text = '12';
          break;
        case 'lec4_p13': // مسألة حل بنفسك ص 13: n=30, sigma=40, mean=780, 95%
          _inputMode = _MeanInputMode.summary;
          _isSigmaKnown = true;
          _confidenceLevel = 0.95;
          _meanCtrl.text = '780';
          _stdCtrl.text = '40';
          _nCtrl.text = '30';
          break;
        case 'lec4_p15': // مسألة حجم العينة ص 15: s=0.3, e=0.05, 95%
          _inputMode = _MeanInputMode.sampleSize;
          _isSigmaKnown = true;
          _confidenceLevel = 0.95;
          _stdCtrl.text = '0.3';
          _errorCtrl.text = '0.05';
          break;
      }
    });
    _calculate();
  }

  void _calculate() {
    setState(() => _errorMessage = null);

    try {
      final alpha = 1.0 - _confidenceLevel;
      final alphaOverTwo = alpha / 2.0;

      // وضع حساب حجم العينة المطلوب n (محاضرة 4 ص 14-15)
      if (_inputMode == _MeanInputMode.sampleSize) {
        final sigma = double.parse(_stdCtrl.text.trim());
        final e = double.parse(_errorCtrl.text.trim());
        if (sigma <= 0 || e <= 0) {
          throw Exception('تأكد أن الانحراف المعياري وهامش الخطأ > 0.');
        }

        final zCrit = NormalDist.criticalZ(alphaOverTwo);
        final exactN = math.pow((zCrit * sigma) / e, 2).toDouble();
        final requiredN = exactN.ceil();

        setState(() {
          _result = CiResult(
            title:
                'Required Sample Size (n) at ${(_confidenceLevel * 100).toStringAsFixed(0)}% Confidence',
            methodUsed: 'Sample Size Formula — SE = Z_(α/2) · (σ / √n)',
            distType: DistributionType.normal,
            alpha: alpha,
            pointEstimate: requiredN.toDouble(),
            lowerBound: -zCrit,
            upperBound: zCrit,
            leftCritical: -zCrit,
            rightCritical: zCrit,
            isSampleSizeMode: true,
            secondaryLabel: 'Exact Value before Rounding',
            secondaryValue: exactN.toStringAsFixed(2),
            steps: [
              'Given: σ = $sigma, Margin of Error (e) = $e, 1 - α = $_confidenceLevel ⇒ α/2 = ${alphaOverTwo.toStringAsFixed(4)}',
              'Critical Value from Z-table: Z_(${alphaOverTwo.toStringAsFixed(4)}) = ${zCrit.toStringAsFixed(4)}',
              'Law: e = Z_(α/2) · (σ / √n)  ⇒  n = [ (Z_(α/2) · σ) / e ]²',
              'Substitution: n = [ (${zCrit.toStringAsFixed(3)} × $sigma) / $e ]² = ${exactN.toStringAsFixed(2)}',
              'Required Sample Size (rounded up): n = $requiredN',
            ],
          );
        });
        return;
      }

      double xBar;
      double stdDev;
      int n;
      final List<String> steps = [];

      if (_inputMode == _MeanInputMode.summary) {
        xBar = double.parse(_meanCtrl.text.trim());
        stdDev = double.parse(_stdCtrl.text.trim());
        n = int.parse(_nCtrl.text.trim());
        steps.add(
          'Given: n = $n, X̄ = $xBar, ${_isSigmaKnown ? "σ" : "s"} = $stdDev',
        );
      } else if (_inputMode == _MeanInputMode.rawList) {
        final values = _rawCtrl.text
            .split(RegExp(r'[,\s]+'))
            .where((e) => e.trim().isNotEmpty)
            .map(double.parse)
            .toList();
        if (values.length < 2) throw Exception('أدخل قيمتين على الأقل.');
        n = values.length;
        xBar = values.reduce((a, b) => a + b) / n;
        final sumSqDiff = values.fold(
          0.0,
          (sum, x) => sum + math.pow(x - xBar, 2),
        );
        stdDev = math.sqrt(sumSqDiff / (n - 1));
        steps.add(
          'From $n raw values: X̄ = Σx / n = ${xBar.toStringAsFixed(4)}, s = ${stdDev.toStringAsFixed(4)}',
        );
      } else {
        n = int.parse(_nCtrl.text.trim());
        final sumX = double.parse(_sumXCtrl.text.trim());
        final sumX2 = double.parse(_sumX2Ctrl.text.trim());
        if (n < 2) throw Exception('حجم العينة n يجب أن يكون أكبر من 1.');
        xBar = sumX / n;
        final variance = (sumX2 - (sumX * sumX) / n) / (n - 1);
        if (variance < 0) {
          throw Exception('قيم المجاميع غير متناسقة (التباين سالب).');
        }
        stdDev = math.sqrt(variance);
        steps.add('X̄ = Σx / n = $sumX / $n = ${xBar.toStringAsFixed(4)}');
        steps.add(
          's² = [Σx² - (Σx)²/n] / (n - 1) = ${variance.toStringAsFixed(4)} ⇒ s = ${stdDev.toStringAsFixed(4)}',
        );
      }

      if (n < 2 || stdDev <= 0) {
        throw Exception('تأكد أن n ≥ 2 والانحراف المعياري > 0.');
      }

      final bool useZ = _isSigmaKnown || n >= 30;
      final double criticalVal = useZ
          ? NormalDist.criticalZ(alphaOverTwo)
          : StudentTDist.criticalT(alphaOverTwo, n - 1);

      final double se = stdDev / math.sqrt(n);
      final double marginOfError = criticalVal * se;
      final double lcl = xBar - marginOfError;
      final double ucl = xBar + marginOfError;

      final String critSymbol = useZ
          ? 'Z_(${alphaOverTwo.toStringAsFixed(4)})'
          : 't_(${alphaOverTwo.toStringAsFixed(4)}, ${n - 1})';
      final String stdSymbol = _isSigmaKnown ? 'σ' : 's';

      steps.add(
        'Confidence Level = ${(_confidenceLevel * 100).toStringAsFixed(0)}% ⇒ α = ${alpha.toStringAsFixed(3)}, α/2 = ${alphaOverTwo.toStringAsFixed(4)}',
      );
      steps.add(
        'Critical Value: $critSymbol = ${criticalVal.toStringAsFixed(4)}',
      );
      steps.add(
        'Law: X̄ - $critSymbol · ($stdSymbol / √n) < μ < X̄ + $critSymbol · ($stdSymbol / √n)',
      );
      steps.add(
        'Substitution: ${xBar.toStringAsFixed(3)} ± ${criticalVal.toStringAsFixed(3)} × (${stdDev.toStringAsFixed(3)} / √$n) = ${xBar.toStringAsFixed(3)} ± ${marginOfError.toStringAsFixed(4)}',
      );
      steps.add(
        'Result: ${lcl.toStringAsFixed(4)} < μ < ${ucl.toStringAsFixed(4)}',
      );

      final String methodLabel = useZ
          ? (_isSigmaKnown
                ? 'Z-Distribution (σ Known)'
                : 'Z-Distribution (σ Unknown, n ≥ 30)')
          : 'Student-t Distribution (σ Unknown, n < 30, df = ${n - 1})';

      setState(() {
        _result = CiResult(
          title:
              '${(_confidenceLevel * 100).toStringAsFixed(0)}% Confidence Interval for Mean (μ)',
          methodUsed: methodLabel,
          distType: useZ ? DistributionType.normal : DistributionType.studentT,
          degreesOfFreedom: n - 1,
          alpha: alpha,
          pointEstimate: xBar,
          lowerBound: lcl,
          upperBound: ucl,
          standardError: se,
          leftCritical: -criticalVal,
          rightCritical: criticalVal,
          secondaryLabel: 'Critical $critSymbol',
          secondaryValue: '±${criticalVal.toStringAsFixed(4)}',
          steps: steps,
        );
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveCalcLayout(
      inputSection: _buildInputCard(context),
      resultAndChartSection: _buildResultSection(context),
    );
  }

  Widget _buildInputCard(BuildContext context) {
    return Card(
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
                    'Population Mean (μ)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Lecture 4 Examples',
                  icon: const Icon(Icons.auto_stories_outlined),
                  onSelected: _applyPreset,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'lec4_p8',
                      child: Text('Lec 4 (p.8): σ Known, n=25'),
                    ),
                    PopupMenuItem(
                      value: 'lec4_p10',
                      child: Text('Lec 4 (p.10): Sums Σx, Σx²'),
                    ),
                    PopupMenuItem(
                      value: 'lec4_p11',
                      child: Text('Lec 4 (p.11): Student-t, n=12'),
                    ),
                    PopupMenuItem(
                      value: 'lec4_p13',
                      child: Text('Lec 4 (p.13): حل بنفسك (Bulbs)'),
                    ),
                    PopupMenuItem(
                      value: 'lec4_p15',
                      child: Text('Lec 4 (p.15): Sample Size (n)'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<_MeanInputMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _MeanInputMode.summary,
                  label: Text('Summary', maxLines: 1, softWrap: false),
                ),
                ButtonSegment(
                  value: _MeanInputMode.rawList,
                  label: Text('Raw', maxLines: 1, softWrap: false),
                ),
                ButtonSegment(
                  value: _MeanInputMode.sums,
                  label: Text('Σx, Σx²', maxLines: 1, softWrap: false),
                ),
                ButtonSegment(
                  value: _MeanInputMode.sampleSize,
                  label: Text('Find n', maxLines: 1, softWrap: false),
                ),
              ],
              selected: {_inputMode},
              onSelectionChanged: (val) {
                setState(() => _inputMode = val.first);
                _calculate();
              },
            ),
            const SizedBox(height: 12),
            if (_inputMode != _MeanInputMode.sampleSize) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Population σ is Known'),
                subtitle: Text(
                  _isSigmaKnown
                      ? 'Uses Z-table regardless of sample size'
                      : 'Uses Z if n ≥ 30, or Student-t if n < 30',
                ),
                value: _isSigmaKnown,
                onChanged: (v) {
                  setState(() => _isSigmaKnown = v);
                  _calculate();
                },
              ),
              const Divider(),
            ],
            const SizedBox(height: 8),
            if (_inputMode == _MeanInputMode.sampleSize) ...[
              TextFormField(
                controller: _stdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Standard Deviation (σ or s)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _errorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Desired Margin of Error (e)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ] else if (_inputMode == _MeanInputMode.summary) ...[
              TextFormField(
                controller: _meanCtrl,
                decoration: const InputDecoration(
                  labelText: 'Sample Mean (X̄)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stdCtrl,
                decoration: InputDecoration(
                  labelText: _isSigmaKnown
                      ? 'Population Std Dev (σ)'
                      : 'Sample Std Dev (s)',
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
            ] else if (_inputMode == _MeanInputMode.rawList) ...[
              TextFormField(
                controller: _rawCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Sample Values (comma or space separated)',
                ),
              ),
            ] else ...[
              TextFormField(
                controller: _nCtrl,
                decoration: const InputDecoration(labelText: 'Sample Size (n)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sumXCtrl,
                decoration: const InputDecoration(
                  labelText: 'Sum of Values (Σx)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sumX2Ctrl,
                decoration: const InputDecoration(
                  labelText: 'Sum of Squares (Σx²)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Confidence Level (1 - α): ${(_confidenceLevel * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.labelLarge,
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
              label: Text(
                _inputMode == _MeanInputMode.sampleSize
                    ? 'Calculate Sample Size (n)'
                    : 'Calculate CI',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection(BuildContext context) {
    if (_errorMessage != null) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _errorMessage!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
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
                const SizedBox(height: 4),
                Chip(label: Text(res.methodUsed)),
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
                        : '${res.lowerBound.toStringAsFixed(4)}  <  μ  <  ${res.upperBound.toStringAsFixed(4)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!res.isSampleSizeMode) ...[
                  _StatRow(
                    'Point Estimate (X̄)',
                    res.pointEstimate.toStringAsFixed(4),
                  ),
                  _StatRow(
                    res.secondaryLabel ?? 'Critical Value',
                    res.secondaryValue ?? '-',
                  ),
                  _StatRow(
                    'Standard Error (SE)',
                    res.standardError?.toStringAsFixed(4) ?? '-',
                  ),
                  _StatRow(
                    'Interval Width (UCL - LCL)',
                    (res.upperBound - res.lowerBound).toStringAsFixed(4),
                  ),
                ] else ...[
                  _StatRow(res.secondaryLabel!, res.secondaryValue!),
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
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
