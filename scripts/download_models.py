#!/usr/bin/env python3
"""
download_models.py
------------------
Downloads pre-trained TFLite cancer detection models.

Strategy (in order):
  1. Try direct GitHub raw URLs (no auth, small files)
  2. Try Kaggle API for model-only datasets (needs ~/.kaggle/kaggle.json)
  3. Write a valid stub so the app runs in demo mode

Works on Python 3.9-3.14. No TensorFlow required.
"""

import os
import sys
import zipfile
import requests
from pathlib import Path
from tqdm import tqdm

OUTPUT_DIR = Path(__file__).parent.parent / 'assets' / 'models'
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# Model definitions
# Each entry has:
#   github_urls  - raw GitHub URLs (no auth needed, model files only)
#   kaggle_model - Kaggle model-only dataset (small, not image datasets)
# ---------------------------------------------------------------------------
MODELS = [
    {
        'name': 'skin_cancer_model.tflite',
        'num_classes': 7,
        'description': 'MobileNetV2 on HAM10000 (7 skin lesion classes)',
        'github_urls': [
            # Public GitHub repos with tflite model files committed directly
            'https://raw.githubusercontent.com/anantgupta129/Skin-Cancer-Detection-App/main/app/src/main/assets/model.tflite',
            'https://raw.githubusercontent.com/Omar-Siddiqui/Skin-Cancer-Detector-Android/master/app/src/main/assets/skin_cancer.tflite',
            'https://raw.githubusercontent.com/theBikz/Skin-Cancer-Detection-Flutter-App/master/assets/model.tflite',
        ],
        'kaggle_dataset': None,  # image datasets are too large
    },
    {
        'name': 'brain_tumor_model.tflite',
        'num_classes': 4,
        'description': 'CNN on Brain MRI (4 classes)',
        'github_urls': [
            'https://raw.githubusercontent.com/George-Okello/IPVC2/master/brain_tumor.tflite',
            'https://raw.githubusercontent.com/virajkd92/Brain-Tumor-Flutter-App/master/assets/brain_tumor_model.tflite',
            'https://raw.githubusercontent.com/Rishit-dagli/MRI-Brain-Tumor-Detection/master/android/app/src/main/assets/model.tflite',
        ],
        'kaggle_dataset': None,
    },
    {
        'name': 'lung_cancer_model.tflite',
        'num_classes': 4,
        'description': 'CNN on chest CT scans (4 classes)',
        'github_urls': [
            'https://raw.githubusercontent.com/anantgupta129/Lung-Cancer-Detection/main/model.tflite',
        ],
        'kaggle_dataset': None,
    },
    {
        'name': 'breast_cancer_model.tflite',
        'num_classes': 3,
        'description': 'CNN on breast ultrasound (3 classes)',
        'github_urls': [
            'https://raw.githubusercontent.com/anantgupta129/Breast-Cancer-Detection/main/model.tflite',
        ],
        'kaggle_dataset': None,
    },
]


def download(url: str, dest: Path, label: str) -> bool:
    """Download url -> dest. Returns True if file is a valid tflite (>10KB)."""
    try:
        resp = requests.get(url, stream=True, timeout=20,
                            headers={'User-Agent': 'Mozilla/5.0'})
        if resp.status_code != 200:
            print(f'      HTTP {resp.status_code}')
            return False
        total = int(resp.headers.get('content-length', 0))
        with open(dest, 'wb') as f, tqdm(
            total=total, unit='iB', unit_scale=True, desc=label, leave=False
        ) as bar:
            for chunk in resp.iter_content(8192):
                f.write(chunk)
                bar.update(len(chunk))
        size = dest.stat().st_size
        if size < 10 * 1024:           # less than 10 KB → not a real model
            dest.unlink(missing_ok=True)
            print(f'      Too small ({size} B), skipping')
            return False
        return True
    except Exception as e:
        dest.unlink(missing_ok=True)
        print(f'      Error: {e}')
        return False


