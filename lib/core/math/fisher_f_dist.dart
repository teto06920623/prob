import 'dart:math' as math;

class FisherFDist {
  /// دالة كثافة الاحتمال لتوزيع فيشر F(d1, d2) عند x > 0
  static double pdf(double x, int d1, int d2) {
    if (x <= 0 || d1 <= 0 || d2 <= 0) return 0.0;
    final a = d1 / 2.0;
    final b = d2 / 2.0;
    final logBeta = _logGamma(a) + _logGamma(b) - _logGamma(a + b);
    final logNum = a * math.log(d1 * x) + b * math.log(d2);
    final logDen = math.log(x) + (a + b) * math.log(d1 * x + d2) + logBeta;
    return math.exp(logNum - logDen);
  }

  /// المساحة التراكمية P(F <= x)
  static double cdf(double x, int d1, int d2) {
    if (x <= 0) return 0.0;
    final z = (d1 * x) / (d1 * x + d2);
    return _regularizedIncompleteBeta(z, d1 / 2.0, d2 / 2.0);
  }

  /// احتمال الذيل الأيمن P(F > x)
  static double rightTailProb(double x, int d1, int d2) {
    return (1.0 - cdf(x, d1, d2)).clamp(0.0, 1.0);
  }

  /// القيمة الحرجة F_(alpha, d1, d2) بحيث P(F > F_crit) = alpha
  /// وتدعم خاصية المقلوب من المحاضرة الثانية: F_(1-alpha, d1, d2) = 1 / F_(alpha, d2, d1)
  static double criticalF(double alpha, int d1, int d2) {
    if (alpha <= 0.0) return double.infinity;
    if (alpha >= 1.0) return 0.0;
    if (alpha > 0.5) {
      return 1.0 / criticalF(1.0 - alpha, d2, d1);
    }

    double low = 0.0;
    double high = 20.0;
    while (rightTailProb(high, d1, d2) > alpha && high < 1e6) {
      high *= 2.0;
    }

    for (int i = 0; i < 65; i++) {
      final mid = 0.5 * (low + high);
      if (rightTailProb(mid, d1, d2) > alpha) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return 0.5 * (low + high);
  }

  static double _logGamma(double z) {
    const coeffs = [
      76.18009172947146,
      -86.50532032941677,
      24.01409824083091,
      -1.231739572450155,
      0.1208650973866179e-2,
      -0.5395239384953e-5,
    ];
    double x = z;
    double y = z;
    double tmp = x + 5.5;
    tmp -= (x + 0.5) * math.log(tmp);
    double ser = 1.000000000190015;
    for (int j = 0; j < coeffs.length; j++) {
      y += 1.0;
      ser += coeffs[j] / y;
    }
    return -tmp + math.log(2.5066282746310005 * ser / x);
  }

  static double _regularizedIncompleteBeta(double x, double a, double b) {
    if (x <= 0.0) return 0.0;
    if (x >= 1.0) return 1.0;

    final bt = math.exp(
      _logGamma(a + b) - _logGamma(a) - _logGamma(b) + a * math.log(x) + b * math.log(1.0 - x),
    );

    if (x < (a + 1.0) / (a + b + 2.0)) {
      return bt * _betaContinuedFraction(x, a, b) / a;
    } else {
      return 1.0 - bt * _betaContinuedFraction(1.0 - x, b, a) / b;
    }
  }

  static double _betaContinuedFraction(double x, double a, double b) {
    const int maxIter = 200;
    const double eps = 3.0e-12;
    const double fpMin = 1.0e-30;

    final qab = a + b;
    final qap = a + 1.0;
    final qam = a - 1.0;
    double c = 1.0;
    double d = 1.0 - qab * x / qap;
    if (d.abs() < fpMin) d = fpMin;
    d = 1.0 / d;
    double h = d;

    for (int m = 1; m <= maxIter; m++) {
      final m2 = 2 * m;
      double aa = m * (b - m) * x / ((qam + m2) * (a + m2));
      d = 1.0 + aa * d;
      if (d.abs() < fpMin) d = fpMin;
      c = 1.0 + aa / c;
      if (c.abs() < fpMin) c = fpMin;
      d = 1.0 / d;
      h *= d * c;

      aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
      d = 1.0 + aa * d;
      if (d.abs() < fpMin) d = fpMin;
      c = 1.0 + aa / c;
      if (c.abs() < fpMin) c = fpMin;
      d = 1.0 / d;
      final del = d * c;
      h *= del;
      if ((del - 1.0).abs() < eps) break;
    }
    return h;
  }
}