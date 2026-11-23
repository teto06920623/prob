enum DistributionType { normal, studentT, chiSquare, fisherF }

class CiResult {
  final String title;
  final String methodUsed;
  final DistributionType distType;
  final int degreesOfFreedom;
  final int degreesOfFreedom2;
  final double alpha;

  final double pointEstimate;
  final double lowerBound;
  final double upperBound;
  final double? standardError;

  final double leftCritical;
  final double rightCritical;
  final double? testValue;
  final bool isSampleSizeMode;
  final bool isProbabilityMode;

  final String? secondaryLabel;
  final String? secondaryValue;
  final List<String> steps;

  const CiResult({
    required this.title,
    required this.methodUsed,
    required this.distType,
    this.degreesOfFreedom = 1,
    this.degreesOfFreedom2 = 1,
    required this.alpha,
    required this.pointEstimate,
    required this.lowerBound,
    required this.upperBound,
    this.standardError,
    required this.leftCritical,
    required this.rightCritical,
    this.testValue,
    this.isSampleSizeMode = false,
    this.isProbabilityMode = false,
    this.secondaryLabel,
    this.secondaryValue,
    this.steps = const [],
  });
}
