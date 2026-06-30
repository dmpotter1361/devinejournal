from pydantic import BaseModel
from datetime import datetime
from uuid import UUID
from typing import Optional

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_name: str
    user_picture: str

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
