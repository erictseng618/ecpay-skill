# ECPay 測試向量

本目錄提供 CheckMacValue 和 AES 加密的測試向量，可用於自動化測試和 CI 驗證。

完整說明與各語言實作見：
- CheckMacValue: [guides/13-checkmacvalue.md](../guides/13-checkmacvalue.md) §測試向量
- AES 加密: [guides/14-aes-encryption.md](../guides/14-aes-encryption.md) §測試向量

## 向量清單

### CheckMacValue (5 vectors)

| # | 名稱 | 重點驗證 |
|---|------|---------|
| 1 | SHA256 基本測試 | 標準 AIO 金流流程 |
| 2 | MD5 測試 | 國內物流 |
| 3 | 特殊字元 `'` | Node.js/TypeScript 的 encodeURIComponent 不編碼 `'` |
| 4 | 特殊字元 `~` | 各語言 `~` → `%7E` 替換 |
| 5 | **空格處理** | `%20` vs `+` 陷阱（Node.js、Rust 預設產生 `%20`） |

### AES 加密 (4 vectors)

| # | 名稱 | 重點驗證 |
|---|------|---------|
| 1 | 基本測試（插入順序 JSON key） | Python/Node.js/C#/Ruby 等插入順序語言 |
| 2 | 基本測試（字母序 JSON key） | Go/Java/Swift 等字母序語言 |
| 3 | 特殊字元 `!*'()~` | 各語言 URL encode 差異 |
| 4 | **PKCS7 16-byte 邊界** | plaintext 剛好 32 bytes 時的 padding 行為 |

## UTF-8 與非 ASCII 字元測試

ECPay AES 加密支援 UTF-8 中文內容（如 `ItemName` 含中文）。在實作時請注意：
- JSON 序列化時確保使用 UTF-8 編碼，勿使用 ASCII 逸出（如 Python 需設定 `ensure_ascii=False`）
- URL encode 後的 `%XX` 百分比編碼大小寫需符合各語言規格（詳見 guides/14 各語言說明）
- 可用 guides/14 測試帳號（`ejCk326UnaZWKisg` / `q9jcZX8Ib9LM8wYk`）自行構建中文測試向量驗證實作
