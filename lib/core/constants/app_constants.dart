class AppConstants {
  // Cancer types
  static const List<String> cancerTypes = [
    'skin',
    'lung',
    'breast',
    'brain',
  ];

  // Cancer display names
  static const Map<String, String> cancerNames = {
    'skin': 'Skin Cancer',
    'lung': 'Lung Cancer',
    'breast': 'Breast Cancer',
    'brain': 'Brain Tumor',
  };

  // Cancer descriptions
  static const Map<String, String> cancerDescriptions = {
    'skin': 'Analyze skin lesions and dermoscopy images for melanoma, basal cell carcinoma, and other skin conditions.',
    'lung': 'Detect potential lung nodules and abnormalities in chest CT scans.',
    'breast': 'Analyze mammography images for early signs of breast cancer.',
    'brain': 'Detect brain tumors from MRI scans including glioma, meningioma, and pituitary tumors.',
  };

  // Model files (stored in assets/models/)
  static const Map<String, String> modelFiles = {
    'skin': 'skin_cancer_model.tflite',
    'lung': 'lung_cancer_model.tflite',
    'breast': 'breast_cancer_model.tflite',
    'brain': 'brain_tumor_model.tflite',
  };

  // Labels
  static const Map<String, List<String>> labels = {
    'skin': [
      'Melanocytic nevi',
      'Melanoma',
      'Benign keratosis',
      'Basal cell carcinoma',
      'Actinic keratoses',
      'Vascular lesions',
      'Dermatofibroma',
    ],
    'lung': [
      'Normal',
      'Adenocarcinoma',
      'Large cell carcinoma',
      'Squamous cell carcinoma',
    ],
    'breast': [
      'Normal',
      'Benign',
      'Malignant',
    ],
    'brain': [
      'No Tumor',
      'Glioma',
      'Meningioma',
      'Pituitary',
    ],
  };

  // Image input sizes per model
  static const Map<String, int> inputSizes = {
    'skin': 224,
    'lung': 224,
    'breast': 224,
    'brain': 224,
  };

  // Confidence thresholds
  static const double highConfidence = 0.80;
  static const double mediumConfidence = 0.60;

  // API
  static const String baseApiUrl = 'http://localhost:8000';

  // Hive box names
  static const String scanHistoryBox = 'scan_history';
}
