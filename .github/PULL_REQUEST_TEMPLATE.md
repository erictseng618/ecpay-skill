## 變更類型

- [ ] API 規格修正
- [ ] 加密實作修正
- [ ] 新語言支援
- [ ] 文件改善
- [ ] 其他

## 變更描述

<!-- 簡述這個 PR 做了什麼 -->

## 影響的檔案

<!-- 列出修改的檔案 -->

## 測試驗證

- [ ] 若修改 guides/13、14、24：已執行 `bash scripts/validate-ai-index.sh` 確認 AI Section Index 正確
- [ ] 若修改加密實作：已用測試向量驗證正確性
- [ ] SKILL.md / SKILL_OPENAI.md / README.md 版本號一致

## 安全確認

- [ ] **未包含真實的 MerchantID / HashKey / HashIV**（範例一律使用官方測試帳號）
- [ ] **未提交 `.env` 或含有真實憑證的設定檔**
- [ ] 若涉及加密驗證：使用 timing-safe 比較函式（見 [SECURITY.md](../SECURITY.md)）

## 相關 Issue

<!-- 如有相關 Issue 請連結 -->
