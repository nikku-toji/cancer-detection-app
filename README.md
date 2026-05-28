# 🔬 Cancer Detection App

An AI-powered Flutter mobile application for multi-type cancer detection using on-device ML and cloud-based inference.

## 🎯 Supported Cancer Types

| Cancer Type | Input | Model | Dataset |
|---|---|---|---|
| Skin Cancer | Dermoscopy Image | MobileNetV2 (TFLite) | HAM10000 / ISIC |
| Lung Cancer | CT Scan Image | EfficientNet (TFLite) | LIDC-IDRI / Kaggle |
| Breast Cancer | Mammography Image | ResNet50 (TFLite) | CBIS-DDSM / Kaggle |
| Brain Tumor | MRI Image | Custom CNN (TFLite) | Kaggle Brain MRI |

## 📱 Features

- **Multi-cancer detection** from medical images
- **On-device ML** using TensorFlow Lite (offline capable)
- **Cloud inference** fallback via REST API
- **Confidence scores** with visual probability charts
- **History tracking** of past scans
- **Educational content** about each cancer type
- **Nearby hospitals** finder
- **Export reports** as PDF

## 🏗️ Architecture

```
cancer_detection_app/
├── lib/
│   ├── core/           # App config, theme, constants
│   ├── data/           # Models, repositories, data sources
│   ├── domain/         # Business logic, use cases
│   ├── presentation/   # UI screens, widgets, providers
│   └── main.dart
├── assets/
│   ├── models/         # TFLite model files
│   ├── images/         # App images
│   └── animations/     # Lottie JSON animations
├── scripts/            # Python scripts for model training/download
└── backend/            # Optional FastAPI inference backend
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK >= 3.0.0
- Dart >= 3.0.0
- Android Studio / Xcode
- Python 3.9+ (for model scripts)

### Installation

```bash
# Clone the repo
git clone https://github.com/nikku-toji/cancer-detection-app.git
cd cancer-detection-app

# Install Flutter dependencies
flutter pub get

# Download ML models (run the Python script)
cd scripts
pip install -r requirements.txt
python download_models.py

# Run the app
flutter run
```

### Backend (Optional)
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

## 📊 Datasets Used

- **HAM10000** - Human Against Machine with 10000 training images (skin lesions)
- **ISIC Archive** - International Skin Imaging Collaboration
- **Kaggle Chest CT** - Lung cancer CT scan dataset
- **CBIS-DDSM** - Curated Breast Imaging Subset of DDSM
- **Kaggle Brain MRI** - Brain tumor classification MRI dataset

## ⚠️ Medical Disclaimer

> This app is for **educational and research purposes only**. It is **NOT** a substitute for professional medical diagnosis. Always consult a qualified healthcare professional for medical advice.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.
