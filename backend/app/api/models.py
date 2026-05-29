from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from ..core.database import get_db
from ..core.security import get_current_user
from ..models.user import User
from ..models.usage import ModelConfig

router = APIRouter(prefix="/api/models", tags=["模型"])


@router.get("")
async def get_models(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ModelConfig).where(ModelConfig.is_active == True)
    )
    models = result.scalars().all()

    return [
        {
            "id": m.id,
            "name": m.name,
            "provider": m.provider,
        }
        for m in models
    ]


@router.get("/{model_id}")
async def get_model(
    model_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ModelConfig).where(ModelConfig.id == model_id)
    )
    model = result.scalar_one_or_none()

    if not model:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="模型不存在")

    return {
        "id": model.id,
        "name": model.name,
        "provider": model.provider,
    }
