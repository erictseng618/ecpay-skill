# ECPay Skill 更新紀錄

## v2.12 — 2026-03-06

八代理企業級 Review Board 全面修正：

- **DX**：guides/00 新增 CheckMacValue 新手警告、npm/pip 安裝指令、完整 ngrok 步驟
- **過度設計**：guides/23 移除 Message Queue 架構圖、guides/11 場景一改為導航式
- **串接完整性**：guides/22 新增冪等性實作建議和 Callback 檢查清單
- **串接完整性**：guides/01 新增部分退款注意事項和 ATM/CVS RtnCode 說明
- **新手友善**：SKILL.md 新增頻率排序新手推薦路徑
- **新手友善**：guides/14 新增 AES vs CheckMacValue 對比表
- **精簡**：SECURITY.md 整合至 CONTRIBUTING.md、OPENAI_SETUP.md 精簡
- **精簡**：guides/11 跨服務場景新增故障補償對照表
- **維護**：guides/20 新增更新頻率標注、guides/12 新增 GetToken 角色說明

## v2.11 — 2026-03-06

企業級強化與多語言 DX 改善：

- **企業級**：新增 SECURITY.md（漏洞通報流程）
- **企業級**：新增 GitHub Issue/PR 模板（api-spec-error、encryption-issue、PR checklist）
- **企業級**：新增 CI workflow（validate-ai-index.sh 自動驗證 AI Section Index）
- **企業級**：guides/16 新增 PCI DSS 範圍影響表（AIO=SAQ-A、ECPG=SAQ-A-EP、幕後授權=SAQ-D）
- **多語言**：guides/24 TypeScript 擴充 — AioCallbackParams 型別、tsconfig 設定、Webhook 型別安全提示
- **多語言**：guides/24 新增「各語言 E2E 組裝步驟」區段（Delta 指南使用說明）
- **多語言**：guides/14 C# AES 釐清 — HttpUtility（空格→+，推薦）vs WebUtility（空格→%20）選擇指引
- **修正**：SKILL.md Invoice URL 計數 120 → 119
- **修正**：SKILL.md 新增 Ruby CGI.escape + Go json.NewEncoder 陷阱
- **修正**：guides/14 新增 AES 字母序 JSON key 測試向量
- **修正**：SKILL.md YAML keywords 精簡約 30%
- **修正**：guides/24 AI Section Index 行號重新校準

## v2.10 — 2026-03-06

十二次六代理審核修復：

- **CRITICAL**：guides/00 Python + Node.js AES `aesUrlEncode` hex 大小寫修正（`%7e` → `%7E`），AES 不做 `toLowerCase`，小寫 hex 導致密文與 PHP 不一致
- **MAJOR**：guides/14 AI Section Index 行號重新校準（Go→Ruby 偏移 3-6 行，8 個 FAIL → 0）
- **MAJOR**：guides/24 AI Section Index 行號重新校準（系統性偏移 2 行，11 個條目修正）
- **MAJOR**：SKILL.md 瘦身 — 維護指引移至 CONTRIBUTING.md、changelog 摘要改為連結、減少約 35 行
- URL 計數修正 432 → 431（SKILL.md + README.md，共 5 處）
- SKILL.md 陷阱表 Ruby 描述修正（`CGI.escape` 不編碼 `!*'()`，非「原生已編碼」）
- SKILL.md 陷阱表 `~` 替換值改為大寫 `%7E`（同時適用 CMV 和 AES）
- guides/14 Python 註解修正（`quote_plus` 在 Python 3 已編碼 `'`，`.replace` 為冪等保險）
- README 測試帳號去重（4 處 → 2 處，README 改為連結）
- README 安裝路徑改善：Copilot CLI 推薦專案層級、Cursor/Windsurf 分離並給出具體路徑
- CONTRIBUTING.md 新增維護指引段落（從 SKILL.md 遷移）

## v2.9 — 2026-03-06

- C++ AES `aesUrlEncode` 白名單遺漏修正
- README 新增安裝驗證段落
- CHANGELOG 獨立為獨立檔案（從 README 分離）
- AI 生成程式碼 SNAPSHOT 標註規則

## v2.8 — 2026-03-06

- AES hex 大小寫修正（C/Rust/Go）
- SKILL_OPENAI.md 壓縮（適配 GPTs token 限制）
- guides/24 過度設計精簡（72.9KB → 28.6KB，差異指南模式取代完整 E2E）

## v2.7 — 2026-03-06

- AES hashIV 錯字修正
- Commands 10 → 5 精簡（合併為 pay/invoice/logistics/debug/go-live）
- guides/24 TypeScript 改為指向 Node.js + 型別定義
- CONTRIBUTING.md 新增

## v2.6 — 2026-03-06

- DX 無摩擦改善
- 企業級維護驗證協議
- SKILL.md reference 完整索引表

## v2.5 — 2026-03-06

- API 規格即時查閱機制
- references/ 新增 AI 即時讀取標頭
- web_fetch 工具對應表

## v2.4 以前

- **v2.4**：七次七代理企業典範審查、SKILL.md 協議速查卡、guides/00 Go Quick Start
- **v2.3**：Python AES URL encode 單引號 bug 修正（CRITICAL）、核心概念詞彙表、Swift/Rust E2E
- **v2.2**：跨境物流 callback 修正、幕後授權矛盾解決、ECPG CSP 指引
- **v2.1**：DX 摩擦點修正、過度設計精簡、反向快查表、Callback 術語統一
- **v2.0**：AES URL encode 多語言 bug 修正、callback 格式矛盾解決、timing-safe 全面化
- **v1.9**：CRITICAL 程式碼修正（C#/Go/C AES URL encode）、過度設計精簡、AI Section Index
- **v1.0 ~ v1.8**：初始版本 → 25 份指南、12 語言、134 個 PHP 範例、多輪品質審查修正
