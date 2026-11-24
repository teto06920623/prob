// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/math/fisher_f_dist.dart';
import '../../core/math/normal_dist.dart';
import '../../core/models/ci_result.dart';
import '../chart_visualizer/distribution_chart_widget.dart';
import '../chart_visualizer/step_by_step_card.dart';
import '../navigation/app_shell.dart';

enum _ProbCategory { normalDist, samplingDist, fisherF }

enum _NormalQueryType {
  lessThan,
  greaterThan,
  between,
  inverseLeft,
  inverseRight,
}

enum _SamplingTarget { meanXBar, proportionPHat, varianceS2 }

class ProbabilitySamplingScreen extends StatefulWidget {
  const ProbabilitySamplingScreen({super.key});

  @override
  State<ProbabilitySamplingScreen> createState() =>
      _ProbabilitySamplingScreenState();
}

class _ProbabilitySamplingScreenState extends State<ProbabilitySamplingScreen> {
  _ProbCategory _category = _ProbCategory.normalDist;
  _NormalQueryType _normalQuery = _NormalQueryType.between;
  _SamplingTarget _samplingTarget = _SamplingTarget.proportionPHat;

  // Normal & Sampling Controllers
  final _meanCtrl = TextEditingController(text: '100');
  final _stdCtrl = TextEditingController(text: '15');
  final _nCtrl = TextEditingController(text: '200');
  final _propCtrl = TextEditingController(text: '0.40');
  final _aCtrl = TextEditingController(text: '85');
  final _bCtrl = TextEditingController(text: '120');
  final _targetProbCtrl = TextEditingController(text: '0.95');

  // Fisher F Controllers
  final _d1Ctrl = TextEditingController(text: '4');
  final _d2Ctrl = TextEditingController(text: '10');
  final _fAlphaCtrl = TextEditingController(text: '0.05');

  CiResult? _result;
  String? _conditionBadge;
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
    _propCtrl.dispose();
    _aCtrl.dispose();
    _bCtrl.dispose();
    _targetProbCtrl.dispose();
    _d1Ctrl.dispose();
    _d2Ctrl.dispose();
    _fAlphaCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(String key) {
    setState(() {
      if (key == 'lec1_p12') {
        // Lec 1 p.12: IQ ~ N(100, 15^2), P(85 < X < 120)
        _category = _ProbCategory.normalDist;
        _normalQuery = _NormalQueryType.between;
        _meanCtrl.text = '100';
        _stdCtrl.text = '15';
        _aCtrl.text = '85';
        _bCtrl.text = '120';
      } else if (key == 'lec1_p14') {
        // Lec 1 p.14: Inverse Z, P(Z < k) = 0.95
        _category = _ProbCategory.normalDist;
        _normalQuery = _NormalQueryType.inverseLeft;
        _meanCtrl.text = '0';
        _stdCtrl.text = '1';
        _targetProbCtrl.text = '0.95';
      } else if (key == 'lec3_p13') {
        // Lec 3 p.13: Smokers P = 0.40, n = 200, P(P_hat > 0.45)
        _category = _ProbCategory.samplingDist;
        _samplingTarget = _SamplingTarget.proportionPHat;
        _normalQuery = _NormalQueryType.greaterThan;
        _propCtrl.text = '0.40';
        _nCtrl.text = '200';
        _aCtrl.text = '0.45';
      } else if (key == 'lec2_f') {
        // Lec 2: Fisher F(4, 10) at alpha = 0.05 & 0.95
        _category = _ProbCategory.fisherF;
        _d1Ctrl.text = '4';
        _d2Ctrl.text = '10';
        _fAlphaCtrl.text = '0.05';
      }
    });
    _calculate();
  }

