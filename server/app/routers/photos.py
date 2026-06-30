from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from uuid import UUID
from PIL import Image
import io, base64
from ..database import get_db
from ..schemas import PhotoOut, PhotoUpdate
from .. import models
from ..jwt import current_user

router = APIRouter(tags=["photos"])


@router.post("/entries/{entry_id}/photos", response_model=PhotoOut, status_code=201)
async def upload_photo(
    entry_id: UUID,
    file: UploadFile = File(...),
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
    img = Image.open(io.BytesIO(contents)).convert("RGB")

    max_px = 1400
    if img.width > max_px or img.height > max_px:
        img.thumbnail((max_px, max_px), Image.LANCZOS)

    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=88)
    b64 = "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()

    count = db.query(models.Photo).filter(models.Photo.entry_id == entry_id).count()

    photo = models.Photo(
        entry_id=entry_id,
        user_id=user.id,
        data=b64,
        sort_order=str(count),
    )
    db.add(photo)
    db.commit()
    db.refresh(photo)
    return photo


@router.get("/entries/{entry_id}/photos", response_model=list[PhotoOut])
def list_photos(
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
        db.query(models.Photo)
        .filter(models.Photo.entry_id == entry_id)
        .order_by(models.Photo.sort_order)
        .all()
    )


@router.put("/photos/{photo_id}", response_model=PhotoOut)
def update_photo(
    photo_id: UUID,
    body: PhotoUpdate,
    db: Session = Depends(get_db),
    user: models.User = Depends(current_user),
):
    photo = db.query(models.Photo).filter(
        models.Photo.id == photo_id,
        models.Photo.user_id == user.id,
    ).first()
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(photo, field, value)
    db.commit()
    db.refresh(photo)
    return photo


@router.delete("/photos/{photo_id}", status_code=204)
def delete_photo(
    photo_id: UUID,
    db: Session = Depends(get_db),
    user: models.User = Depends(current_user),
):
    photo = db.query(models.Photo).filter(
        models.Photo.id == photo_id,
        models.Photo.user_id == user.id,
    ).first()
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")
    db.delete(photo)
    db.commit()
