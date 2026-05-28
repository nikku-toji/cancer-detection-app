#!/usr/bin/env python3
"""
train_skin_cancer.py
---------------------
Trains a MobileNetV2 model on the HAM10000 / ISIC skin lesion dataset
and exports it as TFLite for use in the Flutter app.

Dataset: HAM10000 (10,015 dermoscopic images, 7 classes)
Download: https://www.kaggle.com/datasets/kmader/skin-cancer-mnist-ham10000

Usage:
  python train_skin_cancer.py --data_dir ./data/HAM10000 --epochs 20
"""

import argparse
import os
from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow.keras import layers, Model
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.callbacks import ModelCheckpoint, EarlyStopping, ReduceLROnPlateau
from sklearn.model_selection import train_test_split
from sklearn.utils.class_weight import compute_class_weight

LABELS = [
    'akiec', 'bcc', 'bkl', 'df', 'mel', 'nv', 'vasc'
]
LABEL_NAMES = [
    'Actinic keratoses', 'Basal cell carcinoma', 'Benign keratosis',
    'Dermatofibroma', 'Melanoma', 'Melanocytic nevi', 'Vascular lesions'
]
IMG_SIZE = 224
BATCH_SIZE = 32


def load_dataset(data_dir: Path):
    meta = pd.read_csv(data_dir / 'HAM10000_metadata.csv')
    meta['label_idx'] = meta['dx'].map({l: i for i, l in enumerate(LABELS)})

    image_dirs = [
        data_dir / 'HAM10000_images_part_1',
        data_dir / 'HAM10000_images_part_2',
    ]

    def find_image(image_id):
        for d in image_dirs:
            p = d / f'{image_id}.jpg'
            if p.exists():
                return str(p)
        return None

    meta['path'] = meta['image_id'].apply(find_image)
    meta = meta.dropna(subset=['path'])
    return meta


def build_model(num_classes: int = 7):
    base = MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights='imagenet',
    )
    base.trainable = False

    inputs = layers.Input(shape=(IMG_SIZE, IMG_SIZE, 3))
    x = tf.keras.applications.mobilenet_v2.preprocess_input(inputs)
    x = base(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(256, activation='relu')(x)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(num_classes, activation='softmax')(x)

    return Model(inputs, outputs)


def train(args):
    data_dir = Path(args.data_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print('Loading dataset...')
    meta = load_dataset(data_dir)

    train_df, val_df = train_test_split(
        meta, test_size=0.2, stratify=meta['label_idx'], random_state=42
    )

    # Class weights for imbalanced dataset
    class_weights = compute_class_weight(
        'balanced', classes=np.unique(train_df['label_idx']), y=train_df['label_idx']
    )
    class_weight_dict = dict(enumerate(class_weights))

    def load_image(path, label):
        img = tf.io.read_file(path)
        img = tf.image.decode_jpeg(img, channels=3)
        img = tf.image.resize(img, [IMG_SIZE, IMG_SIZE])
        return img, label

    def augment(img, label):
        img = tf.image.random_flip_left_right(img)
        img = tf.image.random_flip_up_down(img)
        img = tf.image.random_brightness(img, 0.1)
        img = tf.image.random_contrast(img, 0.9, 1.1)
        return img, label

    train_ds = (
        tf.data.Dataset.from_tensor_slices(
            (train_df['path'].values, train_df['label_idx'].values)
        )
        .map(load_image, num_parallel_calls=tf.data.AUTOTUNE)
        .map(augment, num_parallel_calls=tf.data.AUTOTUNE)
        .batch(BATCH_SIZE)
        .prefetch(tf.data.AUTOTUNE)
    )

    val_ds = (
        tf.data.Dataset.from_tensor_slices(
            (val_df['path'].values, val_df['label_idx'].values)
        )
        .map(load_image, num_parallel_calls=tf.data.AUTOTUNE)
        .batch(BATCH_SIZE)
        .prefetch(tf.data.AUTOTUNE)
    )

    print('Building model...')
    model = build_model(num_classes=len(LABELS))
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy'],
    )

    callbacks = [
        ModelCheckpoint(output_dir / 'best_model.keras', save_best_only=True),
        EarlyStopping(patience=5, restore_best_weights=True),
        ReduceLROnPlateau(patience=3, factor=0.5),
    ]

    print(f'Training for {args.epochs} epochs...')
    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.epochs,
        class_weight=class_weight_dict,
        callbacks=callbacks,
    )

    # Fine-tune
    print('Fine-tuning top layers...')
    for layer in model.layers[-30:]:
        layer.trainable = True
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-5),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy'],
    )
    model.fit(train_ds, validation_data=val_ds, epochs=10, callbacks=callbacks)

    # Export TFLite
    print('Converting to TFLite...')
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    tflite_path = output_dir / 'skin_cancer_model.tflite'
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)

    print(f'\n✅ TFLite model saved: {tflite_path}')
    print(f'   Size: {len(tflite_model) // 1024} KB')
    print(f'\n📂 Copy to Flutter assets:')
    print(f'   cp {tflite_path} ../assets/models/skin_cancer_model.tflite')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--data_dir', required=True, help='Path to HAM10000 directory')
    parser.add_argument('--output_dir', default='./trained_models')
    parser.add_argument('--epochs', type=int, default=20)
    args = parser.parse_args()
    train(args)
