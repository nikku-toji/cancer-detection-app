import 'dart:io';
import 'package:dio/dio.dart';
import '../models/detection_result.dart';
import '../../core/constants/app_constants.dart';

/// Fallback cloud inference service (FastAPI backend)
class CloudInferenceService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseApiUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  Future<DetectionResult> predict({
    required String cancerType,
    required File imageFile,
  }) async {
    final formData = FormData.fromMap({
      'cancer_type': cancerType,
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'scan.jpg',
      ),
    });

    final response = await _dio.post('/predict', data: formData);
    return DetectionResult.fromMap(response.data);
  }
}
