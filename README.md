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
- Flutter SDK >= 3.0.0 — install via `brew install --cask flutter`
- Dart >= 3.0.0 (bundled with Flutter)
- Android Studio / Xcode
- Python 3.9+

### 1. Install Flutter (macOS)

```bash
brew install --cask flutter
flutter doctor   # follow any remaining setup steps
```

### 2. Clone & install Flutter deps

```bash
git clone https://github.com/nikku-toji/cancer-detection-app.git
cd cancer-detection-app
flutter pub get
```

### 3. Download ML models

> **macOS / Homebrew Python users:** Python is externally managed — use a venv.

```bash
cd scripts

# Create and activate a virtual environment
python3 -m venv venv
source venv/bin/activate       # run this every new terminal session

# Install dependencies
pip install -r requirements.txt

# Download / generate models
python download_models.py

cd ..
```

### 4. Run the app

```bash
flutter run                    # picks up connected device / simulator
flutter run -d chrome          # web preview
```

### Backend (Optional — cloud inference fallback)

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

## 📊 Datasets Used

- **HAM10000** — 10,015 dermoscopic skin lesion images (7 classes)
- **ISIC Archive** — International Skin Imaging Collaboration
- **Kaggle Chest CT** — Lung cancer CT scan dataset
- **CBIS-DDSM** — Curated Breast Imaging Subset of DDSM
- **Kaggle Brain MRI** — Brain tumor classification MRI dataset

## 🧠 Models

| Cancer | Architecture | Input | Classes | Source |
|---|---|---|---|---|
| Skin | MobileNetV2 | 224×224 RGB | 7 | HAM10000 |
| Lung | EfficientNetB0 | 224×224 RGB | 4 | Kaggle CT |
| Breast | ResNet50 | 224×224 RGB | 3 | CBIS-DDSM |
| Brain | Custom CNN | 224×224 RGB | 4 | Kaggle MRI |

Models are excluded from git (too large). Run `scripts/download_models.py` to fetch/generate them.

## ⚠️ Medical Disclaimer

> This app is for **educational and research purposes only**. It is **NOT** a substitute for professional medical diagnosis. Always consult a qualified healthcare professional for medical advice.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.
