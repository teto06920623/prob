import 'dart:math' as math;
import 'normal_dist.dart';

class ChiSquareDist {
  /// دالة الكثافة الاحتمالية (PDF) لرسم منحنى Chi-Square (x > 0)
  static double pdf(double x, int df) {
    if (x <= 0) return 0.0;
    final k = df.toDouble();
    final halfK = k / 2.0;
    final logVal = (halfK - 1.0) * math.log(x) -
        (x / 2.0) -
        (halfK * math.ln2 + NormalDist.logGamma(halfK));
    return math.exp(logVal);
  }

  /// احتمال الذيل الأيمن P(Chi^2 > x)
  static double upperTailProb(double x, int df) {
    if (x <= 0) return 1.0;
    return _regularizedGammaQ(df / 2.0, x / 2.0);
  }

  /// استخراج القيمة الحرجة Chi^2_(rightTailAlpha, df)
  /// مثال: لـ 95% ثقة و df=29:
  /// rightTailAlpha = 0.025 -> 45.722 | rightTailAlpha = 0.975 -> 16.047
  static double criticalChiSquare(
    double rightTailAlpha,
    int df, {
    bool useLectureNormalApprox = false,
  }) {
    assert(df >= 1 && rightTailAlpha > 0 && rightTailAlpha < 1);

    // تقريب المحاضرة الثانية في حالة v > 30
    if (useLectureNormalApprox && df > 30) {
      final z = NormalDist.invCdf(1.0 - rightTailAlpha);
      final term = z + math.sqrt(2.0 * df - 1.0);
      return 0.5 * term * term;
    }

    double low = 0.0;
    double high = math.max(100.0, df * 10.0);
    for (int i = 0; i < 80; i++) {
      final mid = (low + high) / 2.0;
      if (upperTailProb(mid, df) > rightTailAlpha) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2.0;
  }

  /// دالة جاما العلوية المنتظمة Q(a, x) = Gamma(a, x) / Gamma(a)
  static double _regularizedGammaQ(double a, double x) {
    if (x < a + 1.0) {
      // حساب السلسلة المتقاربة لـ P(a, x) ثم طرحها من 1
      double sum = 1.0 / a;
      double term = sum;
      double ap = a;
      for (int n = 1; n <= 200; n++) {
        ap += 1.0;
        term *= x / ap;
        sum += term;
        if (term.abs() < sum.abs() * 1e-12) break;
      }
      final p = sum * math.exp(-x + a * math.log(x) - NormalDist.logGamma(a));
      return (1.0 - p).clamp(0.0, 1.0);
    } else {
      // حساب الكسر المستمر لـ Q(a, x)
      double b = x + 1.0 - a;
      double c = 1e30;
      double d = 1.0 / b;
      double h = d;
      for (int i = 1; i <= 200; i++) {
        final an = -i * (i - a);
        b += 2.0;
        d = an * d + b;
        if (d.abs() < 1e-30) d = 1e-30;
        c = b + an / c;
        if (c.abs() < 1e-30) c = 1e-30;
        d = 1.0 / d;
        final del = d * c;
        h *= del;
        if ((del - 1.0).abs() < 1e-12) break;
      }
      return (math.exp(-x + a * math.log(x) - NormalDist.logGamma(a)) * h).clamp(0.0, 1.0);
    }
  }
}