# Notion Database Schema

> **單一事實來源（Canonical source）**：`~/.openclaw/workspace/skills/notion-api/references/database-registry.md` 第 7 筆「學習分享」。
>
> 本 skill 不重複維護 schema。有欄位或 data_source_id 變動，**只改 registry**，這裡不動。

## 快速摘要

- **Database**：龍蝦補完計畫 / 原始資料庫 / 資料庫存放點 / 學習分享
- **共用**：是（跨共學團成員）
- **本 skill 固定類別**：`自我進化`
- **安裝時要填的**：無（`database_id`、`data_source_id`、`category_option` 都預設在 `config.example.json`）

欄位清單、ID、寫入守則（去重、option 不存在怎麼辦）全部看 registry。

## 為什麼共用而不是每個人各自建？

2026-04-21 的設計 session 定調是「讓大家參考」。共用 database 的好處：

- 大家看得到彼此的 OpenClaw 長怎樣
- 一目了然誰最近在玩什麼、有什麼可以偷學
- 做週報 / 月報只要篩選 `類別 = 自我進化` 就好

隱私層面：

- Discord 審核頻道是**私人的**（只有自己看），沒 ✅ 就不會進 Notion
- 貼到 Notion 前使用者自己一定看過
- 每則只有摘要，不包含原始 diff 或 session 內容

## Per-member attribution

DB 裡的「建立者」是 `created_by` 系統欄，Notion 自動填寫入者。每個共學團成員用自己的 MCP 寫入，就自動有個人識別，不需要手動設定 person id。
