import requests as req
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..database import get_db
from ..schemas import TokenResponse
from .. import models
from ..jwt import create_token

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/google", response_model=TokenResponse)
def google_signin(payload: dict, db: Session = Depends(get_db)):
    access_token = payload.get("access_token")
    if not access_token:
        raise HTTPException(status_code=400, detail="Missing access_token")

    resp = req.get(
        "https://www.googleapis.com/oauth2/v2/userinfo",
        headers={"Authorization": f"Bearer {access_token}"},
        timeout=10,
    )
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail=f"Google rejected token: {resp.text}")

    info = resp.json()
    google_id = info.get("id")
    if not google_id:
        raise HTTPException(status_code=401, detail="No user ID in Google response")

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
