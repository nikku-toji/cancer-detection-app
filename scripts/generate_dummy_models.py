#!/usr/bin/env python3
"""
generate_dummy_models.py
------------------------
Generates minimal but fully valid TFLite models using TensorFlow.
Requires Python <= 3.12 and TensorFlow >= 2.13.

Usage (Python 3.12 venv):
  python generate_dummy_models.py
"""

import sys
from pathlib import Path

OUTPUT_DIR = Path(__file__).parent.parent / 'assets' / 'models'
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

MODELS = [
    {'name': 'skin_cancer_model.tflite',   'classes': 7},
    {'name': 'lung_cancer_model.tflite',   'classes': 4},
    {'name': 'breast_cancer_model.tflite', 'classes': 3},
    {'name': 'brain_tumor_model.tflite',   'classes': 4},
]


def generate(name: str, num_classes: int, input_size: int = 224):
    try:
        import tensorflow as tf
    except ImportError:
        print('TensorFlow not found. Install it with: pip install tensorflow')
        print('Note: TensorFlow requires Python <= 3.12')
        sys.exit(1)

    print(f'Generating {name} ({num_classes} classes)...')
    inp = tf.keras.Input(shape=(input_size, input_size, 3))
    x = tf.keras.layers.GlobalAveragePooling2D()(
        tf.keras.layers.Conv2D(16, 3, activation='relu', padding='same')(inp)
    )
    out = tf.keras.layers.Dense(num_classes, activation='softmax')(x)
    model = tf.keras.Model(inp, out)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_bytes = converter.convert()

    dest = OUTPUT_DIR / name
    dest.write_bytes(tflite_bytes)
    print(f'  Saved {dest} ({len(tflite_bytes) // 1024} KB)')


if __name__ == '__main__':
    print(f'Python {sys.version}')
    for m in MODELS:
        generate(m['name'], m['classes'])
    print('\nDone! Copy these to assets/models/ and run flutter run.')
