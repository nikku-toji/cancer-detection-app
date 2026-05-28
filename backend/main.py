"""Main FastAPI app with auth, scan storage, and MongoDB Atlas."""

from contextlib import asynccontextmanager
from fastapi import FastAPI, File, UploadFile, Form, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from bson import ObjectId
from datetime import datetime
import base64
import io
from pathlib import Path
from PIL import Image as PILImage
import numpy as np

from database import connect_db, close_db, get_scans_collection, get_users_collection
from auth import (
    verify_google_token, get_or_create_google_user, create_access_token,
    get_current_user, hash_password, verify_password
)
from models import (
    GoogleAuthRequest, EmailAuthRequest, RegisterRequest,
    TokenResponse, ScanReportCreate
)
from inference import CancerDetector
from config import MAX_IMAGE_SIZE_MB

detector: CancerDetector = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    await connect_db()
    global detector
    detector = CancerDetector(models_dir=Path('../assets/models'))
    await detector.load_all_models()
    yield
    await close_db()


app = FastAPI(
    title='Cancer Detection API',
    description='ML inference + auth + scan history with MongoDB Atlas',
    version='2.0.0',
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_methods=['*'],
    allow_headers=['*'],
)


# ============================================================
# Health
# ============================================================

@app.get('/health')
async def health():
    return {'status': 'healthy', 'models': list(detector.loaded_models)}


# ============================================================
# AUTH ROUTES
# ============================================================

@app.post('/auth/google', response_model=TokenResponse)
async def google_login(req: GoogleAuthRequest):
    """Exchange Google ID token for our JWT."""
    google_info = await verify_google_token(req.id_token)
    user = await get_or_create_google_user(google_info)
    token = create_access_token({'sub': str(user['_id'])})
    return TokenResponse(
        access_token=token,
        user=_serialize_user(user),
    )


@app.post('/auth/register', response_model=TokenResponse)
async def register(req: RegisterRequest):
    """Email/password registration."""
    users = get_users_collection()
    if await users.find_one({'email': req.email}):
        raise HTTPException(status_code=400, detail='Email already registered')

    new_user = {
        'email':          req.email,
        'name':           req.name,
        'password_hash':  hash_password(req.password),
        'auth_provider':  'email',
        'email_verified': False,
        'created_at':     datetime.utcnow(),
        'last_login':     datetime.utcnow(),
        'scan_count':     0,
        'picture':        None,
    }
    result = await users.insert_one(new_user)
    new_user['_id'] = result.inserted_id
    token = create_access_token({'sub': str(result.inserted_id)})
    return TokenResponse(access_token=token, user=_serialize_user(new_user))


@app.post('/auth/login', response_model=TokenResponse)
async def login(req: EmailAuthRequest):
    """Email/password login."""
    users = get_users_collection()
    user = await users.find_one({'email': req.email})
    if not user or not verify_password(req.password, user.get('password_hash', '')):
        raise HTTPException(status_code=401, detail='Invalid email or password')
    await users.update_one({'_id': user['_id']}, {'$set': {'last_login': datetime.utcnow()}})
    token = create_access_token({'sub': str(user['_id'])})
    return TokenResponse(access_token=token, user=_serialize_user(user))


@app.get('/auth/me')
async def get_me(current_user: dict = Depends(get_current_user)):
    return _serialize_user(current_user)


# ============================================================
# SCAN / PREDICT ROUTES
# ============================================================

@app.post('/predict')
async def predict(
    cancer_type: str = Form(...),
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
):
    """Run inference and save report to MongoDB."""
    VALID_TYPES = ['skin', 'lung', 'breast', 'brain']
    if cancer_type not in VALID_TYPES:
        raise HTTPException(400, f'cancer_type must be one of {VALID_TYPES}')

    # Read + validate image
    contents = await file.read()
    if len(contents) > MAX_IMAGE_SIZE_MB * 1024 * 1024:
        raise HTTPException(400, f'Image too large (max {MAX_IMAGE_SIZE_MB}MB)')

    try:
        image = PILImage.open(io.BytesIO(contents)).convert('RGB')
    except Exception:
        raise HTTPException(400, 'Invalid image file')

    # Run inference
    result = await detector.predict(cancer_type=cancer_type, image=image)

    # Compress image for storage (max 512px, 70% quality)
    image.thumbnail((512, 512))
    buf = io.BytesIO()
    image.save(buf, format='JPEG', quality=70)
    image_b64 = base64.b64encode(buf.getvalue()).decode()

    # Save to MongoDB
    scans = get_scans_collection()
    scan_doc = {
        'user_id':        str(current_user['_id']),
        'cancer_type':    cancer_type,
        'top_label':      result['topLabel'],
        'top_confidence': result['topConfidence'],
        'all_confidences':result['allConfidences'],
        'risk_level':     result['riskLevel'],
        'recommendation': result['recommendation'],
        'is_high_risk':   result['isHighRisk'],
        'image_base64':   image_b64,
        'image_mime':     'image/jpeg',
        'created_at':     datetime.utcnow(),
        'model_version':  'v1.0',
    }
    insert_result = await scans.insert_one(scan_doc)

    # Increment user scan count
    await get_users_collection().update_one(
        {'_id': current_user['_id']},
        {'$inc': {'scan_count': 1}}
    )

    return {
        **result,
        'scan_id': str(insert_result.inserted_id),
        'saved_to_db': True,
    }


