import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/math/chi_square_dist.dart';
import '../../core/math/normal_dist.dart';
import '../../core/math/student_t_dist.dart';
import '../../core/models/ci_result.dart';
import '../../core/theme/app_theme.dart';

class DistributionPainter extends CustomPainter {
  final CiResult result;
  final bool
  showActualScale; // true = يعرض (LCL, PointEstimate, UCL) | false = يعرض (-Z/T, 0, Z/T)
  final Color axisColor;
  final Color curveColor;
  final Color textColor;

  DistributionPainter({
    required this.result,
    this.showActualScale = true,
    required this.axisColor,
    required this.curveColor,
    required this.textColor,
  });

  double _pdf(double x) {
    switch (result.distType) {
      case DistributionType.normal:
        return NormalDist.pdf(x);
      case DistributionType.studentT:
        return StudentTDist.pdf(x, result.degreesOfFreedom);
      case DistributionType.chiSquare:
        return ChiSquareDist.pdf(x, result.degreesOfFreedom);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPad = 16.0;
    const double rightPad = 16.0;
    const double topPad = 24.0;
    const double bottomPad = 42.0;

    final double plotWidth = size.width - leftPad - rightPad;
    final double plotHeight = size.height - topPad - bottomPad;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    // 1. تحديد حدود المحور السيني حسب نوع التوزيع
    double minX;
    double maxX;

    if (result.distType == DistributionType.chiSquare) {
      minX = 0.0;
      final df = result.degreesOfFreedom.toDouble();
      final stdRange = df + 4.0 * math.sqrt(2.0 * df);
      final critRange = result.rightCritical.isFinite
          ? result.rightCritical * 1.25
          : 10.0;
      maxX = math.max(10.0, math.max(stdRange, critRange));
    } else {
      double extreme = 3.8;
      if (result.leftCritical.isFinite) {
        extreme = math.max(extreme, result.leftCritical.abs() * 1.3);
      }
      if (result.rightCritical.isFinite) {
        extreme = math.max(extreme, result.rightCritical.abs() * 1.3);
      }
      if (result.testValue != null && result.testValue!.isFinite) {
        extreme = math.max(
          extreme,
          math.min(6.0, result.testValue!.abs() * 1.2),
        );
      }
      minX = -extreme;
      maxX = extreme;
    }

    // 2. إيجاد أعلى نقطة (maxY) لضبط مقياس الرسم الرأسي
    const int samples = 240;
    double maxY = 0.0;
    final double startX = result.distType == DistributionType.chiSquare
        ? (result.degreesOfFreedom <= 2 ? 0.08 : 0.0)
        : minX;
    for (int i = 0; i <= samples; i++) {
      final x = startX + (maxX - startX) * (i / samples);
      final y = _pdf(x);
      if (y.isFinite && y > maxY) maxY = y;
    }
    if (maxY <= 0) maxY = 0.4;

    double toPixelX(double x) =>
        leftPad + ((x - minX) / (maxX - minX)) * plotWidth;
    double toPixelY(double y) =>
        topPad + plotHeight - ((y / maxY).clamp(0.0, 1.15)) * plotHeight;
    final double baselineY = topPad + plotHeight;

    // دالة مساعدة لتظليل مساحة تحت المنحنى بين a و b
    void fillRegion(double a, double b, Color color) {
      final clampedA = a.clamp(startX, maxX);
      final clampedB = b.clamp(startX, maxX);
      if (clampedB <= clampedA) return;

      final path = Path()..moveTo(toPixelX(clampedA), baselineY);
      const int regionSteps = 90;
      for (int i = 0; i <= regionSteps; i++) {
        final x = clampedA + (clampedB - clampedA) * (i / regionSteps);
        path.lineTo(toPixelX(x), toPixelY(_pdf(x)));
      }
      path
        ..lineTo(toPixelX(clampedB), baselineY)
        ..close();

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withAlpha(75);
      canvas.drawPath(path, paint);
    }

    final double leftBound = result.leftCritical.isFinite
        ? result.leftCritical
        : minX;
    final double rightBound = result.rightCritical.isFinite
        ? result.rightCritical
        : maxX;

    // 3. تظليل الذيل الأيسر، منطقة الثقة/القبول الوسطى، والذيل الأيمن
    if (result.leftCritical.isFinite) {
      fillRegion(startX, leftBound, AppTheme.rejectTailColor);
    }
    fillRegion(leftBound, rightBound, AppTheme.acceptRegionColor);
    if (result.rightCritical.isFinite) {
      fillRegion(rightBound, maxX, AppTheme.rejectTailColor);
    }

    // 4. رسم خط المنحنى الرئيسي
    final curvePath = Path();
    for (int i = 0; i <= samples; i++) {
      final x = startX + (maxX - startX) * (i / samples);
      final px = toPixelX(x);
      final py = toPixelY(_pdf(x));
      if (i == 0) {
        curvePath.moveTo(px, py);
      } else {
        curvePath.lineTo(px, py);
      }
    }
    canvas.drawPath(
      curvePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = curveColor,
    );

    // 5. رسم المحاور (X-Axis & Y-Axis) مع الأسهم ونقطة الأصل
    final axisPaint = Paint()
      ..strokeWidth = 1.5
      ..color = axisColor;

    // المحور الأفقي (X-Axis) + سهم اليمين
    final rightEndX = size.width - rightPad;
    canvas.drawLine(
      Offset(leftPad, baselineY),
      Offset(rightEndX, baselineY),
      axisPaint,
    );
    canvas.drawLine(
      Offset(rightEndX - 6, baselineY - 4),
      Offset(rightEndX, baselineY),
      axisPaint,
    );
    canvas.drawLine(
      Offset(rightEndX - 6, baselineY + 4),
      Offset(rightEndX, baselineY),
      axisPaint,
    );

    // تحديد هل نعرض القيم الفعلية للمسألة أم القيم المعيارية (Z/T)
    final bool useActual =
        showActualScale &&
        result.testValue == null &&
        result.distType != DistributionType.chiSquare;

    if (result.distType == DistributionType.chiSquare) {
      // المحور الرأسي (Y-Axis) عند x = 0 لتوزيع Chi-Square + سهم لأعلى
      canvas.drawLine(
        Offset(leftPad, topPad),
        Offset(leftPad, baselineY),
        axisPaint,
      );
      canvas.drawLine(
        Offset(leftPad - 4, topPad + 6),
        Offset(leftPad, topPad),
        axisPaint,
      );
      canvas.drawLine(
        Offset(leftPad + 4, topPad + 6),
        Offset(leftPad, topPad),
        axisPaint,
      );

      // كتابة نقطة الأصل 0 واسم المحور χ²
      _drawAxisLabel(
        canvas,
        '0',
        leftPad,
        baselineY + 6,
        size.width,
        isBold: true,
      );
      _drawAxisLabel(
        canvas,
        'χ²',
        rightEndX - 4,
        baselineY - 18,
        size.width,
        isBold: true,
      );
    } else {
      // المحور الرأسي في المنتصف للتوزيعات المتماثلة (Z و T)
      final zeroPx = toPixelX(0);
      canvas.drawLine(
        Offset(zeroPx, topPad + 4),
        Offset(zeroPx, baselineY),
        Paint()
          ..strokeWidth = 1.2
          ..color = axisColor.withAlpha(140),
      );
      final centerLabel = useActual
          ? result.pointEstimate.toStringAsFixed(2)
          : '0';
      _drawAxisLabel(
        canvas,
        centerLabel,
        zeroPx,
        baselineY + 6,
        size.width,
        color: useActual ? AppTheme.acceptRegionColor : textColor,
        isBold: useActual,
      );
    }

    // 6. رسم الخطوط الرأسية للقيم الحرجة وطباعة أرقامها
    void drawCriticalLine(double critVal, {double? boundVal}) {
      if (!critVal.isFinite || critVal < minX || critVal > maxX) return;
      final px = toPixelX(critVal);
      final py = toPixelY(_pdf(critVal));
      canvas.drawLine(
        Offset(px, py),
        Offset(px, baselineY),
        Paint()
          ..strokeWidth = 1.8
          ..color = AppTheme.rejectTailColor,
      );

      final labelVal = (useActual && boundVal != null) ? boundVal : critVal;
      _drawAxisLabel(
        canvas,
        labelVal.toStringAsFixed(3),
        px,
        baselineY + 6,
        size.width,
        color: AppTheme.rejectTailColor,
        isBold: true,
      );
    }

    drawCriticalLine(result.leftCritical, boundVal: result.lowerBound);
    drawCriticalLine(result.rightCritical, boundVal: result.upperBound);

    // 7. رسم مؤشر قيمة الاختبار المحسوبة (إن وُجدت في شاشة Hypothesis Test)
    if (result.testValue != null && result.testValue!.isFinite) {
      final clampedTest = result.testValue!.clamp(minX, maxX);
      final px = toPixelX(clampedTest);
      canvas.drawLine(
        Offset(px, topPad),
        Offset(px, baselineY),
        Paint()
          ..strokeWidth = 2.0
          ..color = curveColor,
      );
      canvas.drawCircle(
        Offset(px, baselineY),
        4.5,
        Paint()..color = curveColor,
      );
      _drawAxisLabel(
        canvas,
        'Stat=${result.testValue!.toStringAsFixed(2)}',
        px,
        topPad - 18,
        size.width,
        color: curveColor,
        isBold: true,
      );
    }
  }

  void _drawAxisLabel(
    Canvas canvas,
    String text,
    double centerX,
    double topY,
    double maxWidth, {
    Color? color,
    bool isBold = false,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? textColor,
          fontSize: 11.5,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dx = (centerX - textPainter.width / 2).clamp(
      4.0,
      maxWidth - textPainter.width - 4.0,
    );
    textPainter.paint(canvas, Offset(dx, topY));
  }

  @override
  bool shouldRepaint(covariant DistributionPainter oldDelegate) {
    return oldDelegate.result != result ||
        oldDelegate.curveColor != curveColor ||
        oldDelegate.showActualScale != showActualScale;
  }
}
