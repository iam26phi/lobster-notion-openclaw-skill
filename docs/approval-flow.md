# 審核流程（Discord ✅ → Notion）

08:00 納克亞把草稿貼到 Discord 之後，**不會**主動發 Notion。使用者要按 ✅ emoji 才會觸發 Notion publish。

## 三種實作方式（由 v1 → v3）

### v1（最簡單，手動 fallback — **目前實作**）

沒有 hook，使用者按 ✅ 之後在 Discord 聊天框輸入：

```
publish today
```

或補發舊的：`publish 2026-04-20`。

納克亞收到之後，依據「發布到 Notion 的 agent prompt 範本」執行。你也可以手動跑
`scripts/publish-notion.sh [YYYY-MM-DD]` 把組好的 prompt 印出來，貼給納克亞。

**注意**：`publish-notion.sh` 只是 prompt assembler，**不呼叫 Notion API**。實際寫入是納克亞用 notion-api skill 的 tools 完成。

### v2（reaction 觸發，Discord gateway）— **未實作，v1 跑穩後再評估**

這段是設計草稿，目前沒有實際的 hook 基礎設施，不要依賴。

構想：如果 OpenClaw Discord gateway 未來支援 `message_reaction_add` event，就可以綁：

```
當事件 = message_reaction_add
  且 emoji = "✅"
  且 channel_id = <REVIEW_CHANNEL_ID>
  且 message_id 在 drafts/<today>.messageid 之中
→ 喚起 agent turn，帶著 publish-notion.sh 產生的 prompt
```

匹配 message_id 的具體實作方式（gateway plugin? agent reaction handler?）待 v1 穩定後再設計，目前不做。

### v3（更聰明：edit-in-place）— **未實作**

使用者在 Discord 上直接編輯草稿訊息，編完按 ✅，納克亞 publish 編輯後的版本而非原草稿。需要監聽 `message_update` + `message_reaction_add`，留作長期想法。

## 發布到 Notion 的 agent prompt 範本

> **設計原則**：本 skill 不直接寫 Notion API 細節，Notion 寫入由 `notion-api` skill 負責。
> 「學習分享」database 的 schema、data_source_id、寫入守則都登記在
> `~/.openclaw/workspace/skills/notion-api/references/database-registry.md` 第 7 節。
> 本 skill 只提供「寫什麼」、不規定「怎麼寫 API」。

```
你是阿特拉克・納克亞。使用者剛剛在 Discord 上 ✅ 核可了今天的成長報告。

前置條件：此機器必須已安裝 notion-api skill。若未安裝，回覆錯誤並停止。

步驟：
1. 讀 ~/.openclaw/skills/daily-growth-report/config.json 拿 field_map 與 category_option
2. 讀 ~/.openclaw/workspace/self-evolution/drafts/<TODAY>.md
3. **（必做）** 先請 notion-api skill query 同 `分享日期=<TODAY> + 類別=自我進化 + 建立者=self` 是否已存在。
   - 已存在 → 走 update-page 覆蓋（見步驟 5）
   - 不存在 → 走 create-page（見步驟 4）
   共學團共用 DB，這一步不能省。per-member 區分靠 `建立者` (created_by) 系統欄自動處理。

4. 委派給 notion-api skill 在「學習分享」（registry 第 7 筆）**新增一筆**紀錄（若步驟 3 判定要新增）：
   properties：
   - 標題: "OpenClaw 成長日記 <TODAY>｜<使用者名字>"
   - 分享日期: <TODAY>
   - 學習內容: 草稿完整內文（>2000 字依 notion-api 拆 paragraph block）
   - 類別: "自我進化"（固定；select option 不存在請停止，不要自動建立）
   - **不要寫「建立者」**：Notion 會自動填寫入者
   page body（同等重要，人類會在頁面直接讀）：
   - 把同一份草稿以 markdown 形式鋪在 page body
   實際用哪個 MCP 工具、請求格式、重試策略由 notion-api skill 決定。

5. 委派給 notion-api skill **更新**（若步驟 3 判定已存在）：
   - 覆蓋「學習內容」property
   - 清空該 page 現有 body block，再把新草稿 markdown 鋪回去（避免堆疊）

6. 把 drafts/<TODAY>.md 搬到 published/<TODAY>.md

7. 回覆一句：「已發布到 Notion。連結：<PAGE_URL>」
```

### 為什麼要這樣委派

- **避免功能重複**：Notion auth、error handling、rate limit 都寫一次就好
- **schema 集中管理**：「學習分享」欄位改了，只改 registry，這邊不用動
- **跨 skill 一致**：未來共學團有別的 skill 寫同一張表時，走相同路徑

## 超時處理

- 若 24 小時內沒人按 ✅，草稿留在 `drafts/`
- 隔天 08:00 會覆蓋該日期的 messageid（但不會覆蓋草稿）
- 想補發舊的？執行：`bash scripts/publish-notion.sh 2026-04-20`
