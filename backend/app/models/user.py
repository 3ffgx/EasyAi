import uuid
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, Numeric, Enum as SQLEnum
from sqlalchemy.orm import relationship
from ..core.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    nickname = Column(String(100), nullable=False)
    role = Column(SQLEnum("user", "admin", name="user_role"), default="user")
    tier_id = Column(String(50), default="free")
    balance = Column(Numeric(10, 2), default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # 关系
    conversations = relationship("Conversation", back_populates="user", lazy="selectin")
    usage_records = relationship("UsageRecord", back_populates="user", lazy="selectin")
    billing_records = relationship("BillingRecord", back_populates="user", lazy="selectin")
