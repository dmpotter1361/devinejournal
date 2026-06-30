from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
from ..database import get_db
from ..config import settings
from ..schemas import TokenResponse
from .. import models
from ..jwt import create_token

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/google", response_model=TokenResponse)
def google_signin(payload: dict, db: Session = Depends(get_db)):
    credential = payload.get("credential")
    if not credential:
        raise HTTPException(status_code=400, detail="Missing credential")

    try:
        info = id_token.verify_oauth2_token(
            credential,
            google_requests.Request(),
            settings.google_client_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=401, detail=f"Invalid Google token: {e}")

    google_id = info["sub"]
    user = db.query(models.User).filter(models.User.google_id == google_id).first()
    if not user:
        user = models.User(
            google_id=google_id,
            email=info.get("email", ""),
            name=info.get("name", ""),
            picture=info.get("picture", ""),
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    token = create_token(str(user.id))
    return TokenResponse(access_token=token, user_name=user.name, user_picture=user.picture)
