# daily-growth-report

OpenClaw skill 讓每個裝了 OpenClaw 的使用者，每天早上收到一份「**我的 OpenClaw 今天又自我進化了什麼？**」的人話摘要 —— 按 ✅ 核可後才會貼到共用 Notion。

面向「龍蝦補完計畫」共學團設計，但任何 OpenClaw 使用者都可以安裝。

## 每日流程

```
04:30 Tokyo  snapshot 所有 agent / skill / cron / 設定 → 寫草稿
08:00 Tokyo  草稿貼到指定 Discord 頻道（私人）
  ↓ 使用者按 ✅
  publish    轉發到共用 Notion「學習分享」DB，類別 = 自我進化
```

沒按 ✅ 就不發 Notion。草稿留在 `workspace/self-evolution/drafts/` 等手動補核。

## 先決條件

- OpenClaw 已安裝，`openclaw doctor` 過關
- 同一台機器上已安裝 **`notion-api` skill**（本 skill 所有 Notion 寫入都委派給它）
- Discord 機器人綁在一個你可以收訊息的私人頻道
- 你的 Notion 帳號已加入龍蝦補完計畫 workspace
- `rsync` / `git` / `jq` 在 PATH 中（macOS 預設就有）

## 安裝

見 [`docs/install-guide.md`](docs/install-guide.md)。

## 設計文件

- [`SKILL.md`](SKILL.md) — 核心概念、追蹤範圍、偵測機制
- [`docs/approval-flow.md`](docs/approval-flow.md) — Discord ✅ → Notion 審核流程
- [`docs/notion-schema.md`](docs/notion-schema.md) — 指向 notion-api registry 的 schema source
- [`docs/cron-jobs.json`](docs/cron-jobs.json) — cron 任務範本

## 模組化設計

本 skill 只做三件事：**偵測變化 → 寫草稿 → 送審核**。Notion 寫入、schema、去重、API 錯誤處理由 [`notion-api` skill](https://github.com/) 負責，避免重複實作。

## License

[MIT](LICENSE)
