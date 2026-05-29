from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timedelta
from ..core.database import get_db
from ..core.security import get_current_admin
from ..models.user import User
from ..models.conversation import Conversation
from ..models.message import Message
from ..models.usage import UsageRecord, BillingRecord, ModelConfig, TierConfig, SystemConfig, Announcement
from ..schemas.admin import (
    UpdateUserRequest,
    ModelConfigRequest,
    TierConfigRequest,
    AnnouncementRequest,
    GlobalConfigRequest,
)

router = APIRouter(prefix="/api/admin", tags=["管理后台"])


# ========== 用户管理 ==========

@router.get("/users")
async def get_users(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    keyword: str = Query(None),
    role: str = Query(None),
    is_active: bool = Query(None),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    query = select(User)

    if keyword:
        query = query.where(
            (User.email.contains(keyword)) | (User.nickname.contains(keyword))
        )
    if role:
        query = query.where(User.role == role)
    if is_active is not None:
        query = query.where(User.is_active == is_active)

    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()

    result = await db.execute(
        query.order_by(User.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    users = result.scalars().all()

    return {
        "items": [
            {
                "id": u.id,
                "email": u.email,
                "nickname": u.nickname,
                "role": u.role,
                "tier_id": u.tier_id,
                "balance": float(u.balance),
                "is_active": u.is_active,
                "created_at": u.created_at.isoformat(),
            }
            for u in users
        ],
        "total": total,
    }


@router.put("/users/{user_id}")
async def update_user(
    user_id: str,
    req: UpdateUserRequest,
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    if req.nickname is not None:
        user.nickname = req.nickname
    if req.role is not None:
        user.role = req.role
    if req.tier_id is not None:
        user.tier_id = req.tier_id
    if req.is_active is not None:
        user.is_active = req.is_active

    return {"message": "已更新"}


@router.get("/users/{user_id}/stats")
async def get_user_stats(
    user_id: str,
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.utcnow()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    total_result = await db.execute(
        select(
            func.coalesce(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output), 0),
            func.coalesce(func.sum(UsageRecord.cost), 0),
        ).where(UsageRecord.user_id == user_id)
    )
    total_tokens, total_cost = total_result.one()

    today_result = await db.execute(
        select(
            func.coalesce(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output), 0),
        ).where(
            UsageRecord.user_id == user_id,
            UsageRecord.created_at >= today_start,
        )
    )
    today_tokens = today_result.scalar()

    month_result = await db.execute(
        select(
            func.coalesce(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output), 0),
        ).where(
            UsageRecord.user_id == user_id,
            UsageRecord.created_at >= month_start,
        )
    )
    month_tokens = month_result.scalar()

    return {
        "total_tokens": int(total_tokens),
        "total_cost": float(total_cost),
        "today_tokens": int(today_tokens),
        "month_tokens": int(month_tokens),
    }


# ========== 模型管理 ==========

@router.get("/models")
async def get_models(
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(ModelConfig))
    return result.scalars().all()


@router.post("/models")
async def create_model(
    req: ModelConfigRequest,
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    # 检查模型 ID 是否已存在
    existing = await db.execute(select(ModelConfig).where(ModelConfig.id == req.id))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="模型 ID 已存在")

    model = ModelConfig(
        id=req.id,
        name=req.name,
        provider=req.provider,
        api_base=req.api_base,
        api_key=req.api_key,
        is_active=False,  # 默认不启用，需要测试通过后手动启用
    )
    db.add(model)
    return {"message": "模型已添加，请先配置 API Key 并测试通过后再启用"}


@router.put("/models/{model_id}")
async def update_model(
    model_id: str,
    req: ModelConfigRequest,
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(ModelConfig).where(ModelConfig.id == model_id))
    model = result.scalar_one_or_none()

    if not model:
        raise HTTPException(status_code=404, detail="模型不存在")

    if req.name is not None:
        model.name = req.name
    if req.provider is not None:
        model.provider = req.provider
    if req.api_base is not None:
        model.api_base = req.api_base
    # 只有当 api_key 不为空且不是 masked 格式时才更新
    if req.api_key is not None and req.api_key.strip() != '' and '****' not in req.api_key:
        model.api_key = req.api_key
    if req.is_active is not None:
        model.is_active = req.is_active

    return {"message": "已更新"}


@router.delete("/models/{model_id}")
async def delete_model(
    model_id: str,
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(ModelConfig).where(ModelConfig.id == model_id))
    model = result.scalar_one_or_none()

    if not model:
        raise HTTPException(status_code=404, detail="模型不存在")

    await db.delete(model)
    return {"message": "已删除"}


@router.post("/models/{model_id}/test")
async def test_model(
    model_id: str,
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    import httpx
    import time

    result = await db.execute(select(ModelConfig).where(ModelConfig.id == model_id))
    model = result.scalar_one_or_none()

    if not model:
        raise HTTPException(status_code=404, detail="模型不存在")

    if not model.api_key or model.api_key.strip() == '':
        raise HTTPException(status_code=400, detail="未配置 API Key，请先填写 API Key 再测试")

    # 发送测试请求验证 API Key
    try:
        start_time = time.time()
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                f"{model.api_base}/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {model.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model.id,
                    "messages": [{"role": "user", "content": "你好，请回复一个字"}],
                    "max_tokens": 10,
                },
            )

            elapsed = round(time.time() - start_time, 2)

            # 解析响应
            try:
                response_data = response.json()
            except:
                response_data = {}

            if response.status_code == 200:
                # 检查响应是否包含有效数据
                if "choices" in response_data and len(response_data["choices"]) > 0:
                    message = response_data["choices"][0].get("message", {})
                    content = message.get("content", "")
                    reasoning = message.get("reasoning_content", "")

                    # 检查是否有任何有效响应
                    if content or reasoning:
                        # 测试通过，更新验证状态
                        model.is_verified = True
                        model.last_test_at = datetime.utcnow()
                        display_content = content or reasoning
                        return {"message": f"测试通过！模型响应: {display_content[:50]}... (耗时 {elapsed}s)"}
                    else:
                        raise HTTPException(status_code=400, detail="测试失败：模型返回空内容")
                else:
                    raise HTTPException(status_code=400, detail="测试失败：响应格式异常")
            elif response.status_code == 401:
                error_msg = response_data.get("error", {}).get("message", "API Key 无效")
                raise HTTPException(status_code=400, detail=f"API Key 无效: {error_msg}")
            elif response.status_code == 429:
                raise HTTPException(status_code=400, detail="API Key 额度不足或请求过于频繁")
            else:
                error_msg = response_data.get("error", {}).get("message", "未知错误")
                raise HTTPException(status_code=400, detail=f"测试失败: {error_msg}")

    except httpx.TimeoutException:
        raise HTTPException(status_code=400, detail="连接超时，请检查 API 地址是否正确")
    except httpx.ConnectError:
        raise HTTPException(status_code=400, detail="无法连接到 API 服务器，请检查网络")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"测试失败: {str(e)}")


