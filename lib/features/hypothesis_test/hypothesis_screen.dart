import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/math/normal_dist.dart';
import '../../core/math/student_t_dist.dart';
import '../../core/models/ci_result.dart';
import '../chart_visualizer/distribution_chart_widget.dart';
import '../navigation/app_shell.dart';

enum _TailType { left, twoTailed, right }

class HypothesisScreen extends StatefulWidget {
  const HypothesisScreen({super.key});

  @override
  State<HypothesisScreen> createState() => _HypothesisScreenState();
}

class _HypothesisScreenState extends State<HypothesisScreen> {
  _TailType _tailType = _TailType.right;
  bool _isSigmaKnown = true;
  double _alpha = 0.05;

  // مثال صفحة 15 من محاضرة 6 (mu0=42000, xBar=43260, sigma=5230, n=30, alpha=0.05)
  final _mu0Ctrl = TextEditingController(text: '42000');
  final _xBarCtrl = TextEditingController(text: '43260');
  final _stdCtrl = TextEditingController(text: '5230');
  final _nCtrl = TextEditingController(text: '30');

  CiResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _mu0Ctrl.dispose();
    _xBarCtrl.dispose();
    _stdCtrl.dispose();
    _nCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    setState(() => _errorMessage = null);
    try {
      final mu0 = double.parse(_mu0Ctrl.text.trim());
      final xBar = double.parse(_xBarCtrl.text.trim());
      final std = double.parse(_stdCtrl.text.trim());
      final n = int.parse(_nCtrl.text.trim());
      if (n < 2 || std <= 0) throw Exception('تأكد أن n ≥ 2 والانحراف > 0.');

      final useZ = _isSigmaKnown || n >= 30;
      final testStat = (xBar - mu0) / (std / math.sqrt(n));

      double leftCrit = double.negativeInfinity;
      double rightCrit = double.infinity;
      bool rejectH0 = false;

      if (_tailType == _TailType.left) {
        final crit = useZ
            ? NormalDist.criticalZ(_alpha)
            : StudentTDist.criticalT(_alpha, n - 1);
        leftCrit = -crit;
        rejectH0 = testStat < leftCrit;
      } else if (_tailType == _TailType.right) {
        final crit = useZ
            ? NormalDist.criticalZ(_alpha)
            : StudentTDist.criticalT(_alpha, n - 1);
        rightCrit = crit;
        rejectH0 = testStat > rightCrit;
      } else {
        final crit = useZ
            ? NormalDist.criticalZ(_alpha / 2.0)
            : StudentTDist.criticalT(_alpha / 2.0, n - 1);
        leftCrit = -crit;
        rightCrit = crit;
        rejectH0 = testStat < leftCrit || testStat > rightCrit;
      }

      setState(() {
        _result = CiResult(
          title: rejectH0
              ? 'Decision: Reject H₀ (Significant)'
              : 'Decision: Accept H₀ (Not Significant)',
          methodUsed: useZ
              ? 'Z-Test (α = $_alpha)'
              : 'T-Test (df = ${n - 1}, α = $_alpha)',
          distType: useZ ? DistributionType.normal : DistributionType.studentT,
          degreesOfFreedom: n - 1,
          alpha: _alpha,
          pointEstimate: testStat,
          lowerBound: leftCrit,
          upperBound: rightCrit,
          leftCritical: leftCrit,
          rightCritical: rightCrit,
          testValue: testStat,
          secondaryLabel: 'Test Statistic (${useZ ? "Z" : "T"})',
          secondaryValue: testStat.toStringAsFixed(4),
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
                'Hypothesis Testing for Mean (μ)',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SegmentedButton<_TailType>(
                segments: const [
                  ButtonSegment(
                    value: _TailType.left,
                    label: Text('H₁: μ < μ₀'),
                  ),
                  ButtonSegment(
                    value: _TailType.twoTailed,
                    label: Text('H₁: μ ≠ μ₀'),
                  ),
                  ButtonSegment(
                    value: _TailType.right,
                    label: Text('H₁: μ > μ₀'),
                  ),
                ],
                selected: {_tailType},
                onSelectionChanged: (v) {
                  setState(() => _tailType = v.first);
                  _calculate();
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Population σ is Known'),
                value: _isSigmaKnown,
                onChanged: (v) {
                  setState(() => _isSigmaKnown = v);
                  _calculate();
                },
              ),
              TextFormField(
                controller: _mu0Ctrl,
                decoration: const InputDecoration(
                  labelText: 'Hypothesized Mean (μ₀)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _xBarCtrl,
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
                  labelText: _isSigmaKnown ? 'Population σ' : 'Sample s',
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
                children: [0.10, 0.05, 0.01].map((a) {
                  return ChoiceChip(
                    label: Text('α = $a'),
                    selected: _alpha == a,
                    onSelected: (_) {
                      setState(() => _alpha = a);
                      _calculate();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.rule),
                label: const Text('Run Hypothesis Test'),
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

    final isRejected = res.title.contains('Reject');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (isRejected ? Colors.red : Colors.teal).withAlpha(
                      35,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    res.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isRejected
                          ? Colors.red.shade700
                          : Colors.teal.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _row('Method', res.methodUsed),
                _row(res.secondaryLabel!, res.secondaryValue!),
                if (res.leftCritical.isFinite)
                  _row(
                    'Left Critical Value',
                    res.leftCritical.toStringAsFixed(3),
                  ),
                if (res.rightCritical.isFinite)
                  _row(
                    'Right Critical Value',
                    res.rightCritical.toStringAsFixed(3),
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
