from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class UserListResponse(BaseModel):
    items: List[dict]
    total: int


class UpdateUserRequest(BaseModel):
    nickname: Optional[str] = None
    role: Optional[str] = None
    tier_id: Optional[str] = None
    is_active: Optional[bool] = None


class ModelConfigRequest(BaseModel):
    id: Optional[str] = None
    name: Optional[str] = None
    provider: Optional[str] = None
    api_base: Optional[str] = None
    api_key: Optional[str] = None
    is_active: Optional[bool] = None


class ModelConfigResponse(BaseModel):
    id: str
    name: str
    provider: str
    api_base: str
    is_active: bool

    class Config:
        from_attributes = True


class TierConfigRequest(BaseModel):
    id: str
    name: str
    monthly_price: float = 0
    free_quota: int = 0
    overage_rate: float = 0
    is_active: bool = True


class TierConfigResponse(BaseModel):
    id: str
    name: str
    monthly_price: float
    free_quota: int
    overage_rate: float
    is_active: bool

    class Config:
        from_attributes = True


class AnnouncementRequest(BaseModel):
    title: str
    content: str
    type: str = "info"


class GlobalConfigRequest(BaseModel):
    max_context_turns: Optional[int] = None
    max_tokens_per_message: Optional[int] = None
    daily_free_tokens: Optional[int] = None


class StatisticsResponse(BaseModel):
    total_users: int = 0
    total_conversations: int = 0
    total_tokens: int = 0
    total_revenue: float = 0
    today_users: int = 0
    today_conversations: int = 0
    today_tokens: int = 0
    today_revenue: float = 0


class UsageStatsResponse(BaseModel):
    total_tokens: int = 0
    total_cost: float = 0
    today_tokens: int = 0
    today_cost: float = 0
    month_tokens: int = 0
    month_cost: float = 0
