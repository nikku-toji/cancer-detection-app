import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/detection_result.dart';
import '../../core/constants/app_constants.dart';

/// Uses Claude Vision API (claude-haiku) to analyze medical images.
/// No native libraries required — works on macOS, iOS, Android, web.
class MLService {
  // Replace with your Anthropic API key, or set via env/config
  static const _apiKey = String.fromEnvironment(
    'ANTHROPIC_API_KEY',
    defaultValue: '',
  );

  static const _apiUrl = 'https://api.anthropic.com/v1/messages';

  Future<DetectionResult> predict({
    required String cancerType,
    required File imageFile,
  }) async {
    if (_apiKey.isEmpty) {
      print('[MLService] No API key — using mock mode');
      return _mockResult(cancerType, imageFile.path);
    }

    try {
      return await _claudeInference(cancerType, imageFile);
    } catch (e) {
      print('[MLService] Claude API error: $e — falling back to mock');
      return _mockResult(cancerType, imageFile.path);
    }
  }

  Future<DetectionResult> _claudeInference(
      String cancerType, File imageFile) async {
    final labels = AppConstants.labels[cancerType]!;
    final cancerName = AppConstants.cancerNames[cancerType]!;

    // Resize image to reduce payload size
    final bytes = imageFile.readAsBytesSync();
    final decoded = img.decodeImage(bytes)!;
    final resized = img.copyResize(decoded, width: 512);
    final jpegBytes = img.encodeJpg(resized, quality: 85);
    final base64Image = base64Encode(jpegBytes);

    final prompt = '''
You are a medical AI assistant analyzing a medical image for $cancerName detection.

Analyze this image and classify it into one of these categories:
${labels.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

Respond with ONLY a valid JSON object in this exact format, no other text:
{
  "top_label": "<one of the exact category names above>",
  "confidences": {
    ${labels.map((l) => '"$l": <float 0.0-1.0>').join(',\n    ')}
  },
  "reasoning": "<1-2 sentence clinical reasoning>"
}

All confidence values must sum to approximately 1.0.''';

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 512,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': base64Image,
                },
              },
              {'type': 'text', 'text': prompt},
            ],
          }
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final text = data['content'][0]['text'] as String;
    print('[MLService] Claude response: $text');

    // Parse JSON response
    final jsonStart = text.indexOf('{');
    final jsonEnd = text.lastIndexOf('}') + 1;
    final jsonStr = text.substring(jsonStart, jsonEnd);
    final result = jsonDecode(jsonStr);

    final topLabel = result['top_label'] as String;
    final confidencesRaw = result['confidences'] as Map<String, dynamic>;
    final confidences = confidencesRaw
        .map((k, v) => MapEntry(k, (v as num).toDouble()));
    final reasoning = result['reasoning'] as String? ?? '';

    final topConfidence = confidences[topLabel] ?? 0.5;
    final riskLevel = _getRiskLevel(cancerType, topLabel, topConfidence);

    return DetectionResult(
      cancerType: cancerType,
      imagePath: imageFile.path,
      topLabel: topLabel,
      topConfidence: topConfidence,
      allConfidences: confidences,
      timestamp: DateTime.now(),
      isHighRisk: riskLevel == 'high',
      riskLevel: riskLevel,
      recommendation:
          '$reasoning ${_getRecommendation(riskLevel, topLabel)}',
    );
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
    final topEntry =
        confidences.entries.reduce((a, b) => a.value > b.value ? a : b);
    final riskLevel = _getRiskLevel(cancerType, topEntry.key, topEntry.value);
    final recommendation = isMock
        ? '⚠️ Demo mode — Set ANTHROPIC_API_KEY to enable real AI inference. ${_getRecommendation(riskLevel, topEntry.key)}'
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

  void dispose() {}
}
