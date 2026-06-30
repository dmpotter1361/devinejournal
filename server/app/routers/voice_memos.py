from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from uuid import UUID
import base64
from ..database import get_db
from ..schemas import VoiceMemoOut, VoiceMemoUpdate
from .. import models
from ..jwt import current_user

router = APIRouter(tags=["voice_memos"])


@router.post("/entries/{entry_id}/voice-memos", response_model=VoiceMemoOut, status_code=201)
async def upload_voice_memo(
    entry_id: UUID,
    file: UploadFile = File(...),
    duration_ms: str = Form("0"),
    db: Session = Depends(get_db),
    user: models.User = Depends(current_user),
):
    entry = db.query(models.Entry).filter(
        models.Entry.id == entry_id,
        models.Entry.user_id == user.id,
    ).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")

    contents = await file.read()
    mime = file.content_type or "audio/webm"
    b64 = f"data:{mime};base64," + base64.b64encode(contents).decode()

    count = db.query(models.VoiceMemo).filter(models.VoiceMemo.entry_id == entry_id).count()

    memo = models.VoiceMemo(
        entry_id=entry_id,
        user_id=user.id,
        data=b64,
        duration_ms=duration_ms,
        sort_order=str(count),
    )
    db.add(memo)
    db.commit()
    db.refresh(memo)
    return memo


@router.get("/entries/{entry_id}/voice-memos", response_model=list[VoiceMemoOut])
def list_voice_memos(
    entry_id: UUID,
    db: Session = Depends(get_db),
    user: models.User = Depends(current_user),
):
    entry = db.query(models.Entry).filter(
        models.Entry.id == entry_id,
        models.Entry.user_id == user.id,
    ).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    return (
        db.query(models.VoiceMemo)
        .filter(models.VoiceMemo.entry_id == entry_id)
        .order_by(models.VoiceMemo.sort_order)
        .all()
    )


@router.put("/voice-memos/{memo_id}", response_model=VoiceMemoOut)
def update_voice_memo(
    memo_id: UUID,
    body: VoiceMemoUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(current_user),
):
    memo = db.query(models.VoiceMemo).filter(
        models.VoiceMemo.id == memo_id,
        models.VoiceMemo.user_id == user.id,
    ).first()
    if not memo:
        raise HTTPException(status_code=404, detail="Voice memo not found")
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(memo, field, value)
    db.commit()
    db.refresh(memo)
    return memo


@router.delete("/voice-memos/{memo_id}", status_code=204)
def delete_voice_memo(
    memo_id: UUID,
    db: Session = Depends(get_db),
    user: models.User = Depends(current_user),
):
    memo = db.query(models.VoiceMemo).filter(
        models.VoiceMemo.id == memo_id,
        models.VoiceMemo.user_id == user.id,
    ).first()
    if not memo:
        raise HTTPException(status_code=404, detail="Voice memo not found")
    db.delete(memo)
    db.commit()
