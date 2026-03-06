---
description: 查詢綠界訂單狀態、交易紀錄、對帳
---

使用者需要查詢訂單或對帳。請依以下步驟引導：

1. 詢問使用者：要查什麼？（單筆訂單狀態 / 批次對帳 / 發票查詢 / 物流查詢）
2. 根據類型讀取對應 guide 區段：
   - AIO 單筆查詢 → `guides/01-payment-aio.md` §QueryTradeInfo
   - ECPG 查詢 → `guides/02-payment-ecpg.md` §查詢
   - AIO 批次對帳 → `guides/01-payment-aio.md` §對帳（domain: vendor.ecpay.com.tw）
   - 發票查詢 → `guides/04-invoice-b2c.md` §查詢 / `guides/05-invoice-b2b.md` §查詢
   - 物流查詢 → `guides/06-logistics-domestic.md` §查詢 / `guides/07-logistics-allinone.md` §查詢
3. **生成程式碼前**，必須從 `references/` 對應檔案 web_fetch 最新規格