# ========== 套餐管理 ==========

@router.get("/tiers")
async def get_tiers(
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(TierConfig))
    return result.scalars().all()


@router.post("/tiers")
async def create_tier(
    req: TierConfigRequest,
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    tier = TierConfig(
        id=req.id,
        name=req.name,
        monthly_price=req.monthly_price,
        free_quota=req.free_quota,
        overage_rate=req.overage_rate,
        is_active=req.is_active,
    )
    db.add(tier)
    return {"message": "套餐已添加"}


@router.put("/tiers/{tier_id}")
async def update_tier(
    tier_id: str,
    req: TierConfigRequest,
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(TierConfig).where(TierConfig.id == tier_id))
    tier = result.scalar_one_or_none()

    if not tier:
        raise HTTPException(status_code=404, detail="套餐不存在")

    tier.name = req.name
    tier.monthly_price = req.monthly_price
    tier.free_quota = req.free_quota
    tier.overage_rate = req.overage_rate
    tier.is_active = req.is_active

    return {"message": "已更新"}


@router.delete("/tiers/{tier_id}")
async def delete_tier(
    tier_id: str,
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(TierConfig).where(TierConfig.id == tier_id))
    tier = result.scalar_one_or_none()

    if not tier:
        raise HTTPException(status_code=404, detail="套餐不存在")

    await db.delete(tier)
    return {"message": "已删除"}


# ========== 统计 ==========

@router.get("/statistics")
async def get_statistics(
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.utcnow()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    # 总用户数
    total_users = (await db.execute(select(func.count(User.id)))).scalar()

    # 总对话数
    total_conversations = (await db.execute(select(func.count(Conversation.id)))).scalar()

    # 总 Token
    total_tokens = (await db.execute(
        select(func.coalesce(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output), 0))
    )).scalar()

    # 总收入
    total_revenue = (await db.execute(
        select(func.coalesce(func.sum(BillingRecord.amount), 0)).where(BillingRecord.type == "topup")
    )).scalar()

    # 今日新增用户
    today_users = (await db.execute(
        select(func.count(User.id)).where(User.created_at >= today_start)
    )).scalar()

    # 今日对话数
    today_conversations = (await db.execute(
        select(func.count(Conversation.id)).where(Conversation.created_at >= today_start)
    )).scalar()

    # 今日 Token
    today_tokens = (await db.execute(
        select(func.coalesce(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output), 0))
        .where(UsageRecord.created_at >= today_start)
    )).scalar()

    # 今日收入
    today_revenue = (await db.execute(
        select(func.coalesce(func.sum(BillingRecord.amount), 0))
        .where(BillingRecord.type == "topup", BillingRecord.created_at >= today_start)
    )).scalar()

    return {
        "total_users": total_users,
        "total_conversations": total_conversations,
        "total_tokens": int(total_tokens),
        "total_revenue": float(total_revenue),
        "today_users": today_users,
        "today_conversations": today_conversations,
        "today_tokens": int(today_tokens),
        "today_revenue": float(today_revenue),
    }


