---
description: 生成綠界 CheckMacValue 加密驗證程式碼（SHA256 / MD5）
---

使用者需要 CheckMacValue 加密驗證的實作。請依以下步驟引導：

1. 詢問使用者：使用什麼程式語言？用途是 AIO 金流（SHA256）還是國內物流（MD5）？
2. 讀取 `guides/13-checkmacvalue.md`（包含 12 語言實作 + 測試向量）
   - 使用 AI Section Index 跳到目標語言的行範圍
3. 提供對應語言的 CheckMacValue 實作，包含：
   - 參數排序（case-insensitive）
   - URL encode（綠界自訂規則，見 guides/13 §ecpayUrlEncode）
   - Hash 計算（SHA256 或 MD5）
4. 用 guides/13 中的測試向量驗證實作正確性
