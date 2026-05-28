import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/detection_result.dart';
import '../models/scan_record.dart';
import '../services/ml_service.dart';
import '../../core/constants/app_constants.dart';

final detectionRepositoryProvider = Provider((ref) => DetectionRepository());

class DetectionRepository {
  final _mlService = MLService();
  final _uuid = const Uuid();

  Future<DetectionResult> analyze({
    required String cancerType,
    required File imageFile,
  }) async {
    // Always try on-device first.
    // Cloud backend is optional — only used if explicitly enabled.
    // This avoids connection errors when backend is not running.
    final result = await _mlService.predict(
      cancerType: cancerType,
      imageFile: imageFile,
    );

    await _saveToHistory(result);
    return result;
  }

  Future<void> _saveToHistory(DetectionResult result) async {
    try {
      final box = Hive.box<ScanRecord>(AppConstants.scanHistoryBox);
      final id = _uuid.v4();
      await box.put(
        id,
        ScanRecord(
          id: id,
          cancerType: result.cancerType,
          imagePath: result.imagePath,
          topLabel: result.topLabel,
          topConfidence: result.topConfidence,
          allConfidences: result.allConfidences,
          createdAt: result.timestamp,
          isHighRisk: result.isHighRisk,
        ),
      );
    } catch (_) {
      // History save failure should not crash the app
    }
  }

  List<ScanRecord> getHistory() {
    try {
      final box = Hive.box<ScanRecord>(AppConstants.scanHistoryBox);
      return box.values.toList().reversed.toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearHistory() async {
    try {
      final box = Hive.box<ScanRecord>(AppConstants.scanHistoryBox);
      await box.clear();
    } catch (_) {}
  }
}