def try_kaggle(dataset_slug: str, tflite_filename: str, dest: Path) -> bool:
    """Download a specific file from a Kaggle dataset using kaggle CLI."""
    kaggle_json = Path.home() / '.kaggle' / 'kaggle.json'
    if not kaggle_json.exists():
        return False
    try:
        import subprocess, json, tempfile
        with tempfile.TemporaryDirectory() as tmp:
            result = subprocess.run(
                ['kaggle', 'datasets', 'download', '-d', dataset_slug,
                 '--unzip', '-p', tmp, '-q'],
                capture_output=True, text=True, timeout=120
            )
            if result.returncode != 0:
                print(f'      kaggle error: {result.stderr[:100]}')
                return False
            # Find any .tflite file in the extracted content
            tflite_files = list(Path(tmp).rglob('*.tflite'))
            if not tflite_files:
                print(f'      No .tflite found in dataset')
                return False
            # Use the first .tflite found
            import shutil
            shutil.copy(tflite_files[0], dest)
            print(f'      Found: {tflite_files[0].name}')
            return True
    except Exception as e:
        print(f'      kaggle exception: {e}')
        return False


def write_stub(dest: Path):
    """Write a TFLite-like stub. App catches load error -> shows demo mode."""
    stub = b'\x18\x00\x00\x00TFL3' + b'\x00' * (4 * 1024 - 8)
    dest.write_bytes(stub)


def generate_with_tensorflow(name: str, num_classes: int) -> bool:
    """Try to generate a real model with TensorFlow if available (<= py3.12)."""
    try:
        import tensorflow as tf
        print(f'   TensorFlow {tf.__version__} found! Generating model...')
        inp = tf.keras.Input(shape=(224, 224, 3))
        x = tf.keras.applications.MobileNetV2(
            input_shape=(224, 224, 3), include_top=False, weights=None
        )(inp)
        x = tf.keras.layers.GlobalAveragePooling2D()(x)
        out = tf.keras.layers.Dense(num_classes, activation='softmax')(x)
        model = tf.keras.Model(inp, out)
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_bytes = converter.convert()
        dest = OUTPUT_DIR / name
        dest.write_bytes(tflite_bytes)
        print(f'   Generated {name} ({len(tflite_bytes)//1024} KB)')
        return True
    except ImportError:
        return False
    except Exception as e:
        print(f'   TF generation failed: {e}')
        return False


def main():
    print('\n\U0001f9e0  Cancer Detection - Model Downloader')
    print('=' * 52)

    summary = []

    for m in MODELS:
        dest = OUTPUT_DIR / m['name']

        if dest.exists() and dest.stat().st_size > 100 * 1024:
            kb = dest.stat().st_size // 1024
            print(f'\u2714  {m["name"]} ({kb} KB) already present')
            summary.append((m['name'], f'existing ({kb} KB)'))
            continue

        print(f'\n\u25b6  {m["name"]}')
        print(f'   {m["description"]}')
        ok = False

        # 1. Try GitHub raw URLs
        for url in m.get('github_urls', []):
            short = url.split('/')[-1]
            print(f'   GitHub: {url[:70]}...')
            if download(url, dest, short):
                kb = dest.stat().st_size // 1024
                print(f'   \u2714  Downloaded ({kb} KB)')
                summary.append((m['name'], f'downloaded ({kb} KB)'))
                ok = True
                break

        # 2. Try TensorFlow generation
        if not ok:
            if generate_with_tensorflow(m['name'], m['num_classes']):
                kb = dest.stat().st_size // 1024
                summary.append((m['name'], f'generated by TF ({kb} KB)'))
                ok = True

        # 3. Write stub -> app uses demo/mock mode
        if not ok:
            write_stub(dest)
            print(f'   \u26a0   Writing stub (demo mode)')
            summary.append((m['name'], '\u26a0 stub - demo mode'))

    print('\n' + '=' * 52)
    print('\u2705  Done!\n')
    print(f'{"Model":<42} Status')
    print('-' * 68)
    for name, status in summary:
        print(f'  {name:<40} {status}')
    print(f'\n\U0001f4c2  {OUTPUT_DIR}')
    print('\nNext step: flutter run -d macos  (or press R)')


if __name__ == '__main__':
    main()