  void _calculate() {
    setState(() {
      _errorMessage = null;
      _conditionBadge = null;
    });

    try {
      if (_category == _ProbCategory.fisherF) {
        final d1 = int.parse(_d1Ctrl.text.trim());
        final d2 = int.parse(_d2Ctrl.text.trim());
        final alpha = double.parse(_fAlphaCtrl.text.trim());
        if (d1 < 1 || d2 < 1 || alpha <= 0 || alpha >= 1) {
          throw Exception('تأكد أن d₁, d₂ ≥ 1 وأن α بين 0 و 1.');
        }

        final fRight = FisherFDist.criticalF(alpha, d1, d2);
        final fLeft = FisherFDist.criticalF(
          1.0 - alpha,
          d1,
          d2,
        ); // 1 / F_alpha(d2, d1)

        setState(() {
          _result = CiResult(
            title: 'Fisher\'s F-Distribution — F(d₁ = $d1, d₂ = $d2)',
            methodUsed: 'Upper & Lower Critical Values (Lecture 2)',
            distType: DistributionType.fisherF,
            degreesOfFreedom: d1,
            degreesOfFreedom2: d2,
            alpha: alpha,
            pointEstimate: fRight,
            lowerBound: fLeft,
            upperBound: fRight,
            leftCritical: fLeft,
            rightCritical: fRight,
            secondaryLabel: 'Lower Tail F_(1-α, d₁, d₂)',
            secondaryValue: fLeft.toStringAsFixed(4),
            steps: [
              'Given: Numerator df d₁ = $d1, Denominator df d₂ = $d2, α = $alpha',
              'Right Critical Value: F_($alpha, $d1, $d2) = ${fRight.toStringAsFixed(4)}',
              'Reciprocal Property (Lecture 2): F_(${(1 - alpha).toStringAsFixed(3)}, $d1, $d2) = 1 / F_($alpha, $d2, $d1) = ${fLeft.toStringAsFixed(4)}',
            ],
          );
        });
        return;
      }

      if (_category == _ProbCategory.samplingDist &&
          _samplingTarget == _SamplingTarget.varianceS2) {
        final sigma2 = double.parse(_stdCtrl.text.trim());
        final n = int.parse(_nCtrl.text.trim());
        final a = double.parse(_aCtrl.text.trim());
        if (n < 2 || sigma2 <= 0 || a < 0) {
          throw Exception('تأكد من صحة القيم المدخلة.');
        }

        final df = n - 1;
        final chiStat = (df * a) / sigma2;
        final probGreater = _chiSquareRightTail(chiStat, df);
        final prob = _normalQuery == _NormalQueryType.lessThan
            ? (1.0 - probGreater)
            : probGreater;

        setState(() {
          _result = CiResult(
            title: 'Sampling Distribution of Variance (s²)',
            methodUsed: 'χ² = (n - 1)s² / σ² ~ χ²(df = $df)',
            distType: DistributionType.chiSquare,
            degreesOfFreedom: df,
            alpha: (1.0 - prob).clamp(0.0, 1.0),
            pointEstimate: prob,
            lowerBound: _normalQuery == _NormalQueryType.lessThan ? 0.0 : a,
            upperBound: _normalQuery == _NormalQueryType.lessThan
                ? a
                : double.infinity,
            leftCritical: _normalQuery == _NormalQueryType.lessThan
                ? double.negativeInfinity
                : chiStat,
            rightCritical: _normalQuery == _NormalQueryType.lessThan
                ? chiStat
                : double.infinity,
            isProbabilityMode: true,
            secondaryLabel: 'Computed χ² Statistic',
            secondaryValue: chiStat.toStringAsFixed(4),
            steps: [
              'Given: σ² = $sigma2, n = $n (df = $df), target s² = $a',
              'Transform to Chi-Square: χ² = [ ($n - 1) × $a ] / $sigma2 = ${chiStat.toStringAsFixed(4)}',
              'Probability: ${_normalQuery == _NormalQueryType.lessThan ? "P(s² < $a) = P(χ² < ${chiStat.toStringAsFixed(3)})" : "P(s² > $a) = P(χ² > ${chiStat.toStringAsFixed(3)})"} = ${prob.toStringAsFixed(4)}',
            ],
          );
        });
        return;
      }

      // حساب التوزيع الطبيعي أو توزيع المعاينة للمتوسط أو النسبة
      double center;
      double scale;
      String varSymbol = 'X';
      final List<String> steps = [];

      if (_category == _ProbCategory.normalDist) {
        center = double.parse(_meanCtrl.text.trim());
        scale = double.parse(_stdCtrl.text.trim());
        if (scale <= 0) {
          throw Exception('الانحراف المعياري σ يجب أن يكون أكبر من الصفر.');
        }
        steps.add(
          'Given: X ~ N(μ = $center, σ² = ${(scale * scale).toStringAsFixed(4)})',
        );
      } else if (_samplingTarget == _SamplingTarget.meanXBar) {
        center = double.parse(_meanCtrl.text.trim());
        final sigma = double.parse(_stdCtrl.text.trim());
        final n = int.parse(_nCtrl.text.trim());
        if (n < 1 || sigma <= 0) throw Exception('تأكد أن n ≥ 1 و σ > 0.');
        scale = sigma / math.sqrt(n);
        varSymbol = 'X̄';
        steps.add(
          'Sampling Distribution of Mean: X̄ ~ N(μ = $center, SE = σ/√n = ${scale.toStringAsFixed(4)})',
        );
      } else {
        final p = double.parse(_propCtrl.text.trim());
        final n = int.parse(_nCtrl.text.trim());
        if (p <= 0 || p >= 1 || n < 1) {
          throw Exception('تأكد أن P بين 0 و 1 و n ≥ 1.');
        }
        final np = n * p;
        final nq = n * (1.0 - p);
        final isValid = np >= 5.0 && nq >= 5.0;
        _conditionBadge = isValid
            ? 'Normal Approx Valid: nP = ${np.toStringAsFixed(1)} ≥ 5 & n(1-P) = ${nq.toStringAsFixed(1)} ≥ 5'
            : 'Warning: nP = ${np.toStringAsFixed(1)} or n(1-P) = ${nq.toStringAsFixed(1)} < 5';
        center = p;
        scale = math.sqrt((p * (1.0 - p)) / n);
        varSymbol = 'P̂';
        steps.add(
          'Condition Check (Lec 3): nP = ${np.toStringAsFixed(1)}, n(1-P) = ${nq.toStringAsFixed(1)} (${isValid ? "Both ≥ 5 ✓" : "< 5 ⚠"})',
        );
        steps.add(
          'Standard Error: SE = √[ P(1 - P) / n ] = ${scale.toStringAsFixed(5)}',
        );
      }

      if (_normalQuery == _NormalQueryType.inverseLeft ||
          _normalQuery == _NormalQueryType.inverseRight) {
        final targetP = double.parse(_targetProbCtrl.text.trim());
        if (targetP <= 0 || targetP >= 1) {
          throw Exception('الاحتمال المطلوب يجب أن يكون بين 0 و 1.');
        }
        final z = _normalQuery == _NormalQueryType.inverseLeft
            ? NormalDist.criticalZ(1.0 - targetP)
            : NormalDist.criticalZ(targetP);
        final kVal = center + z * scale;

        steps.add(
          'Given Target Probability: ${_normalQuery == _NormalQueryType.inverseLeft ? "P($varSymbol < k) = $targetP" : "P($varSymbol > k) = $targetP"}',
        );
        steps.add('From Z-Table: Z = ${z.toStringAsFixed(4)}');
        steps.add(
          'Inverse Transformation: k = μ + Z·σ = $center + (${z.toStringAsFixed(4)}) × ${scale.toStringAsFixed(4)} = ${kVal.toStringAsFixed(4)}',
        );

        setState(() {
          _result = CiResult(
            title: 'Inverse Normal Value: k = ${kVal.toStringAsFixed(4)}',
            methodUsed: 'Z-Score = ${z.toStringAsFixed(4)}',
            distType: DistributionType.normal,
            alpha: (1.0 - targetP).clamp(0.0, 1.0),
            pointEstimate: center,
            lowerBound: _normalQuery == _NormalQueryType.inverseLeft
                ? double.negativeInfinity
                : kVal,
            upperBound: _normalQuery == _NormalQueryType.inverseLeft
                ? kVal
                : double.infinity,
            leftCritical: _normalQuery == _NormalQueryType.inverseLeft
                ? double.negativeInfinity
                : z,
            rightCritical: _normalQuery == _NormalQueryType.inverseLeft
                ? z
                : double.infinity,
            isProbabilityMode: true,
            secondaryLabel: 'Critical Z-Score',
            secondaryValue: z.toStringAsFixed(4),
            steps: steps,
          );
        });
        return;
      }

      final a = double.parse(_aCtrl.text.trim());
      double prob;
      double leftCrit = double.negativeInfinity;
      double rightCrit = double.infinity;
      double lBound = double.negativeInfinity;
      double uBound = double.infinity;
      String queryTitle;

      if (_normalQuery == _NormalQueryType.lessThan) {
        final zA = (a - center) / scale;
        prob = NormalDist.cdf(zA);
        rightCrit = zA;
        uBound = a;
        queryTitle = 'P($varSymbol < $a) = ${prob.toStringAsFixed(4)}';
        steps.add(
          'Standardize: Z = ($a - ${center.toStringAsFixed(3)}) / ${scale.toStringAsFixed(4)} = ${zA.toStringAsFixed(4)}',
        );
        steps.add(
          'From Z-Table: Φ(${zA.toStringAsFixed(3)}) = ${prob.toStringAsFixed(4)} (${(prob * 100).toStringAsFixed(2)}%)',
        );
      } else if (_normalQuery == _NormalQueryType.greaterThan) {
        final zA = (a - center) / scale;
        prob = 1.0 - NormalDist.cdf(zA);
        leftCrit = zA;
        lBound = a;
        queryTitle = 'P($varSymbol > $a) = ${prob.toStringAsFixed(4)}';
        steps.add(
          'Standardize: Z = ($a - ${center.toStringAsFixed(3)}) / ${scale.toStringAsFixed(4)} = ${zA.toStringAsFixed(4)}',
        );
        steps.add(
          'From Z-Table: 1 - Φ(${zA.toStringAsFixed(3)}) = ${prob.toStringAsFixed(4)} (${(prob * 100).toStringAsFixed(2)}%)',
        );
      } else {
        final b = double.parse(_bCtrl.text.trim());
        if (b <= a) throw Exception('القيمة العليا b يجب أن تكون أكبر من a.');
        final zA = (a - center) / scale;
        final zB = (b - center) / scale;
        prob = (NormalDist.cdf(zB) - NormalDist.cdf(zA)).clamp(0.0, 1.0);
        leftCrit = zA;
        rightCrit = zB;
        lBound = a;
        uBound = b;
        queryTitle = 'P($a < $varSymbol < $b) = ${prob.toStringAsFixed(4)}';
        steps.add(
          'Standardize: Z₁ = ${zA.toStringAsFixed(4)},  Z₂ = ${zB.toStringAsFixed(4)}',
        );
        steps.add(
          'From Z-Table: Φ(${zB.toStringAsFixed(3)}) - Φ(${zA.toStringAsFixed(3)}) = ${prob.toStringAsFixed(4)} (${(prob * 100).toStringAsFixed(2)}%)',
        );
      }

      setState(() {
        _result = CiResult(
          title: queryTitle,
          methodUsed:
              'Standard Normal Transformation — Z = ($varSymbol - μ) / SE',
          distType: DistributionType.normal,
          alpha: (1.0 - prob).clamp(0.0, 1.0),
          pointEstimate: center,
          lowerBound: lBound,
          upperBound: uBound,
          standardError: scale,
          leftCritical: leftCrit,
          rightCritical: rightCrit,
          isProbabilityMode: true,
          secondaryLabel: 'Percentage',
          secondaryValue: '${(prob * 100).toStringAsFixed(2)}%',
          steps: steps,
        );
      });
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  double _chiSquareRightTail(double x, int df) {
    if (x <= 0) return 1.0;
    final a = df / 2.0;
    final z = x / 2.0;
    double sum = 1.0 / a;
    double term = sum;
    for (int n = 1; n < 250; n++) {
      term *= z / (a + n);
      sum += term;
      if (term.abs() < 1e-12) break;
    }
    double logGammaA = 0.0;
    for (int i = 1; i < df; i += 2) {
      logGammaA += math.log(i / 2.0);
    }
    if (df.isOdd) logGammaA += 0.5 * math.log(math.pi);
    final cdf = math.exp(a * math.log(z) - z - logGammaA) * sum;
    return (1.0 - cdf).clamp(0.0, 1.0);
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
                      'Probabilities & Sampling (Lec 1–3)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Lectures 1–3 Examples',
                    icon: const Icon(Icons.auto_stories_outlined),
                    onSelected: _applyPreset,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'lec1_p12',
                        child: Text('Lec 1 (p.12): IQ P(85 < X < 120)'),
                      ),
                      PopupMenuItem(
                        value: 'lec1_p14',
                        child: Text('Lec 1 (p.14): Find k for P(Z < k)=0.95'),
                      ),
                      PopupMenuItem(
                        value: 'lec3_p13',
                        child: Text('Lec 3 (p.13): Smokers P(P̂ > 0.45)'),
                      ),
                      PopupMenuItem(
                        value: 'lec2_f',
                        child: Text('Lec 2: Fisher F(4, 10) Criticals'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<_ProbCategory>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _ProbCategory.normalDist,
                    label: Text('Normal', maxLines: 1, softWrap: false),
                  ),
                  ButtonSegment(
                    value: _ProbCategory.samplingDist,
                    label: Text('Sampling', maxLines: 1, softWrap: false),
                  ),
                  ButtonSegment(
                    value: _ProbCategory.fisherF,
                    label: Text('Fisher F', maxLines: 1, softWrap: false),
                  ),
                ],
                selected: {_category},
                onSelectionChanged: (v) {
                  setState(() => _category = v.first);
                  _calculate();
                },
              ),
              const SizedBox(height: 12),
              if (_category == _ProbCategory.fisherF) ...[
                TextFormField(
                  controller: _d1Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Numerator Degrees of Freedom (d₁)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _d2Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Denominator Degrees of Freedom (d₂)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fAlphaCtrl,
                  decoration: const InputDecoration(labelText: 'Tail Area (α)'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ] else ...[
                if (_category == _ProbCategory.samplingDist) ...[
                  SegmentedButton<_SamplingTarget>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _SamplingTarget.meanXBar,
                        label: Text('Mean X̄', maxLines: 1, softWrap: false),
                      ),
                      ButtonSegment(
                        value: _SamplingTarget.proportionPHat,
                        label: Text('Prop P̂', maxLines: 1, softWrap: false),
                      ),
                      ButtonSegment(
                        value: _SamplingTarget.varianceS2,
                        label: Text('Var s²', maxLines: 1, softWrap: false),
                      ),
                    ],
                    selected: {_samplingTarget},
                    onSelectionChanged: (v) {
                      setState(() => _samplingTarget = v.first);
                      _calculate();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (_category == _ProbCategory.normalDist ||
                    _samplingTarget == _SamplingTarget.meanXBar) ...[
                  TextFormField(
                    controller: _meanCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Population Mean (μ)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
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
                ] else if (_samplingTarget ==
                    _SamplingTarget.proportionPHat) ...[
                  TextFormField(
                    controller: _propCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Population Proportion (P)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _stdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Population Variance (σ²)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
                if (_category == _ProbCategory.samplingDist) ...[
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
                DropdownButtonFormField<_NormalQueryType>(
                  value: _normalQuery,
                  decoration: const InputDecoration(
                    labelText: 'Probability Query Type',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: _NormalQueryType.lessThan,
                      child: Text('P(X < a) — Left Tail'),
                    ),
                    DropdownMenuItem(
                      value: _NormalQueryType.greaterThan,
                      child: Text('P(X > a) — Right Tail'),
                    ),
                    DropdownMenuItem(
                      value: _NormalQueryType.between,
                      child: Text('P(a < X < b) — Between'),
                    ),
                    DropdownMenuItem(
                      value: _NormalQueryType.inverseLeft,
                      child: Text('Find k where P(X < k) = p'),
                    ),
                    DropdownMenuItem(
                      value: _NormalQueryType.inverseRight,
                      child: Text('Find k where P(X > k) = p'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _normalQuery = v);
                      _calculate();
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (_normalQuery == _NormalQueryType.inverseLeft ||
                    _normalQuery == _NormalQueryType.inverseRight)
                  TextFormField(
                    controller: _targetProbCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Target Probability (p between 0 and 1)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  )
                else ...[
                  TextFormField(
                    controller: _aCtrl,
                    decoration: const InputDecoration(labelText: 'Value (a)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                  if (_normalQuery == _NormalQueryType.between) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Upper Value (b)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.functions),
                label: const Text('Calculate Probability'),
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
                if (_conditionBadge != null) ...[
                  Chip(label: Text(_conditionBadge!)),
                  const SizedBox(height: 8),
                ],
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
                    res.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(res.secondaryLabel ?? 'Value'),
                    SelectableText(
                      res.secondaryValue ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
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
}
