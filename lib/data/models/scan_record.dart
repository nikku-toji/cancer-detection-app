import 'dart:io';
import 'package:hive/hive.dart';

part 'scan_record.g.dart';

@HiveType(typeId: 0)
class ScanRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String cancerType;

  @HiveField(2)
  final String imagePath;

  @HiveField(3)
  final String topLabel;

  @HiveField(4)
  final double topConfidence;

  @HiveField(5)
  final Map<String, double> allConfidences;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final bool isHighRisk;

  ScanRecord({
    required this.id,
    required this.cancerType,
    required this.imagePath,
    required this.topLabel,
    required this.topConfidence,
    required this.allConfidences,
    required this.createdAt,
    required this.isHighRisk,
  });
}
