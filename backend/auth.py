from datetime import datetime, timedelta
from typing import Optional
import httpx
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from bson import ObjectId

from config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES, GOOGLE_CLIENT_ID
from database import get_users_collection

pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')
bearer_scheme = HTTPBearer()

GOOGLE_TOKEN_INFO_URL = 'https://oauth2.googleapis.com/tokeninfo'
GOOGLE_USERINFO_URL = 'https://www.googleapis.com/oauth2/v3/userinfo'


# ---- Password helpers ----

def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


# ---- JWT helpers ----

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({'exp': expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid or expired token',
            headers={'WWW-Authenticate': 'Bearer'},
        )


# ---- Google OAuth ----

async def verify_google_token(id_token: str) -> dict:
    """Verify Google ID token and return user info."""
    async with httpx.AsyncClient() as client:
        # Verify with Google
        resp = await client.get(GOOGLE_TOKEN_INFO_URL, params={'id_token': id_token})
        if resp.status_code != 200:
            raise HTTPException(status_code=401, detail='Invalid Google token')
        info = resp.json()

    if info.get('aud') != GOOGLE_CLIENT_ID:
        raise HTTPException(status_code=401, detail='Token audience mismatch')

    return {
        'google_id':   info.get('sub'),
        'email':       info.get('email'),
        'name':        info.get('name'),
        'picture':     info.get('picture'),
        'email_verified': info.get('email_verified') == 'true',
    }


async def get_or_create_google_user(google_info: dict) -> dict:
    """Find existing user or create new one from Google profile."""
    users = get_users_collection()
    user = await users.find_one({'google_id': google_info['google_id']})

    if not user:
        # Also check by email (user may have registered with email before)
        user = await users.find_one({'email': google_info['email']})
        if user:
            # Link Google account to existing user
            await users.update_one(
                {'_id': user['_id']},
                {'$set': {'google_id': google_info['google_id'],
                          'picture': google_info['picture']}}
            )
        else:
            # Create new user
            new_user = {
                'google_id':      google_info['google_id'],
                'email':          google_info['email'],
                'name':           google_info['name'],
                'picture':        google_info['picture'],
                'email_verified': google_info['email_verified'],
                'auth_provider':  'google',
                'created_at':     datetime.utcnow(),
                'last_login':     datetime.utcnow(),
                'scan_count':     0,
            }
            result = await users.insert_one(new_user)
            new_user['_id'] = result.inserted_id
            return new_user

    # Update last login
    await users.update_one(
        {'_id': user['_id']},
        {'$set': {'last_login': datetime.utcnow()}}
    )
    return user


# ---- Current user dependency ----

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme)
) -> dict:
    payload = decode_token(credentials.credentials)
    user_id = payload.get('sub')
    if not user_id:
        raise HTTPException(status_code=401, detail='Invalid token payload')

    users = get_users_collection()
    user = await users.find_one({'_id': ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=401, detail='User not found')
    return user
