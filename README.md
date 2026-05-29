# EasyAi - AI 聊天 SaaS 平台

一个前后端分离的 AI 聊天平台，支持多种 AI 模型，用户管理和使用量统计。

## 技术栈

### 前端
- Vue 3 + Vite
- Element Plus UI
- Pinia 状态管理
- Vue Router

### 后端
- FastAPI
- SQLAlchemy + Alembic
- PostgreSQL
- Redis

### 部署
- Docker + Docker Compose
- Nginx 反向代理

## 功能特性

### 用户端
- 用户注册/登录
- 多模型对话（DeepSeek、OpenAI、Anthropic）
- 流式响应（SSE）
- 对话历史管理
- 使用量统计
- 余额查询
- 日志终端 + 一键反馈

### 管理后台
- 用户管理（列表/详情/封禁/套餐变更）
- 模型管理（配置/测试/启用/禁用）
- 财务中心（收入统计/充值记录/导出）
- 使用量监控（实时仪表盘/趋势图）
- 系统配置（套餐定价/公告/全局参数）

## 快速开始

### 1. 环境准备

```bash
# 克隆项目
git clone <your-repo-url>
cd EasyAi

# 复制环境变量配置
cp .env.example .env

# 编辑 .env 文件，填入你的 API Key
```

### 2. Docker 部署（推荐）

```bash
# 启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f
```

访问 http://localhost 即可使用。

### 3. 本地开发

#### 后端

```bash
cd backend

# 创建虚拟环境
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt

# 启动开发服务器
uvicorn app.main:app --reload --port 8000
```

访问 http://localhost:8000/docs 查看 API 文档。

#### 前端

```bash
cd frontend

# 安装依赖
npm install

# 启动开发服务器
npm run dev
```

访问 http://localhost:5173 即可使用。

## 项目结构

```
EasyAi/
├── frontend/              # Vue 3 前端
│   ├── src/
│   │   ├── api/          # API 请求
│   │   ├── components/   # 组件
│   │   ├── layouts/      # 布局
│   │   ├── router/       # 路由
│   │   ├── stores/       # 状态管理
│   │   └── views/        # 页面
│   └── package.json
│
├── backend/               # FastAPI 后端
│   ├── app/
│   │   ├── api/          # API 路由
│   │   ├── core/         # 核心配置
│   │   ├── models/       # 数据模型
│   │   ├── schemas/      # Pydantic Schema
│   │   └── services/     # 业务逻辑
│   └── requirements.txt
│
├── docker-compose.yml     # Docker 编排
├── nginx.conf             # Nginx 配置
└── .env.example           # 环境变量模板
```

## API 接口

### 认证
- `POST /api/auth/register` - 注册
- `POST /api/auth/login` - 登录
- `POST /api/auth/refresh` - 刷新 Token
- `GET /api/auth/me` - 获取当前用户

### 聊天
- `GET /api/conversations` - 对话列表
- `POST /api/conversations` - 创建对话
- `DELETE /api/conversations/:id` - 删除对话
- `POST /api/chat/send` - 发送消息（SSE）
- `GET /api/chat/history/:id` - 对话历史

### 使用量
- `GET /api/usage/stats` - 使用统计
- `GET /api/usage/records` - 使用记录
- `GET /api/usage/balance` - 余额

### 管理后台
- `GET /api/admin/users` - 用户列表
- `PUT /api/admin/users/:id` - 更新用户
- `GET /api/admin/models` - 模型列表
- `POST /api/admin/models` - 添加模型
- `GET /api/admin/statistics` - 系统统计

## 配置说明

### 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| DATABASE_URL | 数据库连接 | postgresql+asyncpg://... |
| REDIS_URL | Redis 连接 | redis://localhost:6379/0 |
| SECRET_KEY | JWT 密钥 | 需要修改 |
| DEEPSEEK_API_KEY | DeepSeek API Key | - |

### 默认账号

首次运行时，系统会自动创建管理员账号：
- 邮箱：admin@easyai.com
- 密码：admin123

**请在生产环境中立即修改密码！**

## 部署到生产环境

### 1. 修改环境变量

```bash
# 生成随机密钥
openssl rand -hex 32

# 编辑 .env
SECRET_KEY=<生成的密钥>
DEEPSEEK_API_KEY=<你的API Key>
```

### 2. 配置 SSL 证书

```bash
# 创建证书目录
mkdir certs

# 将证书文件放入 certs 目录
# - cert.pem
# - key.pem
```

### 3. 修改 Nginx 配置

编辑 `nginx.conf`，添加 SSL 配置：

```nginx
server {
    listen 443 ssl;
    ssl_certificate /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/key.pem;
    ...
}
```

### 4. 启动服务

```bash
docker-compose up -d
```

## 开发说明

### 添加新模型

1. 在 `backend/app/services/chat_service.py` 添加新的 Adapter
2. 在管理后台添加模型配置
3. 测试模型连接

### 自定义套餐

在管理后台的"系统配置"中可以：
- 添加/编辑套餐
- 设置月费、免费额度、超出单价
- 启用/禁用套餐

## 常见问题

### Q: 如何重置管理员密码？

```bash
# 进入后端容器
docker exec -it easyai-backend bash

# 运行 Python 脚本
python -c "
from app.core.security import get_password_hash
print(get_password_hash('new-password'))
"
```

然后在数据库中更新密码。

### Q: 如何备份数据库？

```bash
docker exec easyai-postgres pg_dump -U postgres easyai > backup.sql
```

### Q: 如何查看日志？

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f backend
```

## 许可证

MIT License
