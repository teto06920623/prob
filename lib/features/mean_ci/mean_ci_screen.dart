import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/math/normal_dist.dart';
import '../../core/math/student_t_dist.dart';
import '../../core/models/ci_result.dart';
import '../chart_visualizer/distribution_chart_widget.dart';
import '../navigation/app_shell.dart';

enum _MeanInputMode { summary, rawList, sums }

class MeanCiScreen extends StatefulWidget {
  const MeanCiScreen({super.key});

  @override
  State<MeanCiScreen> createState() => _MeanCiScreenState();
}

class _MeanCiScreenState extends State<MeanCiScreen> {
  final _formKey = GlobalKey<FormState>();

  _MeanInputMode _inputMode = _MeanInputMode.summary;
  bool _isSigmaKnown = true; // هل تباين المجتمع معلوم؟
  double _confidenceLevel = 0.95;

  // متحكمات الإدخال (مُعبأة مسبقاً بمثال صفحة 8 من محاضرة 4 للتجربة الفورية)
  final _meanCtrl = TextEditingController(text: '15');
  final _stdCtrl = TextEditingController(text: '4');
  final _nCtrl = TextEditingController(text: '25');
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
    _rawCtrl.dispose();
    _sumXCtrl.dispose();
    _sumX2Ctrl.dispose();
    super.dispose();
  }

  void _calculate() {
    setState(() => _errorMessage = null);

    try {
      double xBar;
      double stdDev;
      int n;

      if (_inputMode == _MeanInputMode.summary) {
        xBar = double.parse(_meanCtrl.text.trim());
        stdDev = double.parse(_stdCtrl.text.trim());
        n = int.parse(_nCtrl.text.trim());
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
      } else {
        // وضع المجاميع: مثال صفحة 10 (n=40, sumX=280, sumX2=2100)
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
      }

      if (n < 2 || stdDev <= 0) {
        throw Exception('تأكد أن n ≥ 2 والانحراف المعياري > 0.');
      }

      final alpha = 1.0 - _confidenceLevel;
      final alphaOverTwo = alpha / 2.0;

      // قاعدة المحاضرة الرابعة: متى نستخدم Z ومتى نستخدم T؟
      final bool useZ = _isSigmaKnown || n >= 30;
      final double criticalVal = useZ
          ? NormalDist.criticalZ(alphaOverTwo)
          : StudentTDist.criticalT(alphaOverTwo, n - 1);

      final double se = stdDev / math.sqrt(n);
      final double marginOfError = criticalVal * se;
      final double lcl = xBar - marginOfError;
      final double ucl = xBar + marginOfError;

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
          secondaryLabel: useZ
              ? 'Critical Z_(α/2)'
              : 'Critical t_(α/2, ${n - 1})',
          secondaryValue: '±${criticalVal.toStringAsFixed(4)}',
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Population Mean (μ) Parameters',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // اختيار طريقة الإدخال
              SegmentedButton<_MeanInputMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _MeanInputMode.summary,
                    label: Text('Summary'),
                  ),
                  ButtonSegment(
                    value: _MeanInputMode.rawList,
                    label: Text('Raw Data'),
                  ),
                  ButtonSegment(
                    value: _MeanInputMode.sums,
                    label: Text('Σx, Σx²'),
                  ),
                ],
                selected: {_inputMode},
                onSelectionChanged: (val) {
                  setState(() => _inputMode = val.first);
                  _calculate();
                },
              ),
              const SizedBox(height: 14),

              // تحديد هل السيجما للــ البوبيولاشن معلوم أم مجهول
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
              const SizedBox(height: 8),

              // حقول الإدخال حسب الوضع المختار
              if (_inputMode == _MeanInputMode.summary) ...[
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
                  decoration: const InputDecoration(
                    labelText: 'Sample Size (n)',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ] else if (_inputMode == _MeanInputMode.rawList) ...[
                TextFormField(
                  controller: _rawCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Sample Values (comma or space separated)',
                    hintText: 'e.g. 12.5, 14.0, 13.2, 15.1',
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _nCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sample Size (n)',
                  ),
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
                label: const Text('Calculate Confidence Interval'),
              ),
            ],
          ),
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
                    '${res.lowerBound.toStringAsFixed(4)}  <  μ  <  ${res.upperBound.toStringAsFixed(4)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
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
