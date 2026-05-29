import json
import uuid
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from ..core.database import get_db
from ..core.security import get_current_user
from ..models.user import User
from ..models.conversation import Conversation
from ..models.message import Message
from ..schemas.chat import (
    CreateConversationRequest,
    ConversationResponse,
    SendMessageRequest,
    MessageResponse,
)
from ..services.chat_service import ChatService

router = APIRouter(tags=["聊天"])


@router.get("/api/conversations", response_model=list[ConversationResponse])
async def get_conversations(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import func

    # 获取对话列表，包含最后消息时间和消息数量
    result = await db.execute(
        select(
            Conversation,
            func.max(Message.created_at).label("last_message_at"),
            func.count(Message.id).label("message_count")
        )
        .outerjoin(Message, Message.conversation_id == Conversation.id)
        .where(Conversation.user_id == current_user.id)
        .group_by(Conversation.id)
        .order_by(Conversation.updated_at.desc())
    )

    conversations = []
    for row in result.all():
        conv = row[0]
        conv_dict = {
            "id": conv.id,
            "title": conv.title,
            "model_id": conv.model_id,
            "created_at": conv.created_at,
            "updated_at": conv.updated_at,
            "last_message_at": row[1] or conv.updated_at,
            "message_count": row[2] or 0,
        }
        conversations.append(conv_dict)

    return conversations


@router.post("/api/conversations", response_model=ConversationResponse)
async def create_conversation(
    req: CreateConversationRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    model_id = req.model_id or "deepseek-v4-pro"
    conversation = Conversation(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        title="新对话",
        model_id=model_id,
    )
    db.add(conversation)
    await db.flush()
    return conversation


@router.delete("/api/conversations/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import text
    from ..core.database import async_session

    # 先检查对话是否存在且属于当前用户
    result = await db.execute(
        select(Conversation).where(
            Conversation.id == conversation_id,
            Conversation.user_id == current_user.id,
        )
    )
    conversation = result.scalar_one_or_none()

    if not conversation:
        raise HTTPException(status_code=404, detail="对话不存在")

    try:
        # 使用独立的数据库 session 进行删除操作
        async with async_session() as delete_db:
            # 使用原生 SQL 按顺序删除所有关联数据
            # 1. 删除使用记录
            await delete_db.execute(
                text("DELETE FROM usage_records WHERE conversation_id = :cid"),
                {"cid": conversation_id}
            )

            # 2. 删除消息
            await delete_db.execute(
                text("DELETE FROM messages WHERE conversation_id = :cid"),
                {"cid": conversation_id}
            )

            # 3. 删除对话
            await delete_db.execute(
                text("DELETE FROM conversations WHERE id = :cid AND user_id = :uid"),
                {"cid": conversation_id, "uid": current_user.id}
            )

            # 4. 提交事务
            await delete_db.commit()

        # 从主 session 中移除对话对象
        db.expire(conversation)

        return {"message": "已删除"}
    except Exception as e:
        print(f"Delete error: {e}")
        raise HTTPException(status_code=500, detail=f"删除失败: {str(e)}")


@router.get("/api/chat/history/{conversation_id}", response_model=list[MessageResponse])
async def get_chat_history(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # 验证对话归属
    result = await db.execute(
        select(Conversation).where(
            Conversation.id == conversation_id,
            Conversation.user_id == current_user.id,
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="对话不存在")

    result = await db.execute(
        select(Message)
        .where(Message.conversation_id == conversation_id)
        .order_by(Message.created_at)
    )
    return result.scalars().all()


@router.post("/api/chat/send")
async def send_message(
    req: SendMessageRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # 验证对话归属
    result = await db.execute(
        select(Conversation).where(
            Conversation.id == req.conversation_id,
            Conversation.user_id == current_user.id,
        )
    )
    conversation = result.scalar_one_or_none()

    if not conversation:
        raise HTTPException(status_code=404, detail="对话不存在")

    # 保存用户消息
    user_message = Message(
        id=str(uuid.uuid4()),
        conversation_id=req.conversation_id,
        role="user",
        content=req.content,
        tokens_used=0,
    )
    db.add(user_message)
    await db.flush()  # 立即刷新到数据库

    # 获取历史消息（用于上下文）
    history_result = await db.execute(
        select(Message)
        .where(Message.conversation_id == req.conversation_id)
        .order_by(Message.created_at)
        .limit(20)
    )
    history = history_result.scalars().all()

    # 构建消息列表
    messages = [{"role": msg.role, "content": msg.content} for msg in history]

    # 更新对话标题（如果是第一条消息）
    if len(history) <= 1:
        conversation.title = req.content[:50] + ("..." if len(req.content) > 50 else "")

    model_id = req.model_id or conversation.model_id

    # 流式响应
    async def generate():
        from ..core.database import async_session

        chat_service = ChatService(db)
        full_content = ""
        full_reasoning = ""
        total_tokens = 0

        try:
            async for chunk in chat_service.stream_chat(messages, model_id):
                chunk_type = chunk.get("type")
                if chunk_type == "content":
                    full_content += chunk.get("content", "")
                elif chunk_type == "reasoning":
                    full_reasoning += chunk.get("content", "")
                total_tokens += chunk.get("tokens", 0)
                yield f"data: {json.dumps(chunk)}\n\n"

            # 流结束后使用独立会话保存消息
            final_content = full_content if full_content else full_reasoning

            if final_content:
                try:
                    async with async_session() as save_db:
                        # 保存助手消息
                        assistant_message = Message(
                            id=str(uuid.uuid4()),
                            conversation_id=req.conversation_id,
                            role="assistant",
                            content=final_content,
                            tokens_used=total_tokens,
                        )
                        save_db.add(assistant_message)

                        # 记录使用量
                        from ..services.usage_service import UsageService
                        usage_service = UsageService(save_db)
                        await usage_service.record_usage(
                            user_id=current_user.id,
                            conversation_id=req.conversation_id,
                            model_id=model_id,
                            tokens_input=total_tokens // 2,
                            tokens_output=total_tokens // 2,
                        )

                        await save_db.commit()
                        print(f"Saved assistant message: {len(final_content)} chars")
                except Exception as save_error:
                    print(f"Error saving message: {save_error}")

            yield "data: [DONE]\n\n"

        except Exception as e:
            print(f"Error in generate: {e}")
            yield f"data: {json.dumps({'error': str(e)})}\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        },
    )
