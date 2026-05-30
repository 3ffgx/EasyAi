from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timedelta
from ..core.database import get_db
from ..core.security import get_current_user
from ..models.user import User
from ..models.usage import UsageRecord

router = APIRouter(prefix="/api/usage", tags=["使用量"])


@router.get("/stats")
async def get_usage_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.utcnow()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    # 总使用量
    total_result = await db.execute(
        select(
            func.coalesce(func.sum(UsageRecord.tokens_input), 0),
            func.coalesce(func.sum(UsageRecord.tokens_output), 0),
            func.coalesce(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output), 0),
            func.coalesce(func.sum(UsageRecord.cost), 0),
        ).where(UsageRecord.user_id == current_user.id)
    )
    total_input, total_output, total_tokens, total_cost = total_result.one()

    # 今日使用量
    today_result = await db.execute(
        select(
            func.coalesce(func.sum(UsageRecord.tokens_input), 0),
            func.coalesce(func.sum(UsageRecord.tokens_output), 0),
            func.coalesce(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output), 0),
            func.coalesce(func.sum(UsageRecord.cost), 0),
        ).where(
            UsageRecord.user_id == current_user.id,
            UsageRecord.created_at >= today_start,
        )
    )
    today_input, today_output, today_tokens, today_cost = today_result.one()

    # 本月使用量
    month_result = await db.execute(
        select(
            func.coalesce(func.sum(UsageRecord.tokens_input), 0),
            func.coalesce(func.sum(UsageRecord.tokens_output), 0),
            func.coalesce(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output), 0),
            func.coalesce(func.sum(UsageRecord.cost), 0),
        ).where(
            UsageRecord.user_id == current_user.id,
            UsageRecord.created_at >= month_start,
        )
    )
    month_input, month_output, month_tokens, month_cost = month_result.one()

    return {
        "total": {
            "tokens": int(total_tokens),
            "input": int(total_input),
            "output": int(total_output),
            "cost": float(total_cost),
        },
        "today": {
            "tokens": int(today_tokens),
            "input": int(today_input),
            "output": int(today_output),
            "cost": float(today_cost),
        },
        "month": {
            "tokens": int(month_tokens),
            "input": int(month_input),
            "output": int(month_output),
            "cost": float(month_cost),
        },
    }


@router.get("/records")
async def get_usage_records(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    model_id: str = Query(None),
    start_date: str = Query(None),
    end_date: str = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(UsageRecord).where(UsageRecord.user_id == current_user.id)

    if model_id:
        query = query.where(UsageRecord.model_id == model_id)
    if start_date:
        query = query.where(UsageRecord.created_at >= datetime.fromisoformat(start_date.replace("Z", "+00:00")))
    if end_date:
        query = query.where(UsageRecord.created_at <= datetime.fromisoformat(end_date.replace("Z", "+00:00")))

    # 总数
    count_result = await db.execute(
        select(func.count()).select_from(query.subquery())
    )
    total = count_result.scalar()

    # 分页
    result = await db.execute(
        query.order_by(UsageRecord.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    records = result.scalars().all()

    return {
        "items": [
            {
                "id": r.id,
                "model_id": r.model_id,
                "tokens_input": r.tokens_input,
                "tokens_output": r.tokens_output,
                "cost": float(r.cost),
                "created_at": r.created_at.isoformat(),
            }
            for r in records
        ],
        "total": total,
    }


@router.get("/balance")
async def get_balance(
    current_user: User = Depends(get_current_user),
):
    return {"balance": float(current_user.balance)}


@router.get("/daily")
async def get_daily_usage(
    days: int = Query(7, ge=1, le=30),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取每日 token 使用量统计（用于图表）"""
    # 使用本地时间
    now = datetime.now()
    start_date = now - timedelta(days=days)
    start_date = start_date.replace(hour=0, minute=0, second=0, microsecond=0)

    result = await db.execute(
        select(
            func.date(UsageRecord.created_at).label("date"),
            func.coalesce(func.sum(UsageRecord.tokens_input), 0).label("input"),
            func.coalesce(func.sum(UsageRecord.tokens_output), 0).label("output"),
            func.coalesce(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output), 0).label("total"),
        )
        .where(
            UsageRecord.user_id == current_user.id,
            UsageRecord.created_at >= start_date,
        )
        .group_by(func.date(UsageRecord.created_at))
        .order_by(func.date(UsageRecord.created_at))
    )

    daily_data = {}
    for row in result.all():
        date_str = str(row[0])
        daily_data[date_str] = {
            "input": int(row[1]),
            "output": int(row[2]),
            "total": int(row[3]),
        }

    # 填充缺失的日期（包含今天）
    dates = []
    inputs = []
    outputs = []
    totals = []

    for i in range(days + 1):
        date = (start_date + timedelta(days=i)).strftime("%Y-%m-%d")
        dates.append(date)
        data = daily_data.get(date, {"input": 0, "output": 0, "total": 0})
        inputs.append(data["input"])
        outputs.append(data["output"])
        totals.append(data["total"])

    return {
        "dates": dates,
        "input": inputs,
        "output": outputs,
        "total": totals,
    }


@router.get("/model-stats")
async def get_model_usage_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """获取各模型使用量统计"""
    result = await db.execute(
        select(
            UsageRecord.model_id,
            func.coalesce(func.sum(UsageRecord.tokens_input), 0).label("input"),
            func.coalesce(func.sum(UsageRecord.tokens_output), 0).label("output"),
            func.coalesce(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output), 0).label("total"),
            func.count(UsageRecord.id).label("count"),
        )
        .where(UsageRecord.user_id == current_user.id)
        .group_by(UsageRecord.model_id)
        .order_by(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output).desc())
    )

    models = []
    for row in result.all():
        models.append({
            "model_id": row[0],
            "input": int(row[1]),
            "output": int(row[2]),
            "total": int(row[3]),
            "count": int(row[4]),
        })

    return {"models": models}
