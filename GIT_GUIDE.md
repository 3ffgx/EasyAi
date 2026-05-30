# Git 使用指南

## 基础配置

```bash
# 设置用户信息
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"

# 查看配置
git config --list
```

---

## 场景一：日常开发

### 1. 获取最新代码

```bash
# 拉取远程最新代码
git pull origin main

# 或者先 fetch 再 merge
git fetch origin
git merge origin/main
```

### 2. 查看当前状态

```bash
# 查看修改了哪些文件
git status

# 查看具体修改内容
git diff

# 查看某个文件的修改
git diff 文件路径
```

### 3. 提交代码

```bash
# 添加指定文件
git add 文件1 文件2

# 添加所有修改
git add .

# 提交
git commit -m "描述你做了什么修改"

# 推送到远程
git push origin main
```

---

## 场景二：功能开发（推荐）

### 1. 创建功能分支

```bash
# 从 main 分支创建新分支
git checkout main
git pull
git checkout -b feature/功能名称

# 例如
git checkout -b feature/latex-render
git checkout -b feature/user-profile
```

### 2. 在分支上开发

```bash
# 正常开发、提交
git add .
git commit -m "feat: 添加xxx功能"

# 多次提交都可以
git add .
git commit -m "fix: 修复xxx问题"
```

### 3. 推送分支到远程

```bash
git push origin feature/功能名称
```

### 4. 合并到 main

```bash
# 方式一：在 GitHub 上创建 Pull Request（推荐）
# 方式二：本地合并
git checkout main
git pull
git merge feature/功能名称
git push origin main

# 删除功能分支
git branch -d feature/功能名称
git push origin --delete feature/功能名称
```

---

## 场景三：修复 Bug

### 1. 创建修复分支

```bash
git checkout main
git pull
git checkout -b fix/bug描述
```

### 2. 修复并提交

```bash
git add .
git commit -m "fix: 修复xxx问题"
```

### 3. 合并

```bash
git checkout main
git pull
git merge fix/bug描述
git push origin main
```

---

## 场景四：撤销操作

### 1. 撤销未提交的修改

```bash
# 撤销某个文件的修改
git checkout -- 文件路径

# 撤销所有修改
git checkout -- .
```

### 2. 撤销已 add 的文件

```bash
# 撤销单个文件
git reset HEAD 文件路径

# 撤销所有
git reset HEAD
```

### 3. 撤销已 commit 的提交

```bash
# 撤销最近一次 commit，保留修改
git reset --soft HEAD~1

# 撤销最近一次 commit，不保留修改
git reset --hard HEAD~1
```

### 4. 撤销已 push 的提交

```bash
# 强制推送（慎用！会覆盖远程历史）
git reset --hard HEAD~1
git push --force origin main
```

---

## 场景五：查看历史

```bash
# 查看提交历史
git log

# 简洁模式
git log --oneline

# 图形化显示分支
git log --graph --oneline --all

# 查看某个文件的历史
git log --follow 文件路径

# 查看某次提交的详细内容
git show 提交ID
```

---

## 场景六：分支管理

```bash
# 查看所有分支
git branch -a

# 查看本地分支
git branch

# 切换分支
git checkout 分支名

# 创建并切换新分支
git checkout -b 新分支名

# 删除本地分支
git branch -d 分支名

# 删除远程分支
git push origin --delete 分支名
```

---

## 场景七：暂存工作区

```bash
# 当前工作做到一半，需要切换分支
git stash

# 切换分支做其他事
git checkout 其他分支

# 回来后恢复
git checkout 原分支
git stash pop

# 查看暂存列表
git stash list

# 恢复指定暂存
git stash apply stash@{0}
```

---

## 场景八：解决冲突

### 1. 合并时出现冲突

```bash
# 尝试合并
git merge feature/xxx

# 如果有冲突，编辑冲突文件
# 冲突标记：
# <<<<<<< HEAD
# 当前分支的内容
# =======
# 合并分支的内容
# >>>>>>> feature/xxx
```

### 2. 解决冲突

```bash
# 编辑文件，保留需要的内容，删除冲突标记

# 标记冲突已解决
git add 冲突文件

# 完成合并
git commit -m "merge: 合并xxx分支"
```

---

## 场景九：多人协作

### 1. 协作流程

```bash
# 1. 开始工作前，先拉取最新代码
git checkout main
git pull

# 2. 创建自己的功能分支
git checkout -b feature/我的功能

# 3. 开发并提交
git add .
git commit -m "feat: 我的功能"

# 4. 推送到远程
git push origin feature/我的功能

# 5. 在 GitHub 创建 Pull Request

# 6. 代码审查后合并
```

### 2. 保持分支同步

```bash
# 将 main 的最新代码合并到你的分支
git checkout feature/我的功能
git merge main

# 或者使用 rebase（更整洁的历史）
git checkout feature/我的功能
git rebase main
```

---

## 场景十：版本回退

```bash
# 查看版本历史
git log --oneline

# 回退到指定版本
git reset --hard 提交ID

# 回退后强制推送
git push --force origin main
```

---

## 常用命令速查

| 场景 | 命令 |
|------|------|
| 查看状态 | `git status` |
| 查看修改 | `git diff` |
| 添加文件 | `git add 文件` |
| 提交 | `git commit -m "说明"` |
| 推送 | `git push origin 分支` |
| 拉取 | `git pull origin 分支` |
| 创建分支 | `git checkout -b 分支名` |
| 切换分支 | `git checkout 分支名` |
| 查看分支 | `git branch -a` |
| 合并分支 | `git merge 分支名` |
| 查看历史 | `git log --oneline` |
| 暂存工作 | `git stash` |
| 恢复暂存 | `git stash pop` |

---

## 提交规范

```
feat: 新功能
fix: 修复 bug
docs: 文档更新
style: 代码格式（不影响功能）
refactor: 重构
test: 测试相关
chore: 构建/工具相关
```

示例：
```bash
git commit -m "feat: 添加用户注册功能"
git commit -m "fix: 修复登录失败问题"
git commit -m "docs: 更新 README"
```
