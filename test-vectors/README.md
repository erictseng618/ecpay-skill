# ECPay 測試向量

本目錄提供 CheckMacValue 和 AES 加密的測試向量，可用於自動化測試和 CI 驗證。

完整說明與各語言實作見：
- CheckMacValue: [guides/13-checkmacvalue.md](../guides/13-checkmacvalue.md) §測試向量
- AES 加密: [guides/14-aes-encryption.md](../guides/14-aes-encryption.md) §測試向量

## UTF-8 與非 ASCII 字元測試

ECPay AES 加密支援 UTF-8 中文內容（如 `ItemName` 含中文）。在實作時請注意：
- JSON 序列化時確保使用 UTF-8 編碼，勿使用 ASCII 逸出（如 Python 需設定 `ensure_ascii=False`）
- URL encode 後的 `%XX` 百分比編碼大小寫需符合各語言規格（詳見 guides/14 各語言說明）
- 可用 guides/14 測試帳號（`ejCk326UnaZWKisg` / `q9jcZX8Ib9LM8wYk`）自行構建中文測試向量驗證實作
