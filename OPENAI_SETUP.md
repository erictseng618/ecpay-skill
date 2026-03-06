# OpenAI Custom GPTs 建置指南

> 本指南說明如何將 ECPay Skill 安裝到 OpenAI Custom GPTs（ChatGPT Plus/Team/Enterprise）。

## 前置條件

- ChatGPT Plus、Team、Enterprise 或 Edu 帳號
- 已 clone 或下載本 repo

## 步驟 1：開啟 GPT 編輯器

前往 [https://chatgpt.com/gpts/editor](https://chatgpt.com/gpts/editor)，點選 **Create a GPT** → 切換到 **Configure** 頁籤。

## 步驟 2：基本設定

| 欄位 | 建議值 |
|------|--------|
| **Name** | ECPay 綠界科技整合助手 |
| **Description** | 綠界科技官方 API 整合顧問 — 金流、物流、電子發票、電子票證串接、除錯、上線檢查。支援 12 種程式語言。 |
| **Conversation Starters** | 見下方建議 |

### 建議 Conversation Starters

> OpenAI GPTs 介面最多顯示 4 個按鈕。以下提供 5 個建議，請擇 4 個使用。

```
我要用 Node.js 串接信用卡付款，前後端分離架構
CheckMacValue 驗證失敗，錯誤碼 10400002
幫我用 Python 寫一個 AIO 金流串接
我需要收款後自動開發票再出貨
測試環境可以了，要怎麼切換到正式環境？
```

> **Note**：`commands/` 目錄為 Claude Code 專用快速指令（`/ecpay-*`），不適用於 OpenAI GPTs。GPTs 使用 Conversation Starters 達到同等效果。

## 步驟 3：貼入 System Instructions

1. 開啟本 repo 的 **`SKILL_OPENAI.md`**
2. 複製全部內容
3. 貼入 GPT 編輯器的 **Instructions** 欄位

> ⚠️ OpenAI 限制 Instructions 最多 8,000 字元。`SKILL_OPENAI.md` 已控制在此限制內。

## 步驟 4：上傳 Knowledge Files

OpenAI 允許最多 **20 個** Knowledge Files。以下為建議的優先上傳清單（依重要性排序）：

### 必上傳（核心指南）— 12 個檔案

| # | 檔案 | 用途 |
|---|------|------|
| 1 | `SKILL.md` | 完整決策樹與導航 |
| 2 | `guides/00-getting-started.md` | 入門指南 |
| 3 | `guides/01-payment-aio.md` | AIO 金流（最常用） |
| 4 | `guides/02-payment-ecpg.md` | 站內付 ECPG |
| 5 | `guides/04-invoice-b2c.md` | B2C 電子發票 |
| 6 | `guides/06-logistics-domestic.md` | 國內物流 |
| 7 | `guides/13-checkmacvalue.md` | CheckMacValue 12 語言實作 |
| 8 | `guides/14-aes-encryption.md` | AES 加解密 12 語言實作 |
| 9 | `guides/15-troubleshooting.md` | 除錯指南 |
| 10 | `guides/16-go-live-checklist.md` | 上線檢查清單 |
| 11 | `guides/20-http-protocol-reference.md` | HTTP 協議參考（跨語言必備） |
| 12 | `guides/21-error-codes-reference.md` | 錯誤碼參考 |

### 建議上傳（擴充）— 8 個檔案

| # | 檔案 | 用途 |
|---|------|------|
| 13 | `guides/03-payment-backend.md` | 幕後授權/取號 |
| 14 | `guides/05-invoice-b2b.md` | B2B 電子發票 |
| 15 | `guides/07-logistics-allinone.md` | 全方位物流 |
| 16 | `guides/09-ecticket.md` | 電子票證 |
| 17 | `guides/11-cross-service-scenarios.md` | 跨服務整合場景 |
| 18 | `guides/22-webhook-events-reference.md` | Webhook 參考 |
| 19 | `guides/24-multi-language-integration.md` | 多語言 E2E 範例 |
| 20 | `guides/12-sdk-reference.md` | PHP SDK 參考 |

> 💡 **提示**：如果您的使用場景明確（例如只需金流），可以將不需要的檔案替換為其他 guides。

## 步驟 5：設定 Capabilities

建議啟用：

- [x] **Web Search** — **必須啟用**：GPT 需要透過 Web Search 即時讀取 `developers.ecpay.com.tw` 的最新 API 規格。未啟用此功能將無法取得最新參數定義。
- [x] **Code Interpreter & Data Analysis** — 協助計算 CheckMacValue、除錯加密邏輯

不需要：
- [ ] Image Generation
- [ ] Canvas

## 步驟 6：發布

1. 點選 **Create** 或 **Update**
2. 選擇發布範圍：
   - **Only me** — 個人使用
   - **Anyone with the link** — 團隊共享
   - **Everyone** — 公開到 GPT Store

## 驗證測試

建置完成後，嘗試以下問題確認 GPT 運作正常：

```
1. 「我要串接信用卡付款，用 Python」
   → 預期：推薦 AIO 或 ECPG，生成含 CheckMacValue 的完整程式碼

2. 「CheckMacValue 一直驗證失敗」
   → 預期：詢問使用語言，引導排查 URL encode 順序

3. 「測試帳號是什麼？」
   → 預期：列出對應服務的 MerchantID/HashKey/HashIV

4. 「ECPG 一直 404」
   → 預期：提醒 ecpg vs ecpayment 雙 domain 問題
```

## 更新維護

當 ECPay Skill 有新版本時：
1. 更新 `SKILL_OPENAI.md` → 重新貼入 Instructions
2. 重新上傳更新過的 guides/ 檔案到 Knowledge Files
3. **移除舊版檔案**再上傳新版（OpenAI 用語意搜尋，重複檔案會造成混淆）
