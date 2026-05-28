import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/detection_result.dart';
import '../models/scan_record.dart';
import '../services/ml_service.dart';
import '../services/cloud_inference_service.dart';
import '../../core/constants/app_constants.dart';

final detectionRepositoryProvider = Provider((ref) => DetectionRepository());

class DetectionRepository {
  final _mlService = MLService();
  final _cloudService = CloudInferenceService();
  final _uuid = const Uuid();

  Future<DetectionResult> analyze({
    required String cancerType,
    required File imageFile,
    bool useCloud = false,
  }) async {
    DetectionResult result;

    try {
      if (useCloud) {
        result = await _cloudService.predict(
          cancerType: cancerType,
          imageFile: imageFile,
        );
      } else {
        result = await _mlService.predict(
          cancerType: cancerType,
          imageFile: imageFile,
        );
      }
    } catch (e) {
      if (!useCloud) {
        // Fallback to cloud if on-device fails
        result = await _cloudService.predict(
          cancerType: cancerType,
          imageFile: imageFile,
        );
      } else {
        rethrow;
      }
    }

    // Persist to history
    await _saveToHistory(result);
    return result;
  }

  Future<void> _saveToHistory(DetectionResult result) async {
    final box = Hive.box<ScanRecord>(AppConstants.scanHistoryBox);
    await box.put(
      _uuid.v4(),
      ScanRecord(
        id: _uuid.v4(),
        cancerType: result.cancerType,
        imagePath: result.imagePath,
        topLabel: result.topLabel,
        topConfidence: result.topConfidence,
        allConfidences: result.allConfidences,
        createdAt: result.timestamp,
        isHighRisk: result.isHighRisk,
      ),
    );
  }

  List<ScanRecord> getHistory() {
    final box = Hive.box<ScanRecord>(AppConstants.scanHistoryBox);
    return box.values.toList().reversed.toList();
  }

  Future<void> clearHistory() async {
    final box = Hive.box<ScanRecord>(AppConstants.scanHistoryBox);
    await box.clear();
  }
}
