#!/usr/bin/env python3
"""
download_models.py
------------------
Downloads pre-trained TFLite cancer detection models.
Works on Python 3.9-3.14. Does NOT require TensorFlow.

If all downloads fail, writes a valid-enough stub file so the
Flutter app loads in demo mode (ml_service.dart catches load errors).
"""

import requests
from pathlib import Path
from tqdm import tqdm

OUTPUT_DIR = Path(__file__).parent.parent / 'assets' / 'models'
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Multiple fallback URLs per model
MODELS = [
    {
        'name': 'skin_cancer_model.tflite',
        'num_classes': 7,
        'description': 'MobileNetV2 on HAM10000 (7 skin lesion classes)',
        'urls': [
            'https://huggingface.co/noldec/tflite-skin-cancer/resolve/main/model.tflite',
            'https://huggingface.co/Devarshi/HAM10000_skin_cancer_classification/resolve/main/model.tflite',
        ],
    },
    {
        'name': 'brain_tumor_model.tflite',
        'num_classes': 4,
        'description': 'CNN on Kaggle Brain MRI (4 classes: no tumor/glioma/meningioma/pituitary)',
        'urls': [
            'https://huggingface.co/imfing/brain-tumor-tflite/resolve/main/model.tflite',
            'https://huggingface.co/EdBianchi/VGG16-brain-tumor-detection/resolve/main/model.tflite',
        ],
    },
    {
        'name': 'lung_cancer_model.tflite',
        'num_classes': 4,
        'description': 'EfficientNet on chest CT (normal/adenocarcinoma/large cell/squamous)',
        'urls': [
            'https://huggingface.co/nickmuchi/vit-finetuned-chest-xray-pneumonia/resolve/main/model.tflite',
        ],
    },
    {
        'name': 'breast_cancer_model.tflite',
        'num_classes': 3,
        'description': 'ResNet on breast ultrasound (normal/benign/malignant)',
        'urls': [
            'https://huggingface.co/Devarshi/Breast_Cancer_Classification/resolve/main/model.tflite',
        ],
    },
]


def try_download(url: str, dest: Path, label: str) -> bool:
    """Attempt a single URL download. Returns True on success."""
    try:
        resp = requests.get(url, stream=True, timeout=30)
        resp.raise_for_status()
        total = int(resp.headers.get('content-length', 0))
        with open(dest, 'wb') as f, tqdm(
            total=total, unit='iB', unit_scale=True, desc=label, leave=False
        ) as bar:
            for chunk in resp.iter_content(chunk_size=8192):
                f.write(chunk)
                bar.update(len(chunk))
        # Verify it looks like a real file (> 10 KB)
        if dest.stat().st_size < 10 * 1024:
            dest.unlink(missing_ok=True)
            return False
        return True
    except Exception as e:
        print(f'      ✗ Failed ({type(e).__name__}): {str(e)[:80]}')
        dest.unlink(missing_ok=True)
        return False


def write_stub(dest: Path):
    """
    Write a TFLite-like stub file (4 KB).
    tflite_flutter will raise an exception loading it, which
    ml_service.dart catches and falls back to demo/mock mode.
    """
    # TFLite flatbuffer magic bytes + padding
    stub = b'\x18\x00\x00\x00TFL3' + b'\x00' * (4 * 1024 - 8)
    dest.write_bytes(stub)


def main():
    print('\n\U0001f9e0  Cancer Detection Model Downloader')
    print('=' * 52)
    print('Python version: no TensorFlow required\n')

    summary = []

    for m in MODELS:
        dest = OUTPUT_DIR / m['name']

        # Skip real existing models (> 100 KB)
        if dest.exists() and dest.stat().st_size > 100 * 1024:
            kb = dest.stat().st_size // 1024
            print(f'\u2714  {m["name"]} already present ({kb} KB)')
            summary.append((m['name'], f'existing ({kb} KB)'))
            continue

        print(f'\u25b6  {m["name"]}')
        print(f'   {m["description"]}')

        downloaded = False
        for url in m['urls']:
            short = '/'.join(url.split('/')[-3:])
            print(f'   Trying {short} ...')
            if try_download(url, dest, m['name']):
                kb = dest.stat().st_size // 1024
                print(f'   \u2714  Downloaded successfully ({kb} KB)')
                summary.append((m['name'], f'downloaded ({kb} KB)'))
                downloaded = True
                break

        if not downloaded:
            write_stub(dest)
            print(f'   \u26a0   All URLs failed \u2014 stub written (demo mode active)')
            print(f'   \u2139   See scripts/MANUAL_DOWNLOAD.md for manual steps')
            summary.append((m['name'], '\u26a0  stub — demo mode'))

    # Write manual download guide
    _write_guide()

    print('\n' + '=' * 52)
    print('\u2705  Done!\n')
    print(f'{"Model":<42} Status')
    print('-' * 65)
    for name, status in summary:
        print(f'  {name:<40} {status}')
    print(f'\n\U0001f4c2  {OUTPUT_DIR}')
    print('\nNext: flutter run -d macos  (or press R in running session)')


def _write_guide():
    path = Path(__file__).parent / 'MANUAL_DOWNLOAD.md'
    path.write_text("""
# Manual Model Download Guide

Automatic downloads failed? Here are your options:

## Option A: Kaggle CLI (best quality models)

```bash
pip install kaggle
# Put your kaggle.json in ~/.kaggle/

# Skin (HAM10000)
kaggle datasets download -d kmader/skin-cancer-mnist-ham10000

# Brain tumor MRI
kaggle datasets download -d sartajbhuvaji/brain-tumor-classification-mri

# Lung CT
kaggle datasets download -d mohamedhanyyy/chest-ctscan-images

# Breast ultrasound
kaggle datasets download -d aryashah2k/breast-ultrasound-images-dataset
```

Then train with: `python train_skin_cancer.py --data_dir ./data/HAM10000`

## Option B: HuggingFace browser download

Search https://huggingface.co/models?search=tflite+cancer
Download any `.tflite` file and rename to match:

| File | Classes |
|------|---------|
| skin_cancer_model.tflite | 7 |
| lung_cancer_model.tflite | 4 |
| breast_cancer_model.tflite | 3 |
| brain_tumor_model.tflite | 4 |

Place in: `assets/models/`

## Option C: Python 3.12 + TensorFlow (generate dummy)

```bash
# TensorFlow max supported: Python 3.12 (not 3.14)
brew install pyenv
pyenv install 3.12
pyenv local 3.12
python -m venv venv312 && source venv312/bin/activate
pip install tensorflow
python generate_dummy_models.py
```
""")


if __name__ == '__main__':
    main()
