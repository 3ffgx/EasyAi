import uuid
from decimal import Decimal
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from ..models.usage import UsageRecord, BillingRecord
from ..models.user import User


class UsageService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def record_usage(
        self,
        user_id: str,
        conversation_id: str,
        model_id: str,
        tokens_input: int,
        tokens_output: int,
    ):
        # 计算费用（简化版，实际应根据模型配置计算）
        cost = self._calculate_cost(model_id, tokens_input, tokens_output)

        # 记录使用量
        record = UsageRecord(
            id=str(uuid.uuid4()),
            user_id=user_id,
            conversation_id=conversation_id,
            model_id=model_id,
            tokens_input=tokens_input,
            tokens_output=tokens_output,
            cost=cost,
        )
        self.db.add(record)

        # 扣除余额
        await self._deduct_balance(user_id, cost)

        return record

    def _calculate_cost(
        self, model_id: str, tokens_input: int, tokens_output: int
    ) -> Decimal:
        # 简化版定价，实际应从数据库读取
        rates = {
            "deepseek-v4-pro": {"input": 0.0001, "output": 0.0002},
            "deepseek-chat": {"input": 0.0001, "output": 0.0002},
            "deepseek-reasoner": {"input": 0.0005, "output": 0.001},
        }

        rate = rates.get(model_id, {"input": 0.0001, "output": 0.0002})
        cost = (tokens_input * rate["input"] + tokens_output * rate["output"]) / 1000

        return Decimal(str(round(cost, 6)))

    async def _deduct_balance(self, user_id: str, cost: Decimal):
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()

        if user:
            user.balance = user.balance - cost

            # 记录消费
            billing = BillingRecord(
                id=str(uuid.uuid4()),
                user_id=user_id,
                amount=cost,
                type="usage",
                description="API 调用消费",
            )
            self.db.add(billing)

    async def get_user_stats(self, user_id: str):
        from sqlalchemy import func
        from datetime import datetime

        now = datetime.utcnow()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

        # 总使用量
        total_result = await self.db.execute(
            select(
                func.coalesce(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output), 0),
                func.coalesce(func.sum(UsageRecord.cost), 0),
            ).where(UsageRecord.user_id == user_id)
        )
        total_tokens, total_cost = total_result.one()

        # 今日使用量
        today_result = await self.db.execute(
            select(
                func.coalesce(func.sum(UsageRecord.tokens_input + UsageRecord.tokens_output), 0),
            ).where(
                UsageRecord.user_id == user_id,
                UsageRecord.created_at >= today_start,
            )
        )
        today_tokens = today_result.scalar()

        # 本月使用量
        month_result = await self.db.execute(
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
