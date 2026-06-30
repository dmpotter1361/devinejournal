from fastapi import APIRouter, Depends, HTTPException
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
