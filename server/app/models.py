import uuid
from sqlalchemy import Column, String, DateTime, Text, Boolean, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from .database import Base

class User(Base):
    __tablename__ = "users"
    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    google_id  = Column(String, unique=True, nullable=False, index=True)
    email      = Column(String, unique=True, nullable=False)
    name       = Column(String, default="")
    picture    = Column(String, default="")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Entry(Base):
    __tablename__ = "entries"
    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title      = Column(String, default="")
    body       = Column(Text, default="")
    mood       = Column(String, default="")
    tags         = Column(Text, default="")
    locked_until = Column(Text, nullable=True)
    paper_style  = Column(Text, nullable=False, server_default='lined', default='lined')
    is_favorite  = Column(Boolean, nullable=False, server_default='false', default=False)
    theme_id     = Column(String, nullable=True)        # per-entry theme override (null = global)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

class Photo(Base):
    __tablename__ = "photos"
    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    entry_id   = Column(UUID(as_uuid=True), ForeignKey("entries.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.id",   ondelete="CASCADE"), nullable=False, index=True)
    data       = Column(Text, nullable=False)          # base64 data URL (JPEG)
    width_pct  = Column(String, default="100")         # "25" | "50" | "75" | "100"
    align      = Column(String, default="center")      # "left" | "center" | "right"
    caption    = Column(String, default="")
    sort_order = Column(String, default="0")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class VoiceMemo(Base):
    __tablename__ = "voice_memos"
    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    entry_id    = Column(UUID(as_uuid=True), ForeignKey("entries.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id     = Column(UUID(as_uuid=True), ForeignKey("users.id",   ondelete="CASCADE"), nullable=False, index=True)
    data        = Column(Text, nullable=False)          # base64 data URL (webm/ogg audio)
    duration_ms = Column(String, default="0")
    transcript  = Column(Text, default="")
    sort_order  = Column(String, default="0")
    created_at  = Column(DateTime(timezone=True), server_default=func.now())
