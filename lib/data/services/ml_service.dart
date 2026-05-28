import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/detection_result.dart';
import '../../core/constants/app_constants.dart';

class MLService {
  final Map<String, Interpreter> _interpreters = {};

  /// Load TFLite model for the given cancer type
  Future<void> loadModel(String cancerType) async {
    if (_interpreters.containsKey(cancerType)) return;
    final modelFile = AppConstants.modelFiles[cancerType]!;
    final interpreter = await Interpreter.fromAsset('models/$modelFile');
    _interpreters[cancerType] = interpreter;
  }

  /// Run inference on an image file
  Future<DetectionResult> predict({
    required String cancerType,
    required File imageFile,
  }) async {
    await loadModel(cancerType);

    final interpreter = _interpreters[cancerType]!;
    final inputSize = AppConstants.inputSizes[cancerType]!;
    final labels = AppConstants.labels[cancerType]!;

    // Preprocess image
    final inputTensor = _preprocessImage(imageFile, inputSize);

    // Prepare output buffer
    final outputShape = interpreter.getOutputTensor(0).shape;
    final outputBuffer = List.generate(
      outputShape[0],
      (_) => List.filled(outputShape[1], 0.0),
    );

    interpreter.run(inputTensor, outputBuffer);

    // Parse output
    final confidences = <String, double>{};
    final rawOutput = outputBuffer[0];
    for (int i = 0; i < labels.length && i < rawOutput.length; i++) {
      confidences[labels[i]] = rawOutput[i];
    }

    final topEntry =
        confidences.entries.reduce((a, b) => a.value > b.value ? a : b);

    final riskLevel = _getRiskLevel(cancerType, topEntry.key, topEntry.value);
    final recommendation = _getRecommendation(riskLevel, topEntry.key);

    return DetectionResult(
      cancerType: cancerType,
      imagePath: imageFile.path,
      topLabel: topEntry.key,
      topConfidence: topEntry.value,
      allConfidences: confidences,
      timestamp: DateTime.now(),
      isHighRisk: riskLevel == 'high',
      riskLevel: riskLevel,
      recommendation: recommendation,
    );
  }

  /// Preprocess image to [1, size, size, 3] float32 tensor
  /// Uses image 4.x API: pixel.r / pixel.g / pixel.b
  List<List<List<List<double>>>> _preprocessImage(File imageFile, int size) {
    final bytes = imageFile.readAsBytesSync();
    final rawImage = img.decodeImage(bytes)!;
    final resized = img.copyResize(rawImage, width: size, height: size);

    return [
      List.generate(
        size,
        (y) => List.generate(
          size,
          (x) {
            final pixel = resized.getPixel(x, y);
            // image ^4.x: access channels via pixel.r / .g / .b (0–255)
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    ];
  }

  String _getRiskLevel(String cancerType, String label, double confidence) {
    final lowRiskLabels = {
      'skin': ['Melanocytic nevi', 'Vascular lesions', 'Dermatofibroma'],
      'lung': ['Normal'],
      'breast': ['Normal', 'Benign'],
      'brain': ['No Tumor'],
    };

    if (lowRiskLabels[cancerType]?.contains(label) == true) {
      return confidence > 0.7 ? 'low' : 'medium';
    }
    return confidence > AppConstants.highConfidence ? 'high' : 'medium';
  }

  String _getRecommendation(String riskLevel, String label) {
    switch (riskLevel) {
      case 'high':
        return 'High confidence detection of $label. Please consult a specialist immediately for professional medical evaluation.';
      case 'medium':
        return 'Uncertain result for $label. Further examination by a qualified physician is recommended.';
      default:
        return 'Low risk detected. Regular screening is still recommended. Maintain healthy habits.';
    }
  }

  void dispose() {
    for (final interp in _interpreters.values) {
      interp.close();
    }
    _interpreters.clear();
  }
}
