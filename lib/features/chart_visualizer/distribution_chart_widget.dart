import 'package:flutter/material.dart';
import '../../core/models/ci_result.dart';
import '../../core/theme/app_theme.dart';
import 'distribution_painter.dart';

class DistributionChartWidget extends StatefulWidget {
  final CiResult result;

  const DistributionChartWidget({super.key, required this.result});

  @override
  State<DistributionChartWidget> createState() =>
      _DistributionChartWidgetState();
}

class _DistributionChartWidgetState extends State<DistributionChartWidget> {
  bool _showActualScale = true;

  bool get _isPositiveOnly =>
      widget.result.distType == DistributionType.chiSquare ||
      widget.result.distType == DistributionType.fisherF;

  (String, String) _getDistributionHeader() {
    switch (widget.result.distType) {
      case DistributionType.normal:
        return _showActualScale &&
                widget.result.testValue == null &&
                !widget.result.isSampleSizeMode
            ? (
                'Sampling Distribution',
                'N(${widget.result.pointEstimate.toStringAsFixed(2)}, SE²)',
              )
            : ('Standard Normal Distribution', 'Z ~ N(0, 1)');
      case DistributionType.studentT:
        return _showActualScale && widget.result.testValue == null
            ? (
                'Sample Mean Distribution',
                't(df = ${widget.result.degreesOfFreedom})',
              )
            : (
                'Student\'s t-Distribution',
                'T ~ t(df = ${widget.result.degreesOfFreedom})',
              );
      case DistributionType.chiSquare:
        return (
          'Chi-Square Distribution',
          'χ²(df = ${widget.result.degreesOfFreedom})',
        );
      case DistributionType.fisherF:
        return (
          'Fisher\'s F-Distribution',
          'F(d₁ = ${widget.result.degreesOfFreedom}, d₂ = ${widget.result.degreesOfFreedom2})',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canToggleScale =
        widget.result.testValue == null &&
        !widget.result.isSampleSizeMode &&
        !_isPositiveOnly;

    final (distTitle, distFormula) = _getDistributionHeader();

    final acceptLabel = widget.result.isProbabilityMode
        ? 'Target Probability (${((1 - widget.result.alpha) * 100).toStringAsFixed(2)}%)'
        : 'Confidence / Accept (${((1 - widget.result.alpha) * 100).toStringAsFixed(1)}%)';

    final rejectLabel = widget.result.isProbabilityMode
        ? 'Complement Area (${(widget.result.alpha * 100).toStringAsFixed(2)}%)'
        : 'Critical Region (α = ${widget.result.alpha.toStringAsFixed(3)})';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        distTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        distFormula,
                        maxLines: 1,
                        softWrap: false,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canToggleScale)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(_showActualScale ? 'Show Z/T' : 'Show Values'),
                    onPressed: () =>
                        setState(() => _showActualScale = !_showActualScale),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _LegendItem(
                  color: AppTheme.acceptRegionColor,
                  label: acceptLabel,
                ),
                _LegendItem(
                  color: AppTheme.rejectTailColor,
                  label: rejectLabel,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 230,
              width: double.infinity,
              child: CustomPaint(
                painter: DistributionPainter(
                  result: widget.result,
                  showActualScale: _showActualScale,
                  axisColor: colorScheme.outline,
                  curveColor: colorScheme.primary,
                  textColor: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withAlpha(180),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
