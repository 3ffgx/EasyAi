# EasyAi - AI 聊天平台

一个支持多模型的 AI 聊天 Web 应用。

## 功能特性

- 多模型支持（DeepSeek、OpenAI、Claude 等）
- 流式对话（实时显示回复）
- Markdown + LaTeX 公式渲染
- 用户注册登录
- 使用量统计
- 管理后台

## 技术栈

| 部分 | 技术 |
|------|------|
| 前端 | Vue 3 + Vite + Element Plus |
| 后端 | FastAPI + SQLAlchemy |
| 数据库 | PostgreSQL |
| 部署 | Docker + Nginx |

## 快速开始

### 1. 克隆项目

```bash
git clone git@github.com:3ffgx/EasyAi.git
cd EasyAi
```

### 2. 启动后端

```bash
cd backend

# 创建虚拟环境
python -m venv venv
venv\Scripts\activate  # Windows
# source venv/bin/activate  # Mac/Linux

# 安装依赖
pip install -r requirements.txt

# 配置环境变量
cp ../.env.example ../.env
# 编辑 .env 文件，填入你的 API Key

# 启动
uvicorn app.main:app --reload --port 8000
```

### 3. 启动前端

```bash
cd frontend

# 安装依赖
npm install

# 启动
npm run dev
```

### 4. 访问

- 前端：http://localhost:5173
- 后端文档：http://localhost:8000/docs

## 默认账号

管理员账号需要手动创建：

```bash
# 注册账号后，在数据库中将 role 改为 admin
```

## 项目结构

```
EasyAi/
├── backend/          # 后端代码
│   ├── app/
│   │   ├── api/      # API 接口
│   │   ├── core/     # 核心配置
│   │   ├── models/   # 数据模型
│   │   └── services/ # 业务逻辑
│   └── requirements.txt
├── frontend/         # 前端代码
│   ├── src/
│   │   ├── views/    # 页面
│   │   ├── stores/   # 状态管理
│   │   └── api/      # 请求封装
│   └── package.json
├── docker-compose.yml
└── .env.example
```

## 开发指南

### 后端开发

- API 路由：`backend/app/api/`
- 数据模型：`backend/app/models/`
- 业务逻辑：`backend/app/services/`

### 前端开发

- 页面：`frontend/src/views/`
- 组件：`frontend/src/components/`
- 状态：`frontend/src/stores/`

### 数据库迁移

```bash
cd backend
alembic revision --autogenerate -m "描述"
alembic upgrade head
```

## 部署

使用 Docker Compose：

```bash
docker-compose up -d
```

## 常见问题

**Q: 数据库连接失败？**
A: 检查 PostgreSQL 是否启动，`.env` 中的数据库配置是否正确。

**Q: API Key 无效？**
A: 在管理后台配置有效的 API Key 并测试通过。

**Q: 前端启动报错？**
A: 删除 `node_modules` 重新 `npm install`。

## 联系方式

- 作者：3ffgx
- QQ：1405936435
- GitHub：https://github.com/3ffgx/EasyAi
