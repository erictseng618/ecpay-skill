# 貢獻指南

感謝您有興趣為 ECPay Skill 做出貢獻！

## 回報問題

- 在 Issues 中描述問題，附上：使用的 AI 平台（Claude Code / Copilot CLI / GPTs）、重現步驟、預期行為
- API 規格錯誤請附上 `developers.ecpay.com.tw` 對應頁面截圖或連結

## 安全漏洞通報

若發現安全漏洞（如 HashKey/HashIV 洩漏風險、加密實作缺陷、timing attack 弱點），請**不要**在公開 Issues 中提交。

**通報方式**：直接聯繫綠界技術團隊 ecpay@ecpay.com.tw，主旨標明 `[Security] ECPay Skill 安全漏洞通報`。

**回應時間**：
- 確認收到：1-2 個工作天
- 初步評估：3-5 個工作天
- CRITICAL 級別：24 小時內修復

**涵蓋範圍**：
- guides/13（12 語言 CheckMacValue）、guides/14（12 語言 AES）
- SKILL.md / SKILL_OPENAI.md 中的安全規則
- scripts/SDK_PHP/ 官方 PHP SDK 範例

不涵蓋：ECPay 平台本身的漏洞（請透過 techsupport@ecpay.com.tw 通報）。

## 修改指南

1. Fork 本 repo 並建立 feature branch
2. 修改時遵守以下原則：
   - **guides/** 內的參數表為 SNAPSHOT，修改時同步更新 `SNAPSHOT 2026-XX` 標記
   - **references/** 內為 URL 索引，維持 blockquote AI 指令標頭 + 章節 URL 列表格式
   - 更新 **guides/13、14、24** 的章節結構後，執行 `bash scripts/validate-ai-index.sh` 確認 AI Section Index 行號索引正確
   - **commands/** 為 Claude Code 快速指令，保持精簡（每個 ≤ 20 行）
3. 確認 SKILL.md / SKILL_OPENAI.md / README.md 的版本號與更新紀錄一致
4. 提交 Pull Request 並說明變更原因

## 目錄結構規範

| 目錄 | 用途 | 修改注意事項 |
|------|------|-------------|
| `guides/` | AI 知識文件 | 保持 SNAPSHOT 標記一致，參數表附來源 reference 路徑 |
| `references/` | 官方 API URL 索引 | 維持 YAML front-matter + URL 列表格式 |
| `scripts/SDK_PHP/` | 官方 PHP 範例 | 僅追蹤官方 SDK 更新，不自行修改 |
| `commands/` | Claude Code 指令 | 指令負責導航，不重複 SKILL.md 的 SNAPSHOT 邏輯 |

## 新增語言支援

- 加密函式（guides/13, 14）：需提供 timing-safe 比較 + 測試向量驗證
- E2E 範例（guides/24）：提供安裝指令、框架選擇、與 Go 參考版的差異點
- 更新 SKILL.md 語言計數和語言特定陷阱表

## 維護指引

### 定期驗證（建議每季執行）

1. **URL 可達性驗證**：抽查 references/ 中的 URL 是否仍可存取（建議每季抽查 10-20 個 URL）
2. **AI 即時讀取測試**：使用 `web_fetch` 讀取 2-3 個 reference URL，確認回傳內容包含預期的 API 參數表
3. **PHP SDK 版本檢查**：比對 `scripts/SDK_PHP/composer.json` 與 [ECPay 官方 PHP SDK](https://github.com/ECPay/ECPayAIO_PHP) 最新版本
4. **AI Section Index 校驗**：執行 `bash scripts/validate-ai-index.sh` 確認行號索引正確

> **URL 失效回退策略**：若 `developers.ecpay.com.tw` 單一 URL 失效（404/重新導向），先在該站搜尋替代頁面更新 reference 檔案。
> 若大量 URL 同時失效（網站改版），聯繫綠界技術支援 (techsupport@ecpay.com.tw) 取得新 URL 結構。

### 新增 API 端點時
1. 在對應 `guides/` 中新增或補充 API 說明
2. 在 `references/` 中新增官方文件 URL 索引（確保 URL 可被 AI 即時讀取）
3. 更新 SKILL.md 決策樹（若為新服務類型）
4. 更新文件索引表

### PHP SDK 更新時
1. 比對新版 PHP 範例與現有 guide 內容
2. 更新參數差異、新增 API
3. 同步加密實作（若有變更）

### API 版本演進處理

當 ECPay 更新 API 規格時（棄用端點、新增參數、變更格式）：
1. 更新 `references/` 對應文件中的 URL 索引
2. 更新對應 `guides/` 的 SNAPSHOT 日期戳記
3. 在 `CHANGELOG.md` 記錄受影響的 guide 編號

ECPay 官方 API 變更公告請見：[developers.ecpay.com.tw](https://developers.ecpay.com.tw)

## 版本相容性承諾

- **v2.x（當前系列）**：同系列版本保持向下相容，不移除現有 guide 結構或加密函式介面
- **棄用警告**：若 ECPay 官方廢棄某 API 端點，對應 guide 頂部將標注 `⚠️ 已棄用（官方公告：YYYY-MM）`，並維持至少一個版本的過渡說明
- **主版本升級**（如 v3.x）：提前在 `CHANGELOG.md` 及 `guides/00` 頂部列出破壞性變更清單，讓開發者有足夠時間準備遷移
- ECPay API 官方棄用公告請見 [developers.ecpay.com.tw](https://developers.ecpay.com.tw)

## 授權

貢獻即同意以 MIT License 授權您的修改。
