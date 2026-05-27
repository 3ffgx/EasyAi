# EasyAi DeepSeek V4 Pro

面向新手的 Claude Code + DeepSeek V4 Pro 可视化安装器。

## 当前设计原则

不要让用户为了安装 Claude Code 被迫安装 Python、Node.js、Git。

当前推荐入口是：

```text
启动EasyAi.vbs
```

这个入口不会弹出黑色命令行窗口，会直接打开中文可视化界面。

备用入口是：

```text
EasyAi-DeepSeek.bat
```

它会打开同一个 WPF 可视化界面，不需要用户提前安装 Python。

## 三种使用方式

启动界面会先弹出“使用前须知”，提醒用户：

- Claude Code 是 Anthropic 官方工具，首次启动时可能要求登录或完成官方认证。
- DeepSeek API Key 只负责模型调用，不是 Claude 账号。
- 本工具不能绕过 Claude Code 的官方账号、认证或地区限制。
- 地区不可用、官方下载异常、无法测试、连接测试失败等紧急问题会弹窗提示，不只写日志。

1. 只安装 Claude Code

   适合只想安装 Claude Code、不想配置 DeepSeek 的用户。

2. 安装 Claude Code + 配置 DeepSeek V4 Pro

   适合新手的一键模式。程序会安装 Claude Code，并写入 DeepSeek 环境变量。

3. 只配置 DeepSeek

   适合电脑上已经有 Claude Code 的用户。

## 为什么不默认安装 Node.js 和 Git

Claude Code 官方现在推荐使用原生安装器：

```powershell
irm https://claude.ai/install.ps1 | iex
```

Windows 也可以通过 WinGet 安装：

```powershell
winget install Anthropic.ClaudeCode
```

所以普通用户不需要先理解 Node.js、npm、Python 或 Git。

Git 只是代码协作工具，Claude Code 可以在没有 Git 的目录里使用。  
Node.js/npm 只是高级安装方式，不应该作为小白默认流程。

## DeepSeek 配置

页面里统一使用 `Base URL` 写法，避免用户在 DeepSeek 或 Claude Code 文档里找不到对应字段。

程序默认写入：

```powershell
ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
ANTHROPIC_AUTH_TOKEN=你的 DeepSeek API Key
ANTHROPIC_MODEL=deepseek-v4-pro
ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro
ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-pro
ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-pro
CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-pro
CLAUDE_CODE_EFFORT_LEVEL=think
```

默认还会额外写入：

```powershell
ANTHROPIC_API_KEY=你的 DeepSeek API Key
DEEPSEEK_API_KEY=你的 DeepSeek API Key
```

Windows 环境变量写入后，需要新打开 PowerShell、CMD 或终端窗口才会生效。

## Key 校验

测试连接会先直接请求 DeepSeek Anthropic API：

```text
POST https://api.deepseek.com/anthropic/v1/messages
```

只有 DeepSeek API Key 真实通过后，才继续测试本机 Claude Code。瞎填 Key 应该失败并弹窗。

## 页面结构

- 模块 1｜安装前检测：显示 Claude Code、DeepSeek 配置和官方下载状态。
- 模块 2｜DeepSeek 配置：填写 Base URL、API Key 和模型。
- 模块 3｜执行操作：安装、配置或测试。
- 模块 4｜运行日志：按检测、校验、安装、写入、测试分段输出详细日志。

## 开发文件说明

- `EasyAi-DeepSeek.bat`：备用启动入口，不依赖 Python
- `启动EasyAi.vbs`：推荐启动入口，不显示命令行黑框
- `EasyAi-DeepSeek.ps1`：PowerShell WPF 可视化安装器，底部全宽日志区用于查看安装过程

## 后续建议

正式分发时建议做成真正的 `EasyAi.exe`：

- 首选：C# / .NET WinUI 或 WPF
- 备选：Tauri
- 当前 PowerShell WPF 版适合验证流程和用户体验

服务器可以放在第二阶段做：

- 版本更新
- 公告
- 模型配置下发
- 用户 Token 与额度管理
- 多国产模型协议转换
