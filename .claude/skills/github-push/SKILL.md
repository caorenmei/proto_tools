---
name: github-push
description: >
  推送到远程仓库并完成 PR 合并的完整工作流。
  当用户提到"推送"、"push"、"提交到远程"、"创建 PR"、"merge PR"、
  "发布代码"、"提 PR"、"推代码"、"同步到远程"时，务必使用此 skill。
  即使用户没有明确说"PR"，只要涉及将本地代码推送到远程仓库，都应该使用此 skill。
  此 skill 处理 main 分支无 push 权限的场景，自动创建 feature 分支、
  提交更改、push 到远程、用 gh 创建 PR、监视 PR 状态、
  PR 合并后同步本地并清理分支。
compatibility: gh CLI, git
---

# GitHub Push & PR Merge 工作流

用于将本地代码推送到远程仓库，通过 PR 方式合并到 main 分支，
并同步到本地的完整自动化流程。

## 前置条件

- 已安装 `gh` CLI 工具并已认证
- 当前目录在 git 仓库中
- 远程仓库已配置

## 代理配置

`gh` 命令在遇到网络问题时，通过代理重试。

- 读取环境变量 `GH_PROXY`，默认值为 `http://127.0.0.1:1080`
- 执行 gh 命令前，设置 `HTTPS_PROXY` 和 `HTTP_PROXY`

## 工作流程

### 步骤 1：检查当前分支

运行 `git branch --show-current` 获取当前分支名。

- **如果在 main 分支**：
  1. 确保本地 main 是最新的：`git pull origin main`
  2. 创建 feature 分支：`git checkout -b feat/auto-$(date +%s)`
  3. 继续后续步骤

- **如果已在 feature 分支**：直接继续

### 步骤 2：提交未提交的更改

运行 `git status --short` 检查是否有未提交的更改。

- 如果有，自动提交：
  ```bash
  git add -A
  git commit -m "feat: auto commit before push"
  ```

### 步骤 3：Push 到远程

```bash
git push -u origin $(git branch --show-current)
```

如果 push 失败，先执行 `git pull origin $(git branch --show-current) --rebase`，然后重试。

### 步骤 4：创建 PR

先检查是否已有活跃的 PR：

```bash
gh pr view --json state,number,url
```

- 如果返回结果且 `state` 为 `"OPEN"`，记录 PR URL，跳到步骤 5
- 如果没有活跃的 PR，创建新的 PR：

```bash
gh pr create --fill
```

`--fill` 会自动使用提交消息作为 PR 标题和描述。

**代理处理**：如果 gh 命令因网络问题失败，设置代理后重试：

```bash
export HTTPS_PROXY=${GH_PROXY:-http://127.0.0.1:1080}
export HTTP_PROXY=${GH_PROXY:-http://127.0.0.1:1080}
gh pr create --fill
```

记录创建成功的 PR URL。

### 步骤 5：监视 PR 状态

轮询 PR 状态，直到 PR 被合并。

```bash
gh pr view --json state,mergeStateStatus,checks
```

**轮询策略**：
- 间隔 30 秒查询一次
- 如果 `state` 变为 `"MERGED"`，跳到步骤 6
- 如果 `state` 变为 `"CLOSED"`，报错并停止
- 如果 `checks` 中有失败的检查，向用户报告失败项，询问是否继续等待
- 最长等待时间：30 分钟（超过则提示用户手动继续）

**代理处理**：如果 gh 命令因网络问题失败，设置代理后重试。

### 步骤 6：同步本地并清理分支

PR 合并成功后：

1. 切换回 main 分支：
   ```bash
   git checkout main
   ```

2. 拉取最新代码：
   ```bash
   git pull origin main
   ```

3. 删除本地 feature 分支：
   ```bash
   git branch -d <feature-branch-name>
   ```

4. 向用户汇报完成：
   - PR 已合并的链接
   - 本地 main 已同步到最新
   - feature 分支已删除

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| gh 未安装或未认证 | 提示用户安装并运行 `gh auth login` |
| 当前不在 git 仓库 | 报错并停止 |
| push 失败（非快进） | 自动 rebase 后重试 |
| PR 创建失败 | 设置代理重试，仍失败则报错 |
| PR 被关闭 | 报错并停止，不执行清理 |
| 网络超时 | 设置代理重试，最多 3 次 |
| main 分支有本地更改 | 先 stash，创建 feature 分支后恢复 |

## 示例

**用户**：把刚才的改动推上去

**执行**：
1. 检查当前分支 → 在 main
2. 创建 feature 分支 `feat/auto-1717300000`
3. 提交未提交的更改
4. push 到远程
5. `gh pr create --fill` 创建 PR
6. 轮询等待 PR 被合并
7. 合并后切回 main、pull、删除 feature 分支

**用户**：push 一下这个分支

**执行**：
1. 检查当前分支 → 已在 feature/login-fix
2. push 到远程
3. 检查 PR → 已有 OPEN 状态的 PR #42
4. 轮询等待 PR 被合并
5. 合并后切回 main、pull、删除 feature/login-fix
