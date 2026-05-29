from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class CreateConversationRequest(BaseModel):
    model_id: Optional[str] = None


class ConversationResponse(BaseModel):
    id: str
    title: str
    model_id: str
    created_at: datetime
    updated_at: Optional[datetime] = None
    last_message_at: Optional[datetime] = None
    message_count: int = 0

    class Config:
        from_attributes = True


class SendMessageRequest(BaseModel):
    conversation_id: str
    content: str
    model_id: Optional[str] = None


class MessageResponse(BaseModel):
    id: str
    role: str
    content: str
    tokens_used: int
    created_at: datetime

    class Config:
        from_attributes = True


class ConversationListResponse(BaseModel):
    items: List[ConversationResponse]
    total: int


class MessageListResponse(BaseModel):
    items: List[MessageResponse]
    total: int
