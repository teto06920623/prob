import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/math/normal_dist.dart';
import '../../core/math/student_t_dist.dart';
import '../../core/models/ci_result.dart';
import '../chart_visualizer/distribution_chart_widget.dart';
import '../chart_visualizer/step_by_step_card.dart';
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
  bool _isRawData = false;
  double _alpha = 0.05;

  final _mu0Ctrl = TextEditingController(text: '42000');
  final _xBarCtrl = TextEditingController(text: '43260');
  final _stdCtrl = TextEditingController(text: '5230');
  final _nCtrl = TextEditingController(text: '30');
  final _rawCtrl = TextEditingController(
    text:
        '60, 70, 75, 55, 80, 55, 50, 40, 80, 70, 50, 95, 120, 90, 75, 85, 80, 60, 110, 65, 80, 85, 85, 95, 75, 60, 90, 90, 60, 45, 110, 85, 45, 90, 70, 70',
  );

  CiResult? _result;
  String? _pValueStr;
  String? _ciMethodStr;
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
    _rawCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(String key) {
    setState(() {
      if (key == 'lec6_p15') {
        _isRawData = false;
        _isSigmaKnown = true;
        _tailType = _TailType.right;
        _alpha = 0.05;
        _mu0Ctrl.text = '42000';
        _xBarCtrl.text = '43260';
        _stdCtrl.text = '5230';
        _nCtrl.text = '30';
      } else if (key == 'lec6_p17') {
        // مسألة الأحذية الرياضية ص 17 (36 قيمة، sigma=19.2، alpha=0.10، H1: mu < 80)
        _isRawData = true;
        _isSigmaKnown = true;
        _tailType = _TailType.left;
        _alpha = 0.10;
        _mu0Ctrl.text = '80';
        _stdCtrl.text = '19.2';
      }
    });
    _calculate();
  }

  void _calculate() {
    setState(() => _errorMessage = null);
    try {
      final mu0 = double.parse(_mu0Ctrl.text.trim());
      double xBar;
      double std;
      int n;
      final List<String> steps = [];

      if (_isRawData) {
        final values = _rawCtrl.text
            .split(RegExp(r'[,\s]+'))
            .where((e) => e.trim().isNotEmpty)
            .map(double.parse)
            .toList();
        if (values.length < 2) throw Exception('أدخل قيمتين على الأقل.');
        n = values.length;
        xBar = values.reduce((a, b) => a + b) / n;
        if (_isSigmaKnown) {
          std = double.parse(_stdCtrl.text.trim());
        } else {
          final s2 =
              values.fold(0.0, (sum, x) => sum + math.pow(x - xBar, 2)) /
              (n - 1);
          std = math.sqrt(s2);
        }
        steps.add(
          'From $n raw values: X̄ = Σx / n = ${xBar.toStringAsFixed(4)}',
        );
      } else {
        xBar = double.parse(_xBarCtrl.text.trim());
        std = double.parse(_stdCtrl.text.trim());
        n = int.parse(_nCtrl.text.trim());
      }

      if (n < 2 || std <= 0) throw Exception('تأكد أن n ≥ 2 والانحراف > 0.');

      final useZ = _isSigmaKnown || n >= 30;
      final df = n - 1;
      final se = std / math.sqrt(n);
      final testStat = (xBar - mu0) / se;

      double leftCrit = double.negativeInfinity;
      double rightCrit = double.infinity;
      bool rejectH0 = false;
      double pValue = 0.0;
      String h1Text;

      if (_tailType == _TailType.left) {
        h1Text = 'H₁: μ < $mu0 (Left-Tailed)';
        final crit = useZ
            ? NormalDist.criticalZ(_alpha)
            : StudentTDist.criticalT(_alpha, df);
        leftCrit = -crit;
        rejectH0 = testStat < leftCrit;
        pValue = useZ
            ? NormalDist.cdf(testStat)
            : (testStat < 0
                  ? StudentTDist.rightTailProb(-testStat, df)
                  : 1.0 - StudentTDist.rightTailProb(testStat, df));
      } else if (_tailType == _TailType.right) {
        h1Text = 'H₁: μ > $mu0 (Right-Tailed)';
        final crit = useZ
            ? NormalDist.criticalZ(_alpha)
            : StudentTDist.criticalT(_alpha, df);
        rightCrit = crit;
        rejectH0 = testStat > rightCrit;
        pValue = useZ
            ? 1.0 - NormalDist.cdf(testStat)
            : (testStat > 0
                  ? StudentTDist.rightTailProb(testStat, df)
                  : 1.0 - StudentTDist.rightTailProb(-testStat, df));
      } else {
        h1Text = 'H₁: μ ≠ $mu0 (Two-Tailed)';
        final crit = useZ
            ? NormalDist.criticalZ(_alpha / 2.0)
            : StudentTDist.criticalT(_alpha / 2.0, df);
        leftCrit = -crit;
        rightCrit = crit;
        rejectH0 = testStat < leftCrit || testStat > rightCrit;
        final singleTail = useZ
            ? (1.0 - NormalDist.cdf(testStat.abs()))
            : StudentTDist.rightTailProb(testStat.abs(), df);
        pValue = (2.0 * singleTail).clamp(0.0, 1.0);
      }

      // حساب فترة الثقة المقابلة (طريقة CI Method من محاضرة 6 ص 2)
      final twoTailCrit = useZ
          ? NormalDist.criticalZ(_alpha / 2.0)
          : StudentTDist.criticalT(_alpha / 2.0, df);
      final ciLcl = xBar - twoTailCrit * se;
      final ciUcl = xBar + twoTailCrit * se;

      final statSymbol = useZ ? 'Z' : 'T';
      steps.add('Step 1 (Hypotheses): H₀: μ = $mu0  vs  $h1Text');
      steps.add(
        'Step 2 (Critical Value at α = $_alpha): ${leftCrit.isFinite ? "Left = ${leftCrit.toStringAsFixed(3)} " : ""}${rightCrit.isFinite ? "Right = ${rightCrit.toStringAsFixed(3)}" : ""}',
      );
      steps.add(
        'Step 3 (Test Statistic): $statSymbol = (X̄ - μ₀) / (${_isSigmaKnown ? "σ" : "s"} / √n) = (${xBar.toStringAsFixed(2)} - $mu0) / ($std / √$n) = ${testStat.toStringAsFixed(4)}',
      );
      steps.add(
        'Step 4 (Decision): ${rejectH0 ? "Test value falls in Rejection Region ⇒ Reject H₀ (Significant)" : "Test value falls in Acceptance Region ⇒ Accept H₀ (Not Significant)"}',
      );
      steps.add(
        'P-Value Check: P-value = ${pValue.toStringAsFixed(4)} ${pValue <= _alpha ? "≤" : ">"} α ($_alpha)',
      );

      setState(() {
        _pValueStr =
            '${pValue.toStringAsFixed(4)} (${pValue <= _alpha ? "≤ α ⇒ Reject H₀" : "> α ⇒ Accept H₀"})';
        _ciMethodStr =
            '${ciLcl.toStringAsFixed(2)} < μ < ${ciUcl.toStringAsFixed(2)}';
        _result = CiResult(
          title: rejectH0
              ? 'Decision: Reject H₀ (Significant)'
              : 'Decision: Accept H₀ (Not Significant)',
          methodUsed: useZ
              ? 'Z-Test (α = $_alpha)'
              : 'T-Test (df = $df, α = $_alpha)',
          distType: useZ ? DistributionType.normal : DistributionType.studentT,
          degreesOfFreedom: df,
          alpha: _alpha,
          pointEstimate: testStat,
          lowerBound: leftCrit,
          upperBound: rightCrit,
          leftCritical: leftCrit,
          rightCritical: rightCrit,
          testValue: testStat,
          secondaryLabel: 'Test Statistic ($statSymbol)',
          secondaryValue: testStat.toStringAsFixed(4),
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
                      'Hypothesis Testing for Mean (μ)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Lecture 6 Examples',
                    icon: const Icon(Icons.auto_stories_outlined),
                    onSelected: _applyPreset,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'lec6_p15',
                        child: Text('Lec 6 (p.15): Professors Salary'),
                      ),
                      PopupMenuItem(
                        value: 'lec6_p17',
                        child: Text('Lec 6 (p.17): 36 Shoes (Raw Data)'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<_TailType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _TailType.left,
                    label: Text('μ < μ₀', maxLines: 1, softWrap: false),
                  ),
                  ButtonSegment(
                    value: _TailType.twoTailed,
                    label: Text('μ ≠ μ₀', maxLines: 1, softWrap: false),
                  ),
                  ButtonSegment(
                    value: _TailType.right,
                    label: Text('μ > μ₀', maxLines: 1, softWrap: false),
                  ),
                ],
                selected: {_tailType},
                onSelectionChanged: (v) {
                  setState(() => _tailType = v.first);
                  _calculate();
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Population σ is Known'),
                value: _isSigmaKnown,
                onChanged: (v) {
                  setState(() => _isSigmaKnown = v);
                  _calculate();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enter Raw Sample Values'),
                value: _isRawData,
                onChanged: (v) {
                  setState(() => _isRawData = v);
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
              if (_isRawData) ...[
                TextFormField(
                  controller: _rawCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Sample Values (comma/space separated)',
                  ),
                ),
                if (_isSigmaKnown) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Population Std Dev (σ)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ] else ...[
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
                  decoration: const InputDecoration(
                    labelText: 'Sample Size (n)',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
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
                if (_pValueStr != null) _row('P-Value Method', _pValueStr!),
                if (_ciMethodStr != null)
                  _row(
                    '${((1 - _alpha) * 100).toStringAsFixed(0)}% CI Method',
                    _ciMethodStr!,
                  ),
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
        Flexible(
          child: SelectableText(
            v,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