# ============================================================
# SCAN HISTORY ROUTES
# ============================================================

@app.get('/scans')
async def get_scans(
    page: int = 1,
    limit: int = 20,
    cancer_type: str = None,
    current_user: dict = Depends(get_current_user),
):
    """Get paginated scan history for current user."""
    scans = get_scans_collection()
    query = {'user_id': str(current_user['_id'])}
    if cancer_type:
        query['cancer_type'] = cancer_type

    total = await scans.count_documents(query)
    cursor = scans.find(
        query,
        {'image_base64': 0}  # exclude large image from list
    ).sort('created_at', -1).skip((page - 1) * limit).limit(limit)

    docs = await cursor.to_list(length=limit)
    return {
        'total': total,
        'page':  page,
        'pages': (total + limit - 1) // limit,
        'scans': [_serialize_scan(d) for d in docs],
    }


@app.get('/scans/{scan_id}')
async def get_scan(
    scan_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Get single scan report with image."""
    scans = get_scans_collection()
    try:
        doc = await scans.find_one({
            '_id':     ObjectId(scan_id),
            'user_id': str(current_user['_id']),
        })
    except Exception:
        raise HTTPException(400, 'Invalid scan ID')

    if not doc:
        raise HTTPException(404, 'Scan not found')
    return _serialize_scan(doc, include_image=True)


@app.delete('/scans/{scan_id}')
async def delete_scan(
    scan_id: str,
    current_user: dict = Depends(get_current_user),
):
    scans = get_scans_collection()
    result = await scans.delete_one({
        '_id':     ObjectId(scan_id),
        'user_id': str(current_user['_id']),
    })
    if result.deleted_count == 0:
        raise HTTPException(404, 'Scan not found')
    await get_users_collection().update_one(
        {'_id': current_user['_id']},
        {'$inc': {'scan_count': -1}}
    )
    return {'deleted': True}


# ============================================================
# ANALYTICS ROUTES
# ============================================================

@app.get('/analytics/summary')
async def get_analytics(current_user: dict = Depends(get_current_user)):
    """Aggregated analytics for the current user's scans."""
    scans = get_scans_collection()
    user_id = str(current_user['_id'])

    # Total scans per cancer type
    pipeline_by_type = [
        {'$match': {'user_id': user_id}},
        {'$group': {'_id': '$cancer_type', 'count': {'$sum': 1},
                    'high_risk': {'$sum': {'$cond': ['$is_high_risk', 1, 0]}}}},
    ]
    by_type = await scans.aggregate(pipeline_by_type).to_list(None)

    # Risk level distribution
    pipeline_risk = [
        {'$match': {'user_id': user_id}},
        {'$group': {'_id': '$risk_level', 'count': {'$sum': 1}}},
    ]
    risk_dist = await scans.aggregate(pipeline_risk).to_list(None)

    # Scans over time (last 30 days)
    from datetime import timedelta
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    pipeline_time = [
        {'$match': {'user_id': user_id, 'created_at': {'$gte': thirty_days_ago}}},
        {'$group': {
            '_id': {'$dateToString': {'format': '%Y-%m-%d', 'date': '$created_at'}},
            'count': {'$sum': 1}
        }},
        {'$sort': {'_id': 1}},
    ]
    over_time = await scans.aggregate(pipeline_time).to_list(None)

    total = await scans.count_documents({'user_id': user_id})
    high_risk_total = await scans.count_documents({'user_id': user_id, 'is_high_risk': True})

    return {
        'total_scans':   total,
        'high_risk_total': high_risk_total,
        'by_cancer_type': by_type,
        'risk_distribution': risk_dist,
        'scans_over_time': over_time,
    }


# ============================================================
# Helpers
# ============================================================

def _serialize_user(user: dict) -> dict:
    return {
        'id':             str(user['_id']),
        'email':          user.get('email'),
        'name':           user.get('name'),
        'picture':        user.get('picture'),
        'auth_provider':  user.get('auth_provider', 'email'),
        'scan_count':     user.get('scan_count', 0),
        'created_at':     user.get('created_at', datetime.utcnow()).isoformat(),
    }


def _serialize_scan(doc: dict, include_image: bool = False) -> dict:
    result = {
        'id':              str(doc['_id']),
        'user_id':         doc.get('user_id'),
        'cancer_type':     doc.get('cancer_type'),
        'top_label':       doc.get('top_label'),
        'top_confidence':  doc.get('top_confidence'),
        'all_confidences': doc.get('all_confidences', {}),
        'risk_level':      doc.get('risk_level'),
        'recommendation':  doc.get('recommendation'),
        'is_high_risk':    doc.get('is_high_risk', False),
        'has_image':       bool(doc.get('image_base64')),
        'created_at':      doc.get('created_at', datetime.utcnow()).isoformat(),
        'model_version':   doc.get('model_version', 'v1.0'),
    }
    if include_image and doc.get('image_base64'):
        result['image_base64'] = doc['image_base64']
        result['image_mime']   = doc.get('image_mime', 'image/jpeg')
    return result
