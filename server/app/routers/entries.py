from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID
from ..database import get_db
from ..schemas import EntryCreate, EntryUpdate, EntryOut
from .. import models
from ..jwt import current_user

router = APIRouter(prefix="/entries", tags=["entries"])

@router.get("", response_model=List[EntryOut])
def list_entries(
    db: Session = Depends(get_db),
    user: models.User = Depends(current_user),
):
    return (
        db.query(models.Entry)
        .filter(models.Entry.user_id == user.id)
        .order_by(models.Entry.created_at.desc())
        .all()
    )

@router.post("", response_model=EntryOut, status_code=201)
def create_entry(
    body: EntryCreate,
    db: Session = Depends(get_db),
    user: models.User = Depends(current_user),
):
    entry = models.Entry(user_id=user.id, **body.model_dump())
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry

def _is_sealed(entry: models.Entry) -> bool:
    if not entry.locked_until:
        return False
    try:
        date_part = entry.locked_until.split("T")[0]
        y, m, d = (int(x) for x in date_part.split("-"))
        # The client unseals at LOCAL midnight of the open date. The server
        # doesn't know the client's timezone, so hold search results until
        # 12:00 UTC that day — covers UTC-4..-12, never unseals in search
        # before the timeline card unlocks.
        opens = datetime(y, m, d, 12, 0, tzinfo=timezone.utc)
        return opens > datetime.now(timezone.utc)
    except (ValueError, AttributeError):
        return False

# NOTE: must be registered before /{entry_id} or "search" gets parsed as a UUID
@router.get("/search", response_model=List[EntryOut])
def search_entries(
    q: str = "",
    db: Session = Depends(get_db),
    user: models.User = Depends(current_user),
):
    q = q.strip()
    if not q:
        return []
    escaped = q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    like = f"%{escaped}%"
    rows = (
        db.query(models.Entry)
        .filter(
            models.Entry.user_id == user.id,
            or_(
                models.Entry.title.ilike(like),
                models.Entry.body.ilike(like),
                models.Entry.tags.ilike(like),
            ),
        )
        .order_by(models.Entry.created_at.desc())
        .limit(50)
        .all()
    )
    # Sealed entries stay sealed — never surface their content in search
    return [e for e in rows if not _is_sealed(e)]

@router.get("/{entry_id}", response_model=EntryOut)
def get_entry(
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
    return entry

@router.put("/{entry_id}", response_model=EntryOut)
def update_entry(
    entry_id: UUID,
    body: EntryUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(current_user),
):
    entry = db.query(models.Entry).filter(
        models.Entry.id == entry_id,
        models.Entry.user_id == user.id,
    ).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(entry, field, value)
    db.commit()
    db.refresh(entry)
    return entry

@router.delete("/{entry_id}", status_code=204)
def delete_entry(
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
    db.delete(entry)
    db.commit()
