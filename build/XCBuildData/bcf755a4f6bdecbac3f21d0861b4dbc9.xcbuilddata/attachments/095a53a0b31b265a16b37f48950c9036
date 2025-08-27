#!/bin/sh
#!/bin/sh

# 确保 Xcode 脚本可以找到 Claude CLI 和 nvm 的 Node 路径
export PATH=$HOME/.nvm/versions/node/$(ls $HOME/.nvm/versions/node | tail -n 1)/bin:/opt/homebrew/bin:/usr/local/bin:$PATH

echo "🚀 Claude Code 自动提交启动..."

### 1. 检查 Claude CLI 是否安装
if ! command -v claude >/dev/null 2>&1; then
  osascript -e 'display dialog "⚠️ Claude CLI 未安装，请先执行 npm install -g claude-code" buttons {"OK"} with icon caution'
  exit 1
fi

### 2. 检查是否有改动
if [ -z "$(git status --porcelain)" ]; then
  osascript -e 'display notification "没有检测到改动，跳过提交" with title "ℹ️ Claude Code"'
  exit 0
fi

### 3. 自动添加所有改动
git add .

### 4. 确定分支策略
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" = "main" ]; then
  TARGET_BRANCH="main"
else
  # 如果不在 main，就用 feature-分支名（如果不存在则新建）
  TARGET_BRANCH="feature/${BRANCH}"
  git checkout -B "$TARGET_BRANCH"
fi

### 5. 自动 commit & push
if claude commit && claude push; then
  if [ "$TARGET_BRANCH" = "main" ]; then
    osascript -e 'display notification "Claude Code 已推送到 main 分支" with title "✅ Push Complete"'
  else
    # 自动打开 PR 页面（如果存在）
    PR_URL=$(gh pr view --json url --jq '.url' 2>/dev/null)
    if [ -n "$PR_URL" ]; then
      osascript -e "display dialog \"✅ Claude Code 已提交到 $TARGET_BRANCH，点击打开 PR\" buttons {\"打开 PR\"} default button 1"
      open "$PR_URL"
    else
      osascript -e 'display notification "Claude Code 已推送到 feature 分支，等待自动 PR" with title "✅ Push Complete"'
    fi
  fi
else
  echo "❌ Claude CLI 执行失败，查看日志：~/.claude/logs/latest.log"
  if [ -f "$HOME/.claude/logs/latest.log" ]; then
    LOG_CONTENT=$(tail -n 15 $HOME/.claude/logs/latest.log)
  else
    LOG_CONTENT="未找到 Claude 日志，请检查 Xcode Build Log"
  fi
  osascript -e "display dialog \"❌ Claude 提交失败：\n$LOG_CONTENT\" buttons {\"OK\"} with icon stop"
  exit 1
fi

