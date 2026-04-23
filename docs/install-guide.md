# 安裝指南（共學團團員版）

這份 skill 會每天早上在 Discord 上給你一份「今天你的 OpenClaw 又長大了什麼」的摘要。你按 ✅ 之後，它才會被貼到你自己的 Notion。

## 先決條件

- ✅ 你已經裝好 OpenClaw，`openclaw doctor` 過關
- ✅ Discord 機器人綁在一個你可以收訊息的頻道
- ✅ 你的 OpenClaw 已安裝 **`notion-api` skill**（本 skill 所有 Notion 寫入都委派給它）
- ✅ 你有一個 Notion workspace，已加入龍蝦補完計畫
- ✅ `rsync`、`git`、`jq` 三個工具在 PATH 中（macOS 預設就有）

## 五步安裝

### 1. 確認 skill 在本機

```bash
ls ~/.openclaw/skills/daily-growth-report/
# 應該看到 SKILL.md / skill.json / config.example.json / scripts/ / docs/
```

如果沒有，從共學團提供的 repo clone 或 `cp` 到這個位置。

### 2. 確認你有共學團「學習分享」database 的權限

**不用自己建** — 共學團共用一個 database，你只要確認你的 Notion 帳號已經加入龍蝦補完計畫的 workspace，能看到：

```
龍蝦補完計畫！/ 原始資料庫 / 資料庫存放點 / 學習分享
Database ID: 34a3785a098a807fab03f43f07d784c6
```

`database_id`、`data_source_id`、`category_option`（= `自我進化`）**都已經預填在 `config.example.json`，你完全不用動**。

> 不需要設定 person ID — DB 的「建立者」欄是 created_by 系統欄，Notion 會自動填寫入者，per-member attribution 自動處理。

### 3. 選一個 Discord 頻道當審核頻道

這個頻道最好是**私人的**（只有你自己看得到），因為草稿還沒核可。把 channel ID 記下來。

### 4. 填 config.json

```bash
cd ~/.openclaw/skills/daily-growth-report
cp config.example.json config.json
```

編輯 `config.json`，只需要動兩個欄位：
- `discord.review_channel_id` → 你的私人頻道 ID
- `agent_id` → 預設 `atlach-nacha`；如果你 OpenClaw 沒這個 agent，改成任一個你常用的 agent ID

`user_name` **留空就好** — 第一次執行 cron 時會自動從 `workspace/USER.md` 的「What to call them」抓出你的名字寫回 config，之後草稿會以你的名字為主體（第三人稱）方便在共學團 Notion 裡辨識。想自己指定也可以直接填。

其餘欄位都已預填好，不用動。

### 5. 第一次跑、確認 snapshot 沒問題

```bash
bash ~/.openclaw/skills/daily-growth-report/scripts/run-once.sh
```

看到「snapshot done」＋ diff 輸出就 OK。
Snapshot 會存在 `~/.openclaw/workspace/self-evolution/snapshots/`，是一個獨立的 shadow git repo，不會污染你原本的 `.openclaw`。

### 6. 註冊 cron

打開 `docs/cron-jobs.json`，把兩個 job（04:30 snapshot、08:00 Discord post）加進你的 `~/.openclaw/cron/jobs.json`：

```bash
# 備份現有 jobs.json（一定要做）
cp ~/.openclaw/cron/jobs.json ~/.openclaw/cron/jobs.json.bak-before-daily-growth

# 用 openclaw CLI 或手動編輯
# 手動：把 docs/cron-jobs.json 裡的兩個 job 物件複製進 .jobs 陣列
# 記得：
#   - 替換 <UUID-...> 為真實 UUID（uuidgen 產生）
#   - 替換 agentId 為你的 agent（預設 atlach-nacha）
#   - 替換 <REVIEW_CHANNEL_ID> 為你的 Discord 頻道 ID
#   - 先保持 enabled: false 跑一次 test
```

### 7. 測試

```bash
# 手動觸發 04:30 那條看看
openclaw cron run <job-id>

# 檢查有沒有寫出草稿
cat ~/.openclaw/workspace/self-evolution/drafts/$(date +%Y-%m-%d).md
```

草稿看起來 OK 後，把兩條 cron 的 `enabled` 改成 `true`，重啟 gateway。

## 日常使用

- **08:00** — Discord 會收到一則「🐚 今天你的 OpenClaw 又長大了什麼？」訊息
- **看完覺得 OK** — 按 ✅，幾秒後 Notion 會多一筆
- **覺得不 OK** — 什麼都不按，不會發 Notion；草稿留在 `drafts/` 裡，想手動補發也行

## 常見問題

**Q: snapshot 會不會越來越大？**
A: 會，但很慢。只追蹤文字檔，每天的 diff 通常幾 KB。半年大概幾 MB。如果擔心，半年後跑一次 `git gc --aggressive` 在 snapshot repo 就好。

**Q: 我不想每天收，想兩三天一次可以嗎？**
A: 把 04:30 和 08:00 兩條 cron 的排程都改成 `* */2 * *` 或類似。這個 skill 不偵測「昨天」，而是「上一次 snapshot commit」，所以間隔隨你。

**Q: 我怎麼知道它捕捉到的範圍對不對？**
A: 編輯 `config.json` 的 `tracked_paths`。新增/刪除任何 glob 都可以，重跑 snapshot 就會重新 rsync。

**Q: 在共學團分享報告可以嗎？**
A: 可以，Notion database 的 share 權限自己決定。但**審核用的 Discord 頻道請保持私人**，草稿階段不要給別人看。
