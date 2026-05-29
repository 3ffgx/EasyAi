import uuid
from datetime import datetime
from sqlalchemy import Column, String, Integer, Numeric, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from ..core.database import Base


class UsageRecord(Base):
    __tablename__ = "usage_records"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    conversation_id = Column(String(36), ForeignKey("conversations.id"), nullable=True)
    model_id = Column(String(100), nullable=False)
    tokens_input = Column(Integer, default=0)
    tokens_output = Column(Integer, default=0)
    cost = Column(Numeric(10, 6), default=0)
    created_at = Column(DateTime, default=datetime.utcnow)

    # 关系
    user = relationship("User", back_populates="usage_records")


class BillingRecord(Base):
    __tablename__ = "billing_records"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    amount = Column(Numeric(10, 2), nullable=False)
    type = Column(String(20), nullable=False)  # topup, usage, refund
    description = Column(String(500))
    created_at = Column(DateTime, default=datetime.utcnow)

    # 关系
    user = relationship("User", back_populates="billing_records")


class ModelConfig(Base):
    __tablename__ = "model_configs"

    id = Column(String(100), primary_key=True)
    name = Column(String(100), nullable=False)
    provider = Column(String(50), nullable=False)
    api_base = Column(String(500), nullable=False)
    api_key = Column(String(500))
    is_active = Column(Boolean, default=False)  # 默认不启用
    is_verified = Column(Boolean, default=False)  # API Key 是否已验证通过
    last_test_at = Column(DateTime, nullable=True)  # 最后测试时间
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class TierConfig(Base):
    __tablename__ = "tier_configs"

    id = Column(String(50), primary_key=True)
    name = Column(String(100), nullable=False)
    monthly_price = Column(Numeric(10, 2), default=0)
    free_quota = Column(Integer, default=0)
    overage_rate = Column(Numeric(10, 6), default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class SystemConfig(Base):
    __tablename__ = "system_configs"

    key = Column(String(100), primary_key=True)
    value = Column(String(1000))
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Announcement(Base):
    __tablename__ = "announcements"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String(200), nullable=False)
    content = Column(String(2000), nullable=False)
    type = Column(String(20), default="info")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
