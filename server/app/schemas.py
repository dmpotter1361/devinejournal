from pydantic import BaseModel
from datetime import datetime
from uuid import UUID
from typing import Optional, List

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_name: str
    user_picture: str

class PhotoOut(BaseModel):
    id: UUID
    entry_id: UUID
    data: str
    width_pct: str = "100"
    align: str = "center"
    caption: str = ""
    sort_order: str = "0"
    created_at: datetime
    model_config = {"from_attributes": True}

class PhotoUpdate(BaseModel):
    width_pct: Optional[str] = None
    align: Optional[str] = None
    caption: Optional[str] = None

class EntryCreate(BaseModel):
    title: str = ""
    body: str = ""
    mood: str = ""
    tags: str = ""
    locked_until: Optional[str] = None
    paper_style: str = "lined"
    is_favorite: bool = False

class EntryUpdate(BaseModel):
    title: Optional[str] = None
    body: Optional[str] = None
    mood: Optional[str] = None
    tags: Optional[str] = None
    locked_until: Optional[str] = None
    paper_style: Optional[str] = None
    is_favorite: Optional[bool] = None

class EntryOut(BaseModel):
    id: UUID
    title: str
    body: str
    mood: str
    tags: str = ""
    locked_until: Optional[str] = None
    paper_style: str = "lined"
    is_favorite: bool = False
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
