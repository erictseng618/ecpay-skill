# ECPay Skill 更新紀錄

## v2.16 — 2026-03-07

七代理全面審核修正（2 CRITICAL + 4 HIGH + 4 MEDIUM + 5 LOW）：

- **CRITICAL**：guides/00 新增「Callback 回應格式速查表」（AIO 回 `1|OK`、ECPG 回 JSON、全方位物流回 AES 加密 JSON），預防開發者格式錯誤導致無限重試迴圈
- **HIGH**：SKILL_OPENAI.md Knowledge Files 改為完整表格（補齊 guides/12、17、18、19、23 五個缺項）
- **HIGH**：SKILL_OPENAI.md 新增「Language-Specific Traps」速查表（8 項關鍵語言陷阱，含修復方式）
- **HIGH**：guides/24 強化 Python/Node.js 開發者除錯必讀警告（明確標示 guides/13-14 為除錯前置條件）
- **MEDIUM**：OPENAI_SETUP.md 版本號修正 v2.14 → v2.16（與其他入口文件同步）
- **MEDIUM**：guides/15 症狀速查表 RtnCode=2 / 10100073 改標為「✅ 正常業務狀態」，消除開發者誤判
- **MEDIUM**：guides/19 PHP 範例標注來源（基於 references/ API 技術文件，SDK 無獨立 example 檔案）
- **MEDIUM**：SKILL.md 語言陷阱速查表行號參考改為相對位置（`line 79-163` → `§各語言 URL encode 對比`，防漂移）
- **LOW**：.github/ISSUE_TEMPLATE 新增 bug.md（一般問題回報）和 feature-request.md（功能建議）
- **LOW**：SKILL.md 語言陷阱速查表行號參考防漂移修正（L1）

## v2.15 — 2026-03-07

多輪代理深度審核全面修正（六代理並行評估）：2 CRITICAL + 5 HIGH + 10 MEDIUM + 6 LOW：

- **CRITICAL**：guides/00 新增 ECPG 雙 Domain 警告（三大協議表後高亮提示）
- **CRITICAL**：guides/00 嵌入 CheckMacValue 四步驟排查摘要（新手不需跳頁）
- **HIGH**：guides/00 新增服務→協議快速判斷（AIO/ECPG/發票→對應協議）
- **HIGH**：guides/00 升格測試帳號混用警告為獨立區塊（含四服務 MerchantID 對照表）
- **HIGH**：guides/00 本地開發方案新增「對比表」（SimulatePaid vs ngrok 優缺點）
- **MEDIUM**：SKILL.md ATM/CVS 術語修正（「等待付款中」→「取號成功，消費者尚未付款」）
- **MEDIUM**：guides/22 AIO 重試說明補充「持續天數有上限，重試停止後需手動補查」
- **MEDIUM**：guides/23 對帳檔下載補充 Rate Limit 建議（≤7 天範圍、≥1 分鐘間隔）
- **MEDIUM**：guides/04 GetIssueByRelateNo 端點標記改為「建議改用 GetIssueList」
- **MEDIUM**：guides/06 新增冷鏈物流開通確認說明
- **MEDIUM**：guides/09 補充 NotifyURL Callback 格式說明（AES 解密 + 回 `1|OK`）
- **MEDIUM**：OPENAI_SETUP.md 補充版本號標示（v2.15）
- **MEDIUM**：guides/23 監控告警閾值補充「依業務 SLA 調整」說明
- **MEDIUM**：SKILL.md 快速查詢表補充 guides/23 高流量/Rate Limiting 入口
- **MEDIUM**：test-vectors/README.md 補充 UTF-8 中文測試建議說明
- **LOW**：guides/14 Java `LinkedHashMap` 補充性能說明（保序必要，無替代方案）
- **LOW**：guides/24 C# 補充 `HttpClient` singleton 最佳實踐說明
- **LOW**：guides/16 環境切換步驟 3 補充「有無 Feature Flag 分支說明」
- **LOW**：CHANGELOG.md 「六代理」術語改為「多輪代理深度審核（六代理並行評估）」

## v2.14 — 2026-03-07

多輪代理深度審核全面修正（六代理並行評估）（2 CRITICAL + 3 HIGH + 12 MEDIUM + 4 LOW）：

- **CRITICAL**：SKILL_OPENAI.md 版本號 v2.12→v2.13（漏同步）
- **CRITICAL**：SKILL.md 版本號記錄 v2.12→v2.13（第 598 行）
- **HIGH**：guides/00 最快測試路徑補充警告「此路徑不測試 ReturnURL callback」
- **HIGH**：guides/22 Callback 總覽表補充重試觸發條件、AIO 次數上限、其他服務次數未公開說明
- **HIGH**：SKILL_OPENAI.md 補充帳號混用風險警告（金流/物流/發票帳號不同）
- **MEDIUM**：README.md 合併重複條目（431 URL 與 19 份文件說明）
- **MEDIUM**：SKILL.md guides/24 行數修正（約 900→約 910 行）
- **MEDIUM**：SKILL_OPENAI.md rule 8 補充 AES-JSON Checklist 引用
- **MEDIUM**：guides/21 補充未列出錯誤碼的 references 查閱指引
- **MEDIUM**：guides/00 非 PHP 開發者語言選讀路徑補充閱讀順序說明
- **MEDIUM**：guides/22 頂部新增認證方式警告（SHA256/MD5/AES 依服務而異）
- **MEDIUM**：guides/13 Ruby section 頂部補充 CGI.escape 陷阱警告
- **MEDIUM**：guides/13 Java 表格說明補充（%7E→toLowerCase→%7e 的邏輯說明）
- **MEDIUM**：guides/13 Node.js URL encode 補充 %7e/%7E 等價說明
- **MEDIUM**：guides/01 ReturnURL 重要限制補充 10 秒超時 + guides/23 cross-reference
- **MEDIUM**：guides/15 ReturnURL 排查步驟依優先度重排（高/中/低分組）
- **LOW**：guides/09 Ecticket cross-reference 指向 Invoice/B2C/ 具體目錄

## v2.13 — 2026-03-07

多輪代理深度審核全面修正（六代理並行評估）（3 CRITICAL + 8 HIGH + 9 MEDIUM + 6 LOW）：

- **CRITICAL**：修正 CLAUDE.md 中 guides/24 行數（1,775→900）和版本號（v2.1→v2.12）
- **CRITICAL**：guides/09 補充 Ecticket 無 PHP SDK 範例的說明及替代方案
- **HIGH**：SKILL.md 決策樹新增 ECPG 雙 Domain 警告和 ReturnURL 10 秒超時提醒
- **HIGH**：SKILL.md 測試帳號區新增帳號混用風險警告
- **HIGH**：guides/24 新增 AES-JSON 統一 Checklist（10 步驟）
- **HIGH**：guides/24 AI Section Index 行號全面校準
- **HIGH**：SKILL.md Language Traps Table 擴充 AES padding、hex 大小寫、compact JSON 等項目
- **MEDIUM**：guides/21 錯誤碼速查表新增 TransCode 項目
- **MEDIUM**：guides/11 場景一新增時間分解表
- **MEDIUM**：guides/16 新增應用層安全檢查清單（SQL 注入、XSS、冪等性）
- **MEDIUM**：guides/01 非 PHP 開發者路徑改為編號步驟式導引
- **MEDIUM**：README 更新紀錄新增 v2.12 重點摘要
- **LOW**：CLAUDE.md references URL 數量修正（432→431）

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
