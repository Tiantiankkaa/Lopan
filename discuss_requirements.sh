#!/usr/bin/env bash
# discuss_requirements.sh
# 依赖：yq, claude

REQ_FILE="$1"
if [ -z "$REQ_FILE" ] || [ ! -f "$REQ_FILE" ]; then
  echo "Usage: $0 path/to/requirements.txt"
  exit 1
fi
REQ=$(<"$REQ_FILE")
echo "🗒️ 原始需求:"; echo "$REQ"; echo

# 从 agents.yaml 里提取 prompt
PM_PROMPT=$(yq e '.agents.project_manager.prompt' .claude/agents.yaml)
SE_PROMPT=$(yq e '.agents.senior_engineer.prompt' .claude/agents.yaml)
SA_PROMPT=$(yq e '.agents.security_auditor.prompt' .claude/agents.yaml)
SUM_PROMPT=$(yq e '.agents.summarizer.prompt' .claude/agents.yaml)

echo "1️⃣ [Project Manager] 需求拆解:"
claude run --model claude-3.5-sonnet --prompt "$PM_PROMPT" --input "$REQ"
echo; echo

echo "2️⃣ [Senior Engineer] 架构 & 性能评审:"
claude run --model claude-3.5-sonnet --prompt "$SE_PROMPT" --input "$REQ"
echo; echo

echo "3️⃣ [Security Auditor] 安全审计:"
claude run --model claude-3.5-sonnet --prompt "$SA_PROMPT" --input "$REQ"
echo; echo

echo "4️⃣ [Summarizer] 需求讨论汇总:"
# 合并前三步的输出供 summarizer 使用
DISCUSS=$(printf "需求拆解:\n%s\n\n架构评审:\n%s\n\n安全审计:\n%s\n" \
  "$(claude run --model claude-3.5-sonnet --prompt "$PM_PROMPT" --input "$REQ")" \
  "$(claude run --model claude-3.5-sonnet --prompt "$SE_PROMPT" --input "$REQ")" \
  "$(claude run --model claude-3.5-sonnet --prompt "$SA_PROMPT" --input "$REQ")")
claude run --model claude-3.5-haiku --prompt "$SUM_PROMPT" --input "$DISCUSS"
