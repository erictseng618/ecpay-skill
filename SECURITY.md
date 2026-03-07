# Security Policy

## 支援的版本

| 版本 | 狀態 |
|------|------|
| v2.x | 積極維護 |
| v1.x | 不再維護 |

## 通報安全漏洞

若發現安全漏洞（如 HashKey/HashIV 洩漏風險、加密實作缺陷、timing attack 弱點），請**不要**在公開 Issues 中提交。

**通報方式**：ecpay@ecpay.com.tw（主旨標明 `[Security] ECPay Skill 安全漏洞通報`）

**回應時間**：
- 確認收到：1-2 個工作天
- 初步評估：3-5 個工作天
- CRITICAL 級別：24 小時內修復

## Timing-Safe 簽章驗證（必須項）

> **普通字串比較（==）無法防止 Timing Attack，必須使用各語言的 timing-safe 比較函式。**

在支付 Callback 中驗證 CheckMacValue 時：

| 語言 | Timing-Safe 函式 |
|------|----------------|
| PHP | `hash_equals($computed, $received)` |
| Python | `hmac.compare_digest(computed, received)` |
| Node.js | `crypto.timingSafeEqual(Buffer.from(a), Buffer.from(b))` |
| Go | `subtle.ConstantTimeCompare([]byte(a), []byte(b))` |
| Java | `MessageDigest.isEqual(a.getBytes(), b.getBytes())` |
| C# | `CryptographicOperations.FixedTimeEquals(a, b)` |
| Ruby | `Rack::Utils.secure_compare(a, b)` |

完整各語言實作見 [guides/13 §Callback 驗證](./guides/13-checkmacvalue.md)。

## 涵蓋範圍

- guides/13（12 語言 CheckMacValue 實作）
- guides/14（12 語言 AES 加解密實作）
- SKILL.md / SKILL_OPENAI.md 中的安全規則
- scripts/SDK_PHP/ 官方 PHP SDK 範例

不涵蓋：ECPay 平台本身的漏洞（請透過 techsupport@ecpay.com.tw 通報）。

詳細貢獻指南見 [CONTRIBUTING.md](./CONTRIBUTING.md)。
