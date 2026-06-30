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

class EntryUpdate(BaseModel):
    title: Optional[str] = None
    body: Optional[str] = None
    mood: Optional[str] = None

class EntryOut(BaseModel):
    id: UUID
    title: str
    body: str
    mood: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
