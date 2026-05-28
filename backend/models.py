from pydantic import BaseModel, EmailStr
from typing import Optional, Dict
from datetime import datetime


class GoogleAuthRequest(BaseModel):
    id_token: str  # Google ID token from mobile app


class EmailAuthRequest(BaseModel):
    email: EmailStr
    password: str


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    name: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = 'bearer'
    user: dict


class UserProfile(BaseModel):
    id: str
    email: str
    name: str
    picture: Optional[str] = None
    auth_provider: str
    scan_count: int
    created_at: datetime


class ScanReportCreate(BaseModel):
    cancer_type: str
    top_label: str
    top_confidence: float
    all_confidences: Dict[str, float]
    risk_level: str
    recommendation: str
    image_base64: Optional[str] = None  # base64 encoded image
    image_mime_type: Optional[str] = 'image/jpeg'


class ScanReportResponse(BaseModel):
    id: str
    cancer_type: str
    top_label: str
    top_confidence: float
    all_confidences: Dict[str, float]
    risk_level: str
    recommendation: str
    has_image: bool
    created_at: datetime
    user_id: str
