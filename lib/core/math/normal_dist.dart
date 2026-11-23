import 'dart:math' as math;

class NormalDist {
  static const double _sqrt2Pi = 2.5066282746310002;

  /// دالة الكثافة الاحتمالية (PDF) لرسم منحنى الجرس القياسي
  static double pdf(double z) {
    return math.exp(-0.5 * z * z) / _sqrt2Pi;
  }

  /// دالة التوزيع التراكمي Phi(z) = P(Z <= z)
  static double cdf(double z) {
    return 0.5 * (1.0 + _erf(z / math.sqrt2));
  }

  /// القيمة الحرجة Z_(alpha/2) لمستوى ثقة معين (مثلاً alphaOverTwo = 0.025 -> 1.96)
  static double criticalZ(double alphaOverTwo) {
    assert(alphaOverTwo > 0 && alphaOverTwo < 0.5);
    return invCdf(1.0 - alphaOverTwo);
  }

  /// معكوس التوزيع الطبيعي القياسي (Peter Acklam's Rational Approximation | https://stackedboxes.org/2017/05/01/acklams-normal-quantile-function/)
  static double invCdf(double p) {
    if (p <= 0.0) return double.negativeInfinity;
    if (p >= 1.0) return double.infinity;

    const a = [
      -3.969683028665376e+01,
      2.209460984245205e+02,
      -2.759285104469687e+02,
      1.383577518672690e+02,
      -3.066479806614716e+01,
      2.506628277459239e+00,
    ];
    const b = [
      -5.447609879822406e+01,
      1.615858368580409e+02,
      -1.556989798598866e+02,
      6.680131188771972e+01,
      -1.328068155288572e+01,
    ];
    const c = [
      -7.784894002430293e-03,
      -3.223964580411365e-01,
      -2.400758277161838e+00,
      -2.549732539343734e+00,
      4.374664141464968e+00,
      2.938163982698783e+00,
    ];
    const d = [
      7.784695709041462e-03,
      3.224671290700398e-01,
      2.445134137142996e+00,
      3.754408661907416e+00,
    ];

    const pLow = 0.02425;
    const pHigh = 1.0 - pLow;

    if (p < pLow) {
      final q = math.sqrt(-2.0 * math.log(p));
      return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
              c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0);
    } else if (p <= pHigh) {
      final q = p - 0.5;
      final r = q * q;
      return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r +
              a[5]) *
          q /
          (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1.0);
    } else {
      final q = math.sqrt(-2.0 * math.log(1.0 - p));
      return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
              c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0);
    }
  }

  static double _erf(double x) {
    final sign = x >= 0 ? 1.0 : -1.0;
    final absX = x.abs();
    const p = 0.3275911;
    const a1 = 0.254829592, a2 = -0.284496736, a3 = 1.421413741;
    const a4 = -1.453152027, a5 = 1.061405429;
    final t = 1.0 / (1.0 + p * absX);
    final y =
        1.0 -
        (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) *
            t *
            math.exp(-absX * absX);
    return sign * y;
  }

  /// دالة مساعدة لحساب ln(Gamma(z)) باستخدام تقريب Lanczos
  static double logGamma(double z) {
    const coeffs = [
      0.99999999999980993,
      676.5203681218851,
      -1259.1392167224028,
      771.32342877765313,
      -176.61502916214059,
      12.507343278686905,
      -0.13857109526572012,
      9.9843695780195716e-6,
      1.5056327351493116e-7,
    ];
    if (z < 0.5) {
      return math.log(math.pi / math.sin(math.pi * z)) - logGamma(1.0 - z);
    }
    z -= 1.0;
    double x = coeffs[0];
    for (int i = 1; i < coeffs.length; i++) {
      x += coeffs[i] / (z + i);
    }
    final t = z + 7.5;
    return 0.5 * math.log(2.0 * math.pi) +
        (z + 0.5) * math.log(t) -
        t +
        math.log(x);
  }
}
