import 'dart:math' as math;
import 'normal_dist.dart';

class StudentTDist {
  /// دالة الكثافة الاحتمالية (PDF) لتوزيع T بدرجات حرية df
  static double pdf(double t, int df) {
    final v = df.toDouble();
    final logCoeff = NormalDist.logGamma((v + 1.0) / 2.0) -
        (0.5 * math.log(v * math.pi) + NormalDist.logGamma(v / 2.0));
    return math.exp(logCoeff - ((v + 1.0) / 2.0) * math.log(1.0 + (t * t) / v));
  }

  /// احتمال الذيل الأيمن P(T > t) للقيم الموجبة t >= 0
  static double rightTailProb(double t, int df) {
    if (t <= 0) return 0.5;
    final v = df.toDouble();
    final x = v / (v + t * t);
    return 0.5 * _regularizedBeta(x, v / 2.0, 0.5);
  }

  /// القيمة الحرجة t_(alpha/2, df)
  static double criticalT(double alphaOverTwo, int df) {
    assert(df >= 1 && alphaOverTwo > 0 && alphaOverTwo < 0.5);
    double low = 0.0;
    double high = 1000.0;
    for (int i = 0; i < 70; i++) {
      final mid = (low + high) / 2.0;
      if (rightTailProb(mid, df) > alphaOverTwo) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return (low + high) / 2.0;
  }

  static double _regularizedBeta(double x, double a, double b) {
    if (x <= 0.0) return 0.0;
    if (x >= 1.0) return 1.0;
    final bt = math.exp(NormalDist.logGamma(a + b) -
        NormalDist.logGamma(a) -
        NormalDist.logGamma(b) +
        a * math.log(x) +
        b * math.log(1.0 - x));
    if (x < (a + 1.0) / (a + b + 2.0)) {
      return bt * _betaCF(x, a, b) / a;
    } else {
      return 1.0 - bt * _betaCF(1.0 - x, b, a) / b;
    }
  }

  /// الكسر المستمر (Lentz's Method) لحساب دالة بيتا غير المكتملة
  static double _betaCF(double x, double a, double b) {
    const maxIter = 200;
    const eps = 1e-12;
    final qab = a + b, qap = a + 1.0, qam = a - 1.0;
    double c = 1.0;
    double d = 1.0 - qab * x / qap;
    if (d.abs() < 1e-30) d = 1e-30;
    d = 1.0 / d;
    double h = d;

    for (int m = 1; m <= maxIter; m++) {
      final m2 = 2 * m;
      double aa = m * (b - m) * x / ((qam + m2) * (a + m2));
      d = 1.0 + aa * d;
      if (d.abs() < 1e-30) d = 1e-30;
      c = 1.0 + aa / c;
      if (c.abs() < 1e-30) c = 1e-30;
      d = 1.0 / d;
      h *= d * c;

      aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
      d = 1.0 + aa * d;
      if (d.abs() < 1e-30) d = 1e-30;
      c = 1.0 + aa / c;
      if (c.abs() < 1e-30) c = 1e-30;
      d = 1.0 / d;
      final del = d * c;
      h *= del;
      if ((del - 1.0).abs() < eps) break;
    }
    return h;
  }
}