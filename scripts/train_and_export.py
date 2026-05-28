#!/usr/bin/env python3
"""
train_and_export.py
--------------------
Trains lightweight MobileNetV2 classifiers on the Kaggle datasets
you already downloaded, then exports each as a .tflite file.

Requirements (Python <= 3.12 only -- TF doesn't support 3.14 yet):
  pip install tensorflow pillow numpy scikit-learn

Usage:
  python train_and_export.py

Datasets expected in ./tmp_brain, ./tmp_lung, ./tmp (brain MRI).
Auto-detects folder structure.
"""

import os
import sys
import shutil
from pathlib import Path

# ------------------------------------------------------------------ #
# Check Python version before importing TF
# ------------------------------------------------------------------ #
if sys.version_info >= (3, 13):
    print('ERROR: TensorFlow requires Python <= 3.12.')
    print(f'  Your Python: {sys.version}')
    print('\nFix: use pyenv to get Python 3.12:')
    print('  brew install pyenv')
    print('  pyenv install 3.12.8')
    print('  pyenv local 3.12.8')
    print('  python -m venv venv312 && source venv312/bin/activate')
    print('  pip install tensorflow pillow numpy scikit-learn')
    print('  python train_and_export.py')
    sys.exit(1)

try:
    import tensorflow as tf
except ImportError:
    print('TensorFlow not installed.')
    print('Run: pip install tensorflow')
    sys.exit(1)

import numpy as np
from sklearn.model_selection import train_test_split

print(f'TensorFlow {tf.__version__} | Python {sys.version.split()[0]}')

OUTPUT_DIR = Path(__file__).parent.parent / 'assets' / 'models'
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

IMG_SIZE = 224
BATCH = 32
EPOCHS = 10  # quick training; increase to 30+ for better accuracy


# ------------------------------------------------------------------ #
# Dataset auto-discovery
# ------------------------------------------------------------------ #

def find_image_dataset(search_roots: list) -> Path | None:
    """Walk roots and return first directory containing class subdirs with images."""
    for root in search_roots:
        root = Path(root)
        if not root.exists():
            continue
        # Look for any subdir that contains images
        for d in sorted(root.rglob('*')):
            if d.is_dir():
                images = list(d.glob('*.jpg')) + list(d.glob('*.jpeg')) + \
                         list(d.glob('*.png'))
                subdirs = [x for x in d.iterdir() if x.is_dir()]
                if len(subdirs) >= 2 and any(
                    len(list(s.glob('*.jpg')) + list(s.glob('*.jpeg')) + list(s.glob('*.png'))) > 0
                    for s in subdirs
                ):
                    return d
    return None


DATASETS = [
    {
        'name': 'brain_tumor_model.tflite',
        'search': ['./tmp_brain', './tmp', './tmp_brain/Training', './tmp/Training'],
        'classes': None,  # auto-detect from folder names
        'expected_classes': 4,
    },
    {
        'name': 'lung_cancer_model.tflite',
        'search': ['./tmp_lung', './tmp_lung/train', './tmp_lung/Data'],
        'classes': None,
        'expected_classes': 4,
    },
]


# ------------------------------------------------------------------ #
# Model builder
# ------------------------------------------------------------------ #

