---
description: 處理綠界退款、取消授權、發票作廢/折讓
---

使用者需要處理退款或作廢。請依以下步驟引導：

1. 詢問使用者：要退什麼？（信用卡退款 / 發票作廢 / 發票折讓 / 物流退貨）
2. 根據類型讀取對應 guide 區段：
   - 信用卡退款（AIO）→ `guides/01-payment-aio.md` §DoAction（Action=R 退款 / N 取消授權）
   - 信用卡退款（ECPG）→ `guides/02-payment-ecpg.md` §DoAction
   - 發票作廢 → `guides/04-invoice-b2c.md` §Invalid（B2C）/ `guides/05-invoice-b2b.md` §Invalid（B2B）
   - 發票折讓 → `guides/04-invoice-b2c.md` §Allowance / `guides/05-invoice-b2b.md` §Allowance
   - 物流退貨 → `guides/06-logistics-domestic.md` §逆物流
3. 若涉及跨服務補償（退款 + 作廢發票 + 退貨），讀 `guides/11-cross-service-scenarios.md` §補償動作對照表
4. **生成程式碼前**，必須從 `references/` 對應檔案 web_fetch 最新規格
