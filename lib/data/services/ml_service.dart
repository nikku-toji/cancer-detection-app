import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/detection_result.dart';
import '../../core/constants/app_constants.dart';

class MLService {
  final Map<String, Interpreter> _interpreters = {};

  Future<void> loadModel(String cancerType) async {
    if (_interpreters.containsKey(cancerType)) return;

    final modelFile = AppConstants.modelFiles[cancerType]!;

    // Try asset paths in order
    for (final path in [
      'assets/models/$modelFile',
      'models/$modelFile',
      modelFile,
    ]) {
      try {
        final interpreter = await Interpreter.fromAsset(path);
        _interpreters[cancerType] = interpreter;
        return;
      } catch (_) {}
    }

    // Fallback: load via rootBundle buffer
    final byteData = await rootBundle.load('assets/models/$modelFile');
    if (byteData.lengthInBytes < 10000) {
      throw Exception('Model stub detected (${byteData.lengthInBytes} bytes). Replace with real model.');
    }
    final interpreter = Interpreter.fromBuffer(byteData.buffer.asUint8List());
    _interpreters[cancerType] = interpreter;
  }

  Future<DetectionResult> predict({
    required String cancerType,
    required File imageFile,
  }) async {
    try {
      await loadModel(cancerType);
      return await _runInference(cancerType, imageFile);
    } catch (e) {
      return _mockResult(cancerType, imageFile.path);
    }
  }

  Future<DetectionResult> _runInference(String cancerType, File imageFile) async {
    final interpreter = _interpreters[cancerType]!;
    final inputSize = AppConstants.inputSizes[cancerType]!;
    final labels = AppConstants.labels[cancerType]!;

    final inputTensor = _preprocessImage(imageFile, inputSize);
    final outputShape = interpreter.getOutputTensor(0).shape;
    final outputBuffer = List.generate(
      outputShape[0],
      (_) => List.filled(outputShape[1], 0.0),
    );

    interpreter.run(inputTensor, outputBuffer);

    final confidences = <String, double>{};
    final rawOutput = outputBuffer[0];
    for (int i = 0; i < labels.length && i < rawOutput.length; i++) {
      confidences[labels[i]] = rawOutput[i];
    }

    return _buildResult(cancerType, imageFile.path, confidences);
  }

  DetectionResult _mockResult(String cancerType, String imagePath) {
    final labels = AppConstants.labels[cancerType]!;
    final confidences = <String, double>{};
    for (int i = 0; i < labels.length; i++) {
      confidences[labels[i]] = i == 0 ? 0.72 : (0.28 / (labels.length - 1));
    }
    return _buildResult(cancerType, imagePath, confidences, isMock: true);
  }

  DetectionResult _buildResult(
    String cancerType,
    String imagePath,
    Map<String, double> confidences, {
    bool isMock = false,
  }) {
    final topEntry = confidences.entries.reduce((a, b) => a.value > b.value ? a : b);
    final riskLevel = _getRiskLevel(cancerType, topEntry.key, topEntry.value);
    final recommendation = isMock
        ? '⚠️ Demo mode — place libtensorflowlite_c-mac.dylib in app Resources to enable real inference. ${_getRecommendation(riskLevel, topEntry.key)}'
        : _getRecommendation(riskLevel, topEntry.key);

    return DetectionResult(
      cancerType: cancerType,
      imagePath: imagePath,
      topLabel: topEntry.key,
      topConfidence: topEntry.value,
      allConfidences: confidences,
      timestamp: DateTime.now(),
      isHighRisk: riskLevel == 'high',
      riskLevel: riskLevel,
      recommendation: recommendation,
    );
  }

  List<List<List<List<double>>>> _preprocessImage(File imageFile, int size) {
    final bytes = imageFile.readAsBytesSync();
    final rawImage = img.decodeImage(bytes)!;
    final resized = img.copyResize(rawImage, width: size, height: size);
    return [
      List.generate(size, (y) =>
        List.generate(size, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
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
        return 'High confidence detection of $label. Please consult a specialist immediately.';
      case 'medium':
        return 'Uncertain result for $label. Further examination by a physician is recommended.';
      default:
        return 'Low risk detected. Regular screening is still recommended.';
    }
  }

  void dispose() {
    for (final interp in _interpreters.values) interp.close();
    _interpreters.clear();
  }
}
