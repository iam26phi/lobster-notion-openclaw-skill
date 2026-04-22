# daily-growth-report

讓每個裝了 OpenClaw 的成員，每天都能收到一份「**我的 OpenClaw 今天又自我進化了什麼？**」的人話摘要。

面向「龍蝦補完計畫」共學團團員設計，但任何 OpenClaw 使用者都可以安裝。

## 核心概念

OpenClaw 的目錄（agents、workspace、skills、cron、設定）天天在被人、被 agent、被排程任務修改。這個 skill 每天把這些變化收束成一段讓你看得懂的話：

> 「今天你新增了一個 `japanese-coach` agent，改了兩條 cron 設定，skills 資料夾裡多了 `felo-search`。昨天睡前貼進去的 Notion 頁面也被整理了。」

流程：
1. **04:30 Tokyo** — snapshot + 用 LLM 寫草稿（純後台）
2. **08:00 Tokyo** — 把草稿貼到使用者指定的 Discord 頻道
3. **✅ react** — 使用者在 Discord 上按 ✅，才會轉發到 Notion
4. **無反應** — 不發 Notion；草稿留在本地等使用者手動補核

## 觸發方式

- **自動**：兩條 cron（見 `docs/cron-jobs.json`）
- **手動測試**：`~/.openclaw/skills/daily-growth-report/scripts/run-once.sh`

## 追蹤範圍

由 `config.json` 的 `tracked_paths` 決定。預設：

| 路徑 | 追蹤什麼 |
|---|---|
| `agents/*/AGENTS.md`, `agents/*/SOUL.md`, `agents/*/IDENTITY.md` | agent 身份與職責變化 |
| `workspace/` | 工作區設定、memo、progress log |
| `cron/jobs.json` | 排程任務新增、移除、調整 |
| `openclaw.json` | 核心設定 |
| `skills/**/SKILL.md`, `skills/**/skill.json` | skill 清單與版本 |
| `extensions/` 清單 | npm 插件 |
| `vendor/*` 的 `git HEAD` | 自製插件版本 |

**排除**：
- `agents/*/sessions/`（會話紀錄，體積大且天天變）
- `lcm.db*`、`credentials/`、`secrets/`、`.env*`（敏感）
- `logs/`、`tmp/`、`trash/`、`backups/`、`*.bak`

## 偵測機制

在 `workspace/self-evolution/snapshots/` 建一個 **shadow git repo**：
- 每天 04:30 把追蹤範圍 rsync 進去
- 自動 `git add -A && git commit -m "snapshot YYYY-MM-DD"`
- 拿 `git diff HEAD~1 HEAD --stat` 和 `git log -p --since=yesterday` 餵給 LLM

這樣做的好處：
- 完整歷史可追溯
- 免自己寫 diff 邏輯
- 共學團成員裝上去第一天自動初始化

## 輸出

- **草稿檔**：`workspace/self-evolution/drafts/YYYY-MM-DD.md`
- **Discord**：08:00 推送到 `config.json` 指定頻道（私人審核用）
- **Notion**：Discord ✅ react 後轉發到**共學團共用**「學習分享」database，類別 = `自我進化`

## 語氣

- 300 字摘要 + 條列 3–5 則重點
- 台灣繁體中文
- 講「你今天做了 X」而非「系統偵測到變更 X」
- 不列出每個檔案、不貼 diff

## 安裝需要提供

- Discord channel ID（審核用，請設為**私人頻道**）
- （不用設定 person ID；DB 的「建立者」欄是 created_by，Notion 自動填寫入者）
- Agent 名稱（預設 `atlach-nacha`；共學團成員可改成自己的 agent）
- **先決 skill**：`notion-api`（此 skill 不直接呼叫 notion MCP，所有寫入都委派給它）

**Notion database 不用自己建** — 共學團成員共用「學習分享」database（已登記為 `notion-api` skill 的 registry 第 7 筆）。所有人的每日成長報告都會進到同一個地方，類別固定為 `自我進化`。

## 模組化設計（委派給 notion-api）

本 skill 只做三件事：**偵測變化 → 寫草稿 → 送審核**。Notion 實際寫入、schema、去重、API 錯誤處理，統統由 `notion-api` skill 負責：

- `docs/approval-flow.md` 的 publish prompt 只告訴 agent「寫什麼」，不寫「怎麼呼叫 API」
- 「學習分享」的 data_source_id / 欄位 / 寫入守則集中登記在
  `~/.openclaw/workspace/skills/notion-api/references/database-registry.md` 第 7 筆
- 「學習分享」schema 變動 → 只改 registry，這個 skill 不動

詳見 `docs/install-guide.md`。

## 不做的事

- 不碰 `sessions/`、`lcm.db`、credentials
- 不會主動發到 Notion 除非 Discord ✅
- 不跨機器同步（每個人只看自己機器的變化）
- 不追蹤實際對話內容
