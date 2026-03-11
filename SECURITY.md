# 安全政策

## 通報安全漏洞

若發現安全漏洞（如 HashKey/HashIV 洩漏風險、加密實作缺陷、timing attack 弱點），請**不要**在公開 Issues 中提交。

### 通報方式

直接聯繫綠界科技系統分析部：

- **Email**：sysanalydep.sa@ecpay.com.tw
- **主旨格式**：`[Security] ECPay Skill 安全漏洞通報`
- **內容建議包含**：漏洞描述、影響範圍、重現步驟、建議修復方式（如有）

### 回應時間

| 階段 | 時間 |
|------|------|
| 確認收到 | 1-2 個工作天 |
| 初步評估 | 3-5 個工作天 |
| CRITICAL 級別修復 | 24 小時內 |

### 涵蓋範圍

本安全政策涵蓋以下內容的安全漏洞：

- `guides/13`（12 語言 CheckMacValue 實作）、`guides/14`（12 語言 AES 加密實作）
- `SKILL.md` / `SKILL_OPENAI.md` 中的安全規則與決策樹
- `scripts/SDK_PHP/` 官方 PHP SDK 範例
- `test-vectors/` 加密測試向量
- `guides/` 中的程式碼範例（所有語言）

### 不涵蓋範圍

ECPay 平台本身的漏洞（API 伺服器、金流系統、商店後台等），請透過 techsupport@ecpay.com.tw 通報。

## 負責任揭露

我們遵循負責任揭露原則：

1. **請勿公開揭露**：在修復完成前，請勿在公開場合（Issues、社群媒體、部落格）揭露漏洞細節
2. **協同修復**：我們會與通報者合作確認問題並開發修復方案
3. **致謝**：經確認的漏洞，通報者將列入致謝名單（除非通報者要求匿名）

## 憑證安全須知

本 repo 所有出現的 HashKey、HashIV、MerchantID 與測試信用卡號，皆為 **ECPay 官方公開的測試帳號**，僅供開發與驗證使用。

### 貢獻者注意事項

- ❌ **絕對不要** 在 PR 中提交真實的商店 MerchantID、HashKey 或 HashIV
- ❌ **絕對不要** 提交 `.env` 檔案或含有真實憑證的設定檔
- ✅ 範例程式碼一律使用官方測試帳號（見 `SKILL.md` 測試帳號表）
- ✅ 環境變數載入範例使用 `process.env.ECPAY_HASH_KEY` 等 placeholder 形式

### 加密實作安全要求

所有加密驗證程式碼**必須**使用 timing-safe 比較函式，禁止使用 `==` 或 `===`：

| 語言 | 函式 |
|------|------|
| PHP | `hash_equals()` |
| Python | `hmac.compare_digest()` |
| Node.js | `crypto.timingSafeEqual()` |
| Go | `subtle.ConstantTimeCompare()` |
| Java | `MessageDigest.isEqual()` |
| C# | `CryptographicOperations.FixedTimeEquals()` |
| Ruby | `Rack::Utils.secure_compare()` |
| Rust | `constant_time_eq` crate |
| Kotlin | `MessageDigest.isEqual()` |
| Swift | `timingSafeCompare` (自行實作或使用 `Crypto` 套件) |
| C | `CRYPTO_memcmp()` (OpenSSL) |
| C++ | `CRYPTO_memcmp()` (OpenSSL) |
