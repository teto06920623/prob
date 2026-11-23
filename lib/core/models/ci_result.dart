enum DistributionType { normal, studentT, chiSquare }

class CiResult {
  final String title;
  final String methodUsed;
  final DistributionType distType;
  final int degreesOfFreedom;
  final double alpha;

  final double pointEstimate;
  final double lowerBound;
  final double upperBound;
  final double? standardError;

  final double leftCritical;
  final double rightCritical;
  final double? testValue;
  final bool isSampleSizeMode;

  final String? secondaryLabel;
  final String? secondaryValue;
  final List<String> steps; // خطوات الحل بالورقة والقلم

  const CiResult({
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
    this.testValue,
    this.isSampleSizeMode = false,
    this.secondaryLabel,
    this.secondaryValue,
    this.steps = const [],
  });
}