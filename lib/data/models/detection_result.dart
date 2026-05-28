class DetectionResult {
  final String cancerType;
  final String imagePath;
  final String topLabel;
  final double topConfidence;
  final Map<String, double> allConfidences;
  final DateTime timestamp;
  final bool isHighRisk;
  final String riskLevel; // 'low', 'medium', 'high'
  final String recommendation;

  DetectionResult({
    required this.cancerType,
    required this.imagePath,
    required this.topLabel,
    required this.topConfidence,
    required this.allConfidences,
    required this.timestamp,
    required this.isHighRisk,
    required this.riskLevel,
    required this.recommendation,
  });

  factory DetectionResult.fromMap(Map<String, dynamic> map) {
    return DetectionResult(
      cancerType: map['cancerType'],
      imagePath: map['imagePath'],
      topLabel: map['topLabel'],
      topConfidence: map['topConfidence'],
      allConfidences: Map<String, double>.from(map['allConfidences']),
      timestamp: DateTime.parse(map['timestamp']),
      isHighRisk: map['isHighRisk'],
      riskLevel: map['riskLevel'],
      recommendation: map['recommendation'],
    );
  }

  Map<String, dynamic> toMap() => {
        'cancerType': cancerType,
        'imagePath': imagePath,
        'topLabel': topLabel,
        'topConfidence': topConfidence,
        'allConfidences': allConfidences,
        'timestamp': timestamp.toIso8601String(),
        'isHighRisk': isHighRisk,
        'riskLevel': riskLevel,
        'recommendation': recommendation,
      };
}
