# ECPay Skill — 綠界科技 AI 整合助手

> **綠界科技官方出品** — 由 ECPay 團隊開發與維護，內容與 API 同步更新。

**當前版本：v2.6** | [更新紀錄](#更新紀錄)

### 前置需求

使用本 Skill 需要以下任一 AI 編程助手：

| 平台 | 需求 |
|------|------|
| Claude Code | Claude Pro / Team / Enterprise 訂閱 |
| GitHub Copilot CLI | GitHub Copilot 訂閱 |
| OpenAI Custom GPTs | ChatGPT Plus / Team / Enterprise |
| OpenClaw | OpenClaw 帳號 |

## 這是什麼？

ECPay Skill 是一個 **AI Skill 套件**——安裝到 AI 編程助手（Claude Code、GitHub Copilot CLI、OpenClaw、**OpenAI Custom GPTs** 等）後，AI 就能根據你的需求，直接生成綠界 API 串接程式碼、診斷錯誤、引導完整串接流程。

不需要自己翻文件，用自然語言描述需求即可。

### AI Skill 是什麼？

AI Skill 是一種 Markdown 套件規格（SKILL.md），讓 AI 編程助手載入特定領域的專業知識。安裝後，AI 在對話中偵測到相關關鍵字時會自動啟動該 Skill，依據內建的決策樹、指南和範例程式碼來回答問題。

### 這個 Skill 能做什麼？

| 能力 | 說明 |
|------|------|
| **需求分析** | 根據你的場景（電商、訂閱、門市、直播等）推薦最適合的 ECPay 方案 |
| **程式碼生成** | 基於 134 個驗證過的 PHP 範例，翻譯為你需要的任何語言 |
| **即時除錯** | 診斷 CheckMacValue 失敗、AES 解密錯誤、API 錯誤碼等串接問題 |
| **完整流程** | 引導收款 → 發票 → 出貨的端到端整合 |
| **上線檢查** | 逐項檢查安全性、正確性、合規性 |

## 快速開始

### 1. 安裝

**Claude Code**
```bash
git clone <repo-url> ~/.claude/skills/ecpay
```

**GitHub Copilot CLI / VS Code Copilot**
```bash
# 個人全域安裝
git clone <repo-url> ~/.copilot/skills/ecpay

# 或專案層級（團隊共用，提交至 repo）
git clone <repo-url> .github/skills/ecpay
```

**OpenClaw**
```bash
git clone <repo-url> ~/.openclaw/skills/ecpay
```

**OpenAI Custom GPTs（ChatGPT Plus/Team/Enterprise）**
1. 開啟 [GPT 編輯器](https://chatgpt.com/gpts/editor)
2. 將 `SKILL_OPENAI.md` 內容貼入 Instructions 欄位
3. 將 `guides/` 下的 Markdown 檔案上傳為 Knowledge Files
4. 詳細步驟見 [`OPENAI_SETUP.md`](./OPENAI_SETUP.md)

**其他框架**：將此資料夾放入框架的 skill 目錄。

### 2. 使用

安裝後，在 AI 助手中直接用自然語言提問。提到 ECPay 相關關鍵字時 Skill 會自動啟動：

> ecpay, 綠界, 信用卡串接, 超商取貨, 電子發票, CheckMacValue, 站內付, 金流串接, 物流串接, 定期定額, 綁卡, 退款, 折讓...

**Claude Code 快速指令**（選用）：將 `commands/` 內的 `.md` 檔複製到專案 `.claude/commands/`，即可使用以下 10 個快速指令：

| 指令 | 用途 |
|------|------|
| `/ecpay-pay` | 串接金流收款（AIO / ECPG / 幕後授權） |
| `/ecpay-invoice` | 串接電子發票（B2C / B2B / 離線） |
| `/ecpay-logistics` | 串接物流（國內 / 全方位 / 跨境） |
| `/ecpay-ecticket` | 串接電子票證 |
| `/ecpay-checkmac` | 生成 CheckMacValue 加密程式碼 |
| `/ecpay-query` | 查詢訂單 / 對帳 |
| `/ecpay-refund` | 退款 / 發票作廢 / 折讓 |
| `/ecpay-callback` | Callback / Webhook 設定 |
| `/ecpay-debug` | 除錯排查 |
| `/ecpay-go-live` | 上線前檢查清單 |

### 3. 使用範例

```
「我要用 Node.js 串接信用卡付款，前後端分離架構」
→ AI 推薦 ECPG 站內付，生成完整 TypeScript 程式碼

「CheckMacValue 驗證一直失敗，錯誤碼 10400002」
→ AI 診斷加密流程，定位 URL encode 順序問題

「我需要收款後自動開發票再出貨，Python」
→ AI 引導金流 + 發票 + 物流的跨服務串接流程

「測試環境可以用了，要怎麼切換到正式環境？」
→ AI 逐項引導上線檢查清單

「幫我用 Go 寫一個完整的 AIO 信用卡串接」
→ AI 生成含 CheckMacValue 計算、表單送出、Callback 驗證的完整範例
```

## 涵蓋服務

| 服務 | 內容 | 對應指南 |
|------|------|---------|
| **金流** | 全方位金流（AIO）、站內付 2.0（ECPG）、幕後授權、幕後取號 | guides/01-03 |
| **物流** | 國內物流（超商取貨 + 宅配）、全方位物流、跨境物流 | guides/06-08 |
| **電子發票** | B2C、B2B（交換 + 存證模式）、離線 | guides/04-05, 19 |
| **電子票證** | 價金保管（使用後核銷 / 分期核銷）、純發行 | guides/09 |
| **購物車** | WooCommerce、OpenCart、Magento、Shopify | guides/10 |
| **POS 刷卡機** | 實體門市刷卡機串接 | guides/17 |
| **直播收款** | 直播電商收款網址 | guides/18 |

### 支援的付款方式

信用卡一次付清、信用卡分期、信用卡定期定額、ATM 虛擬帳號、超商代碼、超商條碼、WebATM、TWQR、BNPL 先買後付、微信支付、Apple Pay、銀聯

## 特色

- **134 個**經官方驗證的 PHP 範例（可翻譯為任何語言）
- **25 份**深度整合指南（從入門到上線）
- **12 種語言**的加密函式實作（Python、Node.js、TypeScript、Java、C#、Go、C、C++、Rust、Swift、Kotlin、Ruby）
- **432 個**官方 API 文件 URL 索引（可追溯原始文件）
- **19 份**官方 API 技術文件索引
- 決策樹自動推薦最適方案
- 跨服務整合場景（收款 + 發票 + 出貨）
- 內建除錯指南和上線檢查清單
- 多輪六代理品質審查（DX、API 準確度、多語言、過度設計、企業基準、參考利用率）
- **SNAPSHOT 防護機制**——guides/ 參數表標記為 SNAPSHOT，附來源路徑與禁令，AI 生成程式碼時自動從 references/ 即時讀取最新官方規格
- **10 個 Claude Code 快速指令**（`/ecpay-pay`、`/ecpay-debug` 等）

### 三大 HTTP 協議模式

ECPay API 使用三種不同的認證和請求格式，本 Skill 完整涵蓋：

| 模式 | 認證方式 | 請求格式 | 適用服務 |
|------|---------|---------|---------|
| **CMV-SHA256** | CheckMacValue + SHA256 | Form POST | AIO 金流 |
| **AES-JSON** | AES-128-CBC 加密 | JSON POST | ECPG、電子發票、全方位/跨境物流、電子票證 |
| **CMV-MD5** | CheckMacValue + MD5 | Form POST | 國內物流 |

## 指南索引

### 入門與全覽

| # | 檔案 | 主題 |
|---|------|------|
| 00 | guides/00-getting-started.md | 從零開始：五分鐘跑通第一筆交易 |
| 11 | guides/11-cross-service-scenarios.md | 跨服務整合場景（收款+發票+出貨） |

### 金流

| # | 檔案 | 主題 |
|---|------|------|
| 01 | guides/01-payment-aio.md | 全方位金流 AIO（20 個 PHP 範例） |
| 02 | guides/02-payment-ecpg.md | 站內付 2.0 ECPG（24 個 PHP 範例） |
| 03 | guides/03-payment-backend.md | 幕後授權 + 幕後取號 |
| 17 | guides/17-pos-integration.md | POS 刷卡機串接指引 |
| 18 | guides/18-livestream-payment.md | 直播收款指引 |

### 電子發票

| # | 檔案 | 主題 |
|---|------|------|
| 04 | guides/04-invoice-b2c.md | B2C 電子發票（19 個 PHP 範例） |
| 05 | guides/05-invoice-b2b.md | B2B 電子發票（23 個 PHP 範例） |
| 19 | guides/19-invoice-offline.md | 離線電子發票指引 |

### 物流

| # | 檔案 | 主題 |
|---|------|------|
| 06 | guides/06-logistics-domestic.md | 國內物流（24 個 PHP 範例） |
| 07 | guides/07-logistics-allinone.md | 全方位物流（16 個 PHP 範例） |
| 08 | guides/08-logistics-crossborder.md | 跨境物流（8 個 PHP 範例） |

### 其他服務

| # | 檔案 | 主題 |
|---|------|------|
| 09 | guides/09-ecticket.md | 電子票證 |
| 10 | guides/10-cart-plugins.md | 購物車模組 |

### 跨領域技術參考

| # | 檔案 | 主題 |
|---|------|------|
| 12 | guides/12-sdk-reference.md | PHP SDK 完整參考 |
| 13 | guides/13-checkmacvalue.md | CheckMacValue 解說 + 12 語言實作 |
| 14 | guides/14-aes-encryption.md | AES 加解密解說 + 12 語言實作 |
| 20 | guides/20-http-protocol-reference.md | HTTP 協議參考（跨語言必讀） |
| 21 | guides/21-error-codes-reference.md | 全服務錯誤碼集中參考 |
| 22 | guides/22-webhook-events-reference.md | 統一 Callback/Webhook 參考 |

### 運維與上線

| # | 檔案 | 主題 |
|---|------|------|
| 15 | guides/15-troubleshooting.md | 除錯指南 + 常見陷阱 |
| 16 | guides/16-go-live-checklist.md | 上線檢查清單 |
| 23 | guides/23-performance-scaling.md | 效能與擴展性指引 |
| 24 | guides/24-multi-language-integration.md | 多語言整合（Go/Java/C#/TS/Kotlin/Ruby E2E + Mobile App） |

## 目錄結構

```
ecpay-skill/
├── SKILL.md                    # AI 進入點：決策樹 + 導航（Claude Code / Copilot CLI / OpenClaw）
├── SKILL_OPENAI.md             # OpenAI Custom GPTs System Instructions
├── OPENAI_SETUP.md             # OpenAI GPTs 建置指南
├── commands/                   # Claude Code 快速指令（10 個 /ecpay-* 指令）
├── guides/                     # 25 份深度整合指南（同時作為 OpenAI Knowledge Files）
├── references/                 # 官方 API 文件 URL 索引（19 個檔案，432 個 URL）— AI 即時讀取入口
│   ├── Payment/   (8 個)
│   ├── Invoice/   (4 個)
│   ├── Logistics/ (3 個)
│   ├── Ecticket/  (3 個)
│   └── Cart/      (1 個)
└── scripts/SDK_PHP/            # 官方 PHP SDK + 134 個範例
    └── example/
        ├── Payment/Aio/        (20 個)
        ├── Payment/Ecpg/       (24 個)
        ├── Invoice/B2C/        (19 個)
        ├── Invoice/B2B/        (23 個)
        ├── Logistics/Domestic/ (24 個)
        ├── Logistics/AllInOne/ (16 個)
        └── Logistics/CrossBorder/ (8 個)
```

## 測試環境快速參考

> ⚠️ 以下為公開測試帳號，僅供開發測試。正式環境務必使用環境變數管理 HashKey/HashIV。

| 用途 | MerchantID | HashKey | HashIV |
|------|-----------|---------|--------|
| 金流 AIO / ECPG | 3002607 | pwFHCqoQZGmho4w6 | EkRm7iFT261dpevs |
| 國內物流 B2B | 2000132 | 5294y06JbISpM5x9 | v77hoKGq4kWxNNIS |
| 國內物流 C2C | 2000933 | XBERn1YOvpM9nfZc | h1ONHk4P4yqbl5LK |
| 全方位/跨境物流 | 2000132 | 5294y06JbISpM5x9 | v77hoKGq4kWxNNIS |
| 電子發票 | 2000132 | ejCk326UnaZWKisg | q9jcZX8Ib9LM8wYk |

**測試信用卡**：`4311-9522-2222-2222`（VISA），安全碼任意三碼，有效期限任意未來日期
**3D Secure 驗證碼**：`1234`

更多測試卡號見 [guides/00-getting-started.md](./guides/00-getting-started.md)。

## 常見問題

**Q：不用 PHP 可以嗎？**
A：可以。本 Skill 支援 12 種語言的加密函式實作，並提供 HTTP 協議參考（guides/20）讓任何語言都能從零實作。PHP 範例作為翻譯基底，AI 會自動轉換為你的目標語言。

**Q：AIO 和 ECPG 站內付怎麼選？**
A：AIO 會跳轉到綠界付款頁，整合最簡單；ECPG 站內付讓消費者在你的網站內完成付款，適合前後端分離架構（React/Vue/Angular）。詳見 guides/01 和 guides/02。

**Q：Callback（付款通知）收不到怎麼辦？**
A：參考 guides/15 §2 排查流程 + guides/22 各服務 Callback 格式彙總。常見原因：URL 不可達、未回應 `1|OK`、防火牆擋 ECPay IP。

**Q：怎麼從測試環境切換到正式環境？**
A：參考 guides/16 上線檢查清單，逐項替換 MerchantID、HashKey/HashIV、API domain。

**Q：API 規格更新時，AI 會讀到最新的嗎？**
A：會。references/ 目錄存放的是 432 個指向 `developers.ecpay.com.tw` 的 URL 索引，不是靜態規格副本。AI 被指示在需要具體參數規格時，透過 `web_fetch` 即時讀取這些 URL 取得官方最新內容。guides/ 提供整合邏輯，references/ 提供即時規格，兩者結合確保回答始終反映最新 API 狀態。

## 更新紀錄

| 日期 | 版本 | 變更摘要 |
|------|------|---------|
| 2025-03 ~ 2026-03 | v1.0-v1.8 | 初始版本 → 25 份指南、12 語言、134 個 PHP 範例 |
| 2026-03-05 | v1.9 | 程式碼修正（C#/Go/C AES URL encode、TypeScript timingSafeEqual）、過度設計精簡 |
| 2026-03-05 | v2.0 | AES URL encode 多語言修正、callback 格式矛盾解決、timing-safe 全面化 |
| 2026-03-05 | v2.1 | DX 改善（ECPG domain 視覺區隔、AES 雙層檢查警告）、反向快查表 |
| 2026-03-05 | v2.2 | 跨境物流 callback 修正、幕後授權 callback 修正、ECPG CSP 指引、Rust/TS E2E 新增 |
| 2026-03-06 | v2.3 | 新增 OpenAI Custom GPTs 支援（SKILL_OPENAI.md + OPENAI_SETUP.md），基於 OpenAI 官方指南設計 |
| 2026-03-06 | v2.5 | API 規格即時查閱機制（21 層指令鏈 + 9 份 guide inline 警告 + 19 個 references AI header）；SNAPSHOT 系統性強化（10 處 SNAPSHOT 2026-03 標記 + 7 層防護體系）；新增 10 個 Claude Code 快速指令（commands/）；閘道模式對照表（代收付 vs 新型閘道）；全服務端點速查表（150+ 端點 × 7 Domain）；OpenAI GPTs Conversation Starters 說明完善 |
| 2026-03-06 | v2.6 | 八次六代理審核修復：DX 無摩擦改善＋企業級強化＋reference 完整索引＋API 準確度修正＋安全警告強化＋Git 版控 |

## 相關資源

- [綠界科技官網](https://www.ecpay.com.tw)
- [開發者文件](https://developers.ecpay.com.tw)
- [PHP SDK GitHub](https://github.com/ECPay/ECPayAIO_PHP)

## 驗證與來源

本 Skill 基於綠界科技官方 API 技術文件及官方 PHP SDK 開發。如需驗證內容準確性：

1. **API 規格**：比對 [developers.ecpay.com.tw](https://developers.ecpay.com.tw) 官方文件
2. **PHP SDK**：比對 [ECPay 官方 GitHub](https://github.com/ECPay/ECPayAIO_PHP) 的範例程式碼
3. **技術諮詢**：聯繫 eric.tseng@ecpay.com.tw 確認

## 聯繫我們

| 用途 | 聯繫方式 |
|------|---------|
| Skill 技術諮詢 | eric.tseng@ecpay.com.tw |
| API 技術支援 | techsupport@ecpay.com.tw |
| 客服專線 | (02) 2655-1775 |

## 授權

MIT License