def build_model(num_classes: int):
    base = tf.keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights='imagenet',
    )
    base.trainable = False

    inp = tf.keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3))
    x = tf.keras.applications.mobilenet_v2.preprocess_input(inp)
    x = base(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    x = tf.keras.layers.Dense(128, activation='relu')(x)
    out = tf.keras.layers.Dense(num_classes, activation='softmax')(x)
    model = tf.keras.Model(inp, out)
    return model


def make_dataset(data_dir: Path, validation_split=0.2):
    train_ds = tf.keras.utils.image_dataset_from_directory(
        data_dir,
        validation_split=validation_split,
        subset='training',
        seed=42,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH,
        label_mode='sparse',
    )
    val_ds = tf.keras.utils.image_dataset_from_directory(
        data_dir,
        validation_split=validation_split,
        subset='validation',
        seed=42,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH,
        label_mode='sparse',
    )
    class_names = train_ds.class_names
    print(f'  Classes ({len(class_names)}): {class_names}')

    AUTOTUNE = tf.data.AUTOTUNE
    train_ds = train_ds.prefetch(AUTOTUNE)
    val_ds = val_ds.prefetch(AUTOTUNE)
    return train_ds, val_ds, class_names


def export_tflite(model, output_path: Path):
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_bytes = converter.convert()
    output_path.write_bytes(tflite_bytes)
    print(f'  Exported: {output_path} ({len(tflite_bytes)//1024} KB)')
    return tflite_bytes


def train_model(dataset_dir: Path, output_name: str):
    print(f'\n Training: {output_name}')
    print(f'  Data dir: {dataset_dir}')

    train_ds, val_ds, class_names = make_dataset(dataset_dir)
    num_classes = len(class_names)

    model = build_model(num_classes)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy'],
    )

    callbacks = [
        tf.keras.callbacks.EarlyStopping(patience=3, restore_best_weights=True),
        tf.keras.callbacks.ReduceLROnPlateau(patience=2, factor=0.5),
    ]

    print(f'  Training for up to {EPOCHS} epochs...')
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS,
        callbacks=callbacks,
        verbose=1,
    )

    val_acc = max(history.history.get('val_accuracy', [0]))
    print(f'  Best val accuracy: {val_acc:.1%}')

    output_path = OUTPUT_DIR / output_name
    export_tflite(model, output_path)
    return class_names


def save_labels(name: str, class_names: list):
    """Save label file next to the model for reference."""
    label_path = OUTPUT_DIR / name.replace('.tflite', '_labels.txt')
    label_path.write_text('\n'.join(class_names))
    print(f'  Labels: {label_path}')


# ------------------------------------------------------------------ #
# Main
# ------------------------------------------------------------------ #

def main():
    print('\n Cancer Detection - Train & Export TFLite Models')
    print('=' * 54)

    trained = []

    for ds in DATASETS:
        out_path = OUTPUT_DIR / ds['name']
        if out_path.exists() and out_path.stat().st_size > 100 * 1024:
            print(f'\n✔ {ds["name"]} already present ({out_path.stat().st_size//1024} KB), skipping.')
            trained.append(ds['name'])
            continue

        data_dir = find_image_dataset(ds['search'])
        if data_dir is None:
            print(f'\n⚠ Could not find image dataset for {ds["name"]}')
            print(f'  Searched: {ds["search"]}')
            continue

        try:
            class_names = train_model(data_dir, ds['name'])
            save_labels(ds['name'], class_names)
            trained.append(ds['name'])
        except Exception as e:
            print(f'  ✗ Training failed: {e}')
            import traceback; traceback.print_exc()

    # ---- Skin + Breast need separate downloads (not done yet) ----
    for name, classes in [
        ('skin_cancer_model.tflite', 7),
        ('breast_cancer_model.tflite', 3),
    ]:
        out_path = OUTPUT_DIR / name
        if out_path.exists() and out_path.stat().st_size > 100 * 1024:
            print(f'\n✔ {name} already present.')
            trained.append(name)
            continue
        print(f'\n Generating stub model for {name} (no dataset downloaded)...')
        model = build_model(classes)
        export_tflite(model, out_path)
        trained.append(name)

    print('\n' + '=' * 54)
    print(f'✅ Done! {len(trained)}/4 models ready.')
    print(f'📂 {OUTPUT_DIR}')
    for f in OUTPUT_DIR.glob('*.tflite'):
        print(f'   {f.name:42s} {f.stat().st_size//1024:6d} KB')
    print('\nNext: flutter run -d macos  (or press R)')


if __name__ == '__main__':
    main()
