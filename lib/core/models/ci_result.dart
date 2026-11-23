enum DistributionType { normal, studentT, chiSquare }

class CiResult {
  final String title;              // مثال: "95% CI for Population Mean (μ)"
  final String methodUsed;         // مثال: "Z-Distribution (σ Known)"
  final DistributionType distType; // نوع المنحنى المطلوب رسمه
  final int degreesOfFreedom;      // درجات الحرية (مهمة لـ T و Chi-Square)
  final double alpha;              // مستوى المعنوية (مثلاً 0.05)

  final double pointEstimate;      // التقدير النقطي (X_bar أو s^2 أو P_hat)
  final double lowerBound;         // الحد الأدنى (LCL)
  final double upperBound;         // الحد الأعلى (UCL)
  final double? standardError;     // الخطأ المعياري (SE) للمتوسط والنسبة

  final double leftCritical;       // القيمة الحرجة اليسرى على الرسم (مثل -1.96 أو 2.70)
  final double rightCritical;      // القيمة الحرجة اليمنى على الرسم (مثل +1.96 أو 19.023)



  // بيانات إضافية اختيارية (مثل فترة الانحراف المعياري sigma أو نتيجة اختبار الفروض)
  final String? secondaryLabel;
  final String? secondaryValue;

  final double? testValue; // قيمة الاختبار المحسوبة في شاشة Hypothesis Test

  const CiResult({
    this.testValue,
    required this.title,
    required this.methodUsed,
    required this.distType,
    this.degreesOfFreedom = 1,
    required this.alpha,
    required this.pointEstimate,
    required this.lowerBound,
    required this.upperBound,
    this.standardError,
    required this.leftCritical,
    required this.rightCritical,
    this.secondaryLabel,
    this.secondaryValue,
  });
}