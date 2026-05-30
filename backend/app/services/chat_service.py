import httpx
import json
from typing import AsyncGenerator, List, Dict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from ..models.usage import ModelConfig


class ChatService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def stream_chat(
        self, messages: List[Dict], model_id: str
    ) -> AsyncGenerator[Dict, None]:
        # 从数据库获取模型配置
        result = await self.db.execute(
            select(ModelConfig).where(ModelConfig.id == model_id, ModelConfig.is_active == True)
        )
        model_config = result.scalar_one_or_none()

        if not model_config:
            yield {"error": f"模型 {model_id} 不存在或未启用"}
            return

        if not model_config.api_key:
            yield {"error": f"模型 {model_id} 未配置 API Key"}
            return

        # 根据提供商选择适配器
        if model_config.provider == "deepseek":
            async for chunk in self._stream_deepseek(model_config, messages):
                yield chunk
        elif model_config.provider == "openai":
            async for chunk in self._stream_openai(model_config, messages):
                yield chunk
        else:
            yield {"error": f"不支持的提供商: {model_config.provider}"}

    async def _stream_deepseek(
        self, model_config: ModelConfig, messages: List[Dict]
    ) -> AsyncGenerator[Dict, None]:
        tokens_input = 0
        tokens_output = 0

        async with httpx.AsyncClient() as client:
            async with client.stream(
                "POST",
                f"{model_config.api_base}/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {model_config.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model_config.id,
                    "messages": messages,
                    "stream": True,
                    "max_tokens": 4096,
                },
                timeout=120,
            ) as response:
                async for line in response.aiter_lines():
                    if line.startswith("data: "):
                        data = line[6:]
                        if data == "[DONE]":
                            yield {"type": "done", "tokens_input": tokens_input, "tokens_output": tokens_output}
                            break

                        try:
                            chunk = json.loads(data)
                            # 提取 usage 信息
                            if "usage" in chunk:
                                usage = chunk["usage"]
                                tokens_input = usage.get("prompt_tokens", 0)
                                tokens_output = usage.get("completion_tokens", 0)

                            if "choices" in chunk and len(chunk["choices"]) > 0:
                                delta = chunk["choices"][0].get("delta", {})
                                content = delta.get("content")
                                reasoning = delta.get("reasoning_content")

                                # 思考过程
                                if reasoning:
                                    yield {"type": "reasoning", "content": reasoning}
                                # 最终回答
                                elif content:
                                    yield {"type": "content", "content": content}
                        except json.JSONDecodeError:
                            continue

    async def _stream_openai(
        self, model_config: ModelConfig, messages: List[Dict]
    ) -> AsyncGenerator[Dict, None]:
        # TODO: 实现 OpenAI 适配器
        yield {"error": "OpenAI 适配器暂未实现"}
