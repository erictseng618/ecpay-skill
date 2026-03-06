---
description: 設定綠界 Callback / Webhook 回應處理
---

使用者需要處理綠界的 Callback 或 Webhook。請依以下步驟引導：

1. 詢問使用者：哪個服務的 Callback？（金流 / 發票 / 物流）
2. 讀取 `guides/22-webhook-events-reference.md`（各服務 callback 回應格式彙總）
3. 根據服務類型確認回應格式：
   - AIO 金流 → 收到後回應 `1|OK`（純文字）
   - ECPG 站內付 → 回應 JSON `{ "TransCode": 1 }`
   - 全方位/跨境物流 v2 → 回應 AES 加密 JSON（三層結構）
   - 國內物流 → 回應 `1|OK`
4. 若 Callback 收不到，參考 `guides/15-troubleshooting.md` §2 排查
5. **生成程式碼前**，必須從 `references/` 對應檔案 web_fetch 最新規格確認 callback 欄位
