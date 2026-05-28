import asyncio
import numpy as np
from pathlib import Path
from PIL import Image
from typing import Dict, List
from constants import LABELS, RISK_LABELS

try:
    import tflite_runtime.interpreter as tflite
except ImportError:
    import tensorflow.lite as tflite


class CancerDetector:
    def __init__(self, models_dir: Path):
        self.models_dir = models_dir
        self.interpreters: Dict[str, tflite.Interpreter] = {}
        self.loaded_models: List[str] = []

    async def load_all_models(self):
        for cancer_type in LABELS.keys():
            model_path = self.models_dir / f'{cancer_type}_cancer_model.tflite'
            if cancer_type == 'brain':
                model_path = self.models_dir / 'brain_tumor_model.tflite'
            if model_path.exists():
                await asyncio.get_event_loop().run_in_executor(
                    None, self._load_model, cancer_type, model_path
                )
                self.loaded_models.append(cancer_type)
                print(f'  Loaded model: {cancer_type}')
            else:
                print(f'  Model not found: {model_path}')

    def _load_model(self, cancer_type: str, model_path: Path):
        interpreter = tflite.Interpreter(model_path=str(model_path))
        interpreter.allocate_tensors()
        self.interpreters[cancer_type] = interpreter

    def _preprocess(self, image: Image.Image, size: int = 224) -> np.ndarray:
        image = image.resize((size, size))
        arr = np.array(image, dtype=np.float32) / 255.0
        return np.expand_dims(arr, axis=0)

    async def predict(self, cancer_type: str, image: Image.Image) -> dict:
        if cancer_type not in self.interpreters:
            raise ValueError(f'Model for {cancer_type} not loaded')

        interpreter = self.interpreters[cancer_type]
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()

        size = input_details[0]['shape'][1]
        input_data = self._preprocess(image, size)

        interpreter.set_tensor(input_details[0]['index'], input_data)
        interpreter.invoke()
        output = interpreter.get_tensor(output_details[0]['index'])[0]

        labels = LABELS[cancer_type]
        confidences = {labels[i]: float(output[i]) for i in range(len(labels))}
        top_label = max(confidences, key=confidences.get)
        top_confidence = confidences[top_label]

        is_low_risk = top_label in RISK_LABELS.get(cancer_type, [])
        risk_level = 'low' if (is_low_risk and top_confidence > 0.7) else (
            'high' if top_confidence > 0.8 else 'medium'
        )

        rec_map = {
            'high': f'High confidence detection of {top_label}. Consult a specialist immediately.',
            'medium': f'Uncertain result. Further examination recommended.',
            'low': 'Low risk detected. Regular screening recommended.',
        }

        return {
            'cancerType': cancer_type,
            'imagePath': '',
            'topLabel': top_label,
            'topConfidence': top_confidence,
            'allConfidences': confidences,
            'timestamp': __import__('datetime').datetime.utcnow().isoformat(),
            'isHighRisk': risk_level == 'high',
            'riskLevel': risk_level,
            'recommendation': rec_map[risk_level],
        }

    def cleanup(self):
        self.interpreters.clear()
