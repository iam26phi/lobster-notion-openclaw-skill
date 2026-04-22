#!/usr/bin/env bash
# daily-growth-report :: publish-notion.sh
# Assembles the Notion-publish prompt for a given date's draft and prints it to stdout.
# This script does NOT call the Notion API — that job belongs to an agent turn
# using the notion-api skill's tools (see docs/approval-flow.md).
#
# Usage:
#   publish-notion.sh                    # today
#   publish-notion.sh 2026-04-20         # backfill a specific date
#
# The output is meant to be fed to the agent (paste into Discord / CLI).
set -euo pipefail

OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
SKILL_DIR="$OPENCLAW_HOME/skills/daily-growth-report"
EVO_DIR="$OPENCLAW_HOME/workspace/self-evolution"
DRAFTS="$EVO_DIR/drafts"
CONFIG="${DAILY_GROWTH_CONFIG:-$SKILL_DIR/config.json}"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: config not found at $CONFIG" >&2
  exit 2
fi

TZ_CONFIG="$(jq -r '.timezone // "Asia/Tokyo"' "$CONFIG")"
TARGET_DATE="${1:-$(TZ="$TZ_CONFIG" date +%Y-%m-%d)}"
DRAFT="$DRAFTS/${TARGET_DATE}.md"

if [[ ! -f "$DRAFT" ]]; then
  echo "ERROR: draft not found for ${TARGET_DATE} at $DRAFT" >&2
  echo "Hint: run snapshot.sh then have the agent generate a draft first." >&2
  exit 2
fi

CATEGORY="$(jq -r '.notion.category_option // "自我進化"' "$CONFIG")"

cat <<EOF
# 發布指令（給納克亞）

你剛剛收到使用者對 ${TARGET_DATE} 的成長報告的 ✅ 核可（或手動補發請求）。

前置條件：此機器必須已安裝 notion-api skill。若未安裝請停止並回報。

步驟：
1. 讀 ~/.openclaw/workspace/skills/notion-api/SKILL.md 與
   references/database-registry.md（**第 7 筆「學習分享」**），
   依其 conventions 用 Notion MCP tools（例如 notion-create-pages）寫入。

2. 讀草稿：$DRAFT

3. **（必做）** 先查同 分享日期=${TARGET_DATE} + 類別=$CATEGORY + 建立者=self 是否已存在。
   共學團共用 DB，這步不能省：
   - 已存在 → notion-update-page 覆蓋（見步驟 5）
   - 不存在 → notion-create-pages 新增（見步驟 4）

4. **新增** 時的 properties：
   - 標題: "OpenClaw 成長日記 ${TARGET_DATE}｜<使用者名字>"
   - 分享日期: ${TARGET_DATE}
   - 學習內容: 草稿完整內文（>2000 字請依 notion-api 慣例拆 paragraph block）
   - 類別: "$CATEGORY"（select；若此 option 不存在請停止，不要自動建立）
   - **不要寫「建立者」**：那是 created_by 系統欄，Notion 會自動填成實際寫入者

   新增時 page body 也要鋪一份（同等重要）：
   - 把草稿 markdown 原文鋪在 Notion page 內文（heading / paragraph / bullet block），
     方便共學團成員直接在 Notion 閱讀。

5. **更新** 時（步驟 3 判定已存在同日紀錄）：
   - 覆蓋「學習內容」property
   - 清空現有 page body block，再把新草稿 markdown 鋪回去（避免堆疊舊版）

6. 成功後：
   - mv $DRAFT ${EVO_DIR}/published/${TARGET_DATE}.md
   - 回覆一句：「已發布到 Notion。連結：<PAGE_URL>」

EOF
