---
description: 串接綠界金流收款（AIO / ECPG 站內付 / 幕後授權）
---

使用者需要串接綠界金流。請依以下步驟引導：

1. 先讀取 `SKILL.md` 的金流決策樹，確認適合的方案（AIO / ECPG / 幕後授權）
2. 詢問使用者：使用什麼語言/框架？需要哪些付款方式？
3. 根據方案讀取對應 guide：
   - AIO → `guides/01-payment-aio.md`
   - ECPG 站內付 → `guides/02-payment-ecpg.md`
   - 幕後授權 → `guides/03-payment-backend.md`
4. **生成程式碼前**，必須從 `references/Payment/` 對應檔案 web_fetch 最新 API 規格
5. 加密實作參考 `guides/13-checkmacvalue.md`（CMV）或 `guides/14-aes-encryption.md`（AES）
