"""FastAPI backend for cloud-based cancer detection inference.

Run with:
  uvicorn main:app --reload --port 8000
"""

from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import numpy as np
from PIL import Image
import io
import time
from pathlib import Path

from inference import CancerDetector

detector: CancerDetector = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global detector
    detector = CancerDetector(models_dir=Path('../assets/models'))
    await detector.load_all_models()
    yield
    detector.cleanup()


app = FastAPI(
    title='Cancer Detection API',
    description='ML inference backend for Flutter Cancer Detection App',
    version='1.0.0',
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_methods=['*'],
    allow_headers=['*'],
)


@app.get('/health')
async def health():
    return {'status': 'healthy', 'models_loaded': list(detector.loaded_models)}


@app.post('/predict')
async def predict(
    cancer_type: str = Form(...),
    file: UploadFile = File(...),
):
    VALID_TYPES = ['skin', 'lung', 'breast', 'brain']
    if cancer_type not in VALID_TYPES:
        raise HTTPException(400, f'cancer_type must be one of {VALID_TYPES}')

    # Read and validate image
    contents = await file.read()
    try:
        image = Image.open(io.BytesIO(contents)).convert('RGB')
    except Exception:
        raise HTTPException(400, 'Invalid image file')

    start_time = time.time()
    result = await detector.predict(cancer_type=cancer_type, image=image)
    inference_time_ms = round((time.time() - start_time) * 1000, 1)

    return {
        **result,
        'inference_time_ms': inference_time_ms,
        'model': 'cloud',
    }


@app.get('/labels/{cancer_type}')
async def get_labels(cancer_type: str):
    from constants import LABELS
    if cancer_type not in LABELS:
        raise HTTPException(404, 'Cancer type not found')
    return {'cancer_type': cancer_type, 'labels': LABELS[cancer_type]}
