import uuid
from sqlalchemy import Column, String, DateTime, Text, ForeignKey, func
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
    tags       = Column(Text, default="")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