@router.get("/statistics/model-ranking")
async def get_model_ranking(
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(
            UsageRecord.model_id,
            func.count(UsageRecord.id).label("usage_count"),
            func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output).label("total_tokens"),
            func.sum(UsageRecord.cost).label("total_cost"),
        )
        .group_by(UsageRecord.model_id)
        .order_by(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output).desc())
        .limit(10)
    )

    return [
        {
            "model_id": row[0],
            "usage_count": row[1],
            "total_tokens": int(row[2] or 0),
            "total_cost": float(row[3] or 0),
        }
        for row in result.all()
    ]


@router.get("/statistics/active-users")
async def get_active_users(
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(
            User.email,
            User.nickname,
            func.count(Conversation.id).label("conversation_count"),
            func.max(Conversation.updated_at).label("last_active"),
        )
        .join(Conversation, Conversation.user_id == User.id)
        .group_by(User.id)
        .order_by(func.max(Conversation.updated_at).desc())
        .limit(10)
    )

    return [
        {
            "email": row[0],
            "nickname": row[1],
            "conversation_count": row[2],
            "last_active": row[3].isoformat() if row[3] else None,
        }
        for row in result.all()
    ]


# ========== 财务 ==========

@router.get("/finance/month-stats")
async def get_month_finance_stats(
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.utcnow()
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    revenue = (await db.execute(
        select(func.coalesce(func.sum(BillingRecord.amount), 0))
        .where(BillingRecord.type == "topup", BillingRecord.created_at >= month_start)
    )).scalar()

    cost = (await db.execute(
        select(func.coalesce(func.sum(UsageRecord.cost), 0))
        .where(UsageRecord.created_at >= month_start)
    )).scalar()

    return {
        "revenue": float(revenue),
        "cost": float(cost),
    }


@router.get("/finance/records")
async def get_finance_records(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    type: str = Query(None),
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    query = select(BillingRecord)

    if type:
        query = query.where(BillingRecord.type == type)

    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()

    result = await db.execute(
        query.order_by(BillingRecord.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    records = result.scalars().all()

    # 获取用户邮箱
    items = []
    for r in records:
        user_result = await db.execute(select(User.email).where(User.id == r.user_id))
        email = user_result.scalar() or "未知"
        items.append({
            "id": r.id,
            "user_email": email,
            "type": r.type,
            "amount": float(r.amount),
            "description": r.description,
            "created_at": r.created_at.isoformat(),
        })

    return {"items": items, "total": total}


# ========== 系统配置 ==========

@router.get("/config")
async def get_global_config(
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(SystemConfig))
    configs = {c.key: c.value for c in result.scalars().all()}

    return {
        "max_context_turns": int(configs.get("max_context_turns", "20")),
        "max_tokens_per_message": int(configs.get("max_tokens_per_message", "4096")),
        "daily_free_tokens": int(configs.get("daily_free_tokens", "10000")),
    }


@router.put("/config")
async def update_global_config(
    req: GlobalConfigRequest,
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    for key, value in req.model_dump(exclude_none=True).items():
        result = await db.execute(select(SystemConfig).where(SystemConfig.key == key))
        config = result.scalar_one_or_none()

        if config:
            config.value = str(value)
        else:
            db.add(SystemConfig(key=key, value=str(value)))

    return {"message": "配置已保存"}


# ========== 公告 ==========

@router.post("/announcements")
async def create_announcement(
    req: AnnouncementRequest,
    admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    announcement = Announcement(
        title=req.title,
        content=req.content,
        type=req.type,
    )
    db.add(announcement)
    return {"message": "公告已发布"}
