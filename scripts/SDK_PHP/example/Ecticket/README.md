# Ecticket PHP 範例

ECPay 官方 PHP SDK v4.x 未包含電子票證（Ecticket）範例。

電子票證使用與 B2C 發票相同的 AES-JSON 協議。
請參考 `../Invoice/B2C/` 目錄中的範例，結構完全相同：
- 替換 `Service` 參數（如 `Issue` → `IssueVoucher`）
- 依 references/Ecticket/ 的 API 文件調整請求參數

參見 [guides/09 電子票券指南](../../../../guides/09-ecticket.md)。
