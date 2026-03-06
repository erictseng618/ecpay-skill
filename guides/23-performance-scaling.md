> 對應 ECPay API 版本 | 最後更新：2026-03

# 效能與擴展性指引

> **適用場景**：已完成基礎串接，準備進入生產環境的高流量場景。
> **前置條件**：已完成 [guides/16 上線檢查清單](./16-go-live-checklist.md)。
> **大多數開發者可跳過本指南**，除非日交易量超過 1,000 筆。

本指南涵蓋 ECPay 整合的效能最佳化、擴展性設計和合規注意事項。

## Rate Limiting

### ECPay 已知限制行為

- ECPay 未公開 API 呼叫速率的具體數值
- 觸發限流後回傳 HTTP 403 Forbidden
- 403 觸發後需等待約 **30 分鐘**才恢復
- 此限制基於 IP + MerchantID 組合

### 建議做法

- API 呼叫間隔至少 **200ms**
- 批次操作（如大量查詢或開發票）使用排隊機制
- 避免在迴圈中無間隔連續呼叫 API
- 實作 exponential backoff（收到 403 時）

### 排隊機制

確保 API 呼叫間隔至少 200ms。使用你的語言/框架的內建 rate limiter 或簡單的 timer queue 即可。多節點環境可用 Redis 做分散式限流。

## 冪等性（Idempotency）

### MerchantTradeNo 唯一性保障

`MerchantTradeNo` 是防止重複扣款的關鍵。在分散式環境下：

```javascript
// 建議的 ID 生成策略
function generateTradeNo() {
  const timestamp = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
  const random = Math.random().toString(36).substring(2, 8).toUpperCase();
  return `${timestamp}${random}`; // 例：20260305143022A1B2C3（共 20 字元）
}
```

**注意**：MerchantTradeNo 最大長度 20 字元，允許英數字。

### 防止重複扣款

```sql
-- 在資料庫中建立 UNIQUE constraint
ALTER TABLE orders ADD CONSTRAINT uq_merchant_trade_no UNIQUE (merchant_trade_no);

-- 建立交易前檢查
SELECT status FROM orders WHERE merchant_trade_no = $1;
-- 若已存在且 status = 'paid'，不要重新建立交易
```

### ReturnURL Callback 的冪等處理

冪等性 SQL 實作（含金流和物流 callback 的 upsert 範例）見 [guides/22 §冪等性實作建議](./22-webhook-events-reference.md#冪等性實作建議)。

### 冪等 Webhook 設計最佳實踐

完整冪等 Webhook 設計模式（含 Node.js / Python 範例、設計原則）見 [guides/22 §冪等性實作建議](./22-webhook-events-reference.md#冪等性實作建議)。

## Webhook 佇列架構

### 為何不應在 ReturnURL Handler 中做重邏輯

- ECPay 期望在約 **10 秒內**收到回應
- 若 handler 執行太久，ECPay 會視為失敗並重試
- 耗時操作（發信、開發票、更新庫存）應非同步處理

### 建議架構

```
ECPay Callback
    │
    ▼
┌─────────────────────┐
│  Callback Handler   │
│  1. 驗證 CMV/AES    │
│  2. 存入 DB (upsert)│
│  3. 推入佇列        │
│  4. 回應 1|OK       │  ← 必須在 10 秒內
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Message Queue      │
│  (Redis/SQS/RabbitMQ)│
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Worker Process     │
│  - 發送確認信       │
│  - 開立電子發票     │
│  - 更新庫存         │
│  - 通知物流出貨     │
└─────────────────────┘
```

> **佇列選擇**：使用你的框架內建的佇列機制即可（如 Laravel Queue、Celery、BullMQ）。

## 重試策略

### 主動查詢（Exponential Backoff with Jitter）

當需要確認交易結果但未收到 callback 時：

```python
import time
import random

def query_trade_with_retry(merchant_trade_no, max_retries=5):
    for attempt in range(max_retries):
        result = query_trade_info(merchant_trade_no)
        if result['TradeStatus'] == '1':  # 已付款
            return result

        # Exponential backoff with jitter
        base_delay = min(2 ** attempt * 1000, 30000)  # 最多 30 秒
        jitter = random.randint(0, 1000)
        time.sleep((base_delay + jitter) / 1000)

    raise TimeoutError(f"Trade {merchant_trade_no} status unknown after {max_retries} retries")
```

### 被動重試（ECPay Callback 重試）

- ECPay 在 callback 未收到正確回應時會自動重試
- 重試頻率約每 **2 小時**一次，每天約 **4 次**
- 持續數天後停止

### 兩者搭配的最佳實踐

1. **即時**：正確處理 callback，回應 `1|OK`
2. **5 分鐘後**：若未收到 callback，主動查詢一次
3. **定期**：每小時掃描「未確認」訂單，批次查詢
4. **每日**：下載對帳檔進行最終比對

## 高可用建議

### 多節點部署時的 Callback 處理

在多節點（load balancer）環境下，同一筆 callback 可能被不同節點接收：

```sql
-- 使用 SELECT FOR UPDATE 或 Advisory Lock 防止競態條件
BEGIN;
SELECT * FROM orders WHERE merchant_trade_no = $1 FOR UPDATE;
-- 檢查是否已處理
-- 更新狀態
COMMIT;
```

### 連接池配置

建議配置：最大連接數 20、閒置超時 30 秒、連接超時 5 秒。確保連接池大小能支撐 callback 高峰期的並發處理量。

### 具體監控告警模式

| 監控項 | 正常範圍 | 告警條件 | 處理方式 |
|--------|---------|---------|---------|
| Callback 接收率 | 建立訂單數 ≈ 回呼數 | 差異 > 10% 超過 1 小時 | 啟動主動查詢恢復（見 [guides/22](./22-webhook-events-reference.md)） |
| CMV/AES 驗證失敗率 | < 1% | > 5% | 檢查 HashKey/HashIV 是否更換或洩漏 |
| 回呼處理時間 P95 | < 3 秒 | > 8 秒 | 移至 Queue 非同步處理（見上方佇列架構） |
| 交易成功率 | > 95% | < 90% 持續 30 分鐘 | 暫停新訂單建立、檢查帳號/參數設定 |
| 對帳差異筆數 | 0 | > 0 連續 2 日 | 人工審查 + 聯繫綠界客服 |

> 使用你的監控框架追蹤以上指標（counter 追蹤回呼總數/失敗數、histogram 追蹤處理延遲）。

## 對帳最佳實踐

### 每日對帳 vs 即時對帳

| 方式 | 優點 | 缺點 | 適用場景 |
|------|------|------|---------|
| 即時（Callback） | 即時性高 | 可能漏收 | 主要流程 |
| 每日（對帳檔） | 完整可靠 | 有延遲（T+1） | 補充驗證 |
| 主動查詢 | 可控時機 | 佔用 API 額度 | 異常處理 |

### 對帳檔下載

- **Domain**：`vendor-stage.ecpay.com.tw`（測試）/ `vendor.ecpay.com.tw`（正式）
- **注意**：對帳檔 domain 與金流 API domain 不同！
- **API 端點**：`/PaymentMedia/TradeNoAio`
- **格式**：CSV

### 差異處理流程

```
每日排程
    │
    ▼
下載對帳檔（CSV）
    │
    ▼
比對本地訂單資料庫
    │
    ├── 一致 → 標記已對帳
    │
    ├── 金額不符 → 告警 + 人工處理
    │
    ├── 對帳檔有但本地無 → 漏收 callback，補建訂單記錄
    │
    └── 本地有但對帳檔無 → 可能未完成付款，確認訂單狀態
```

## 合規注意事項

> PCI-DSS 合規、個人資料保護法、消費爭議處理等法規問題，請諮詢貴公司法務或聯繫綠界客服。
> 使用 ECPay 金流（非直接處理卡號），通常適用 SAQ A 最低合規等級。

## 負載測試指引

### 工具推薦

推薦使用 k6 (JavaScript/Go)、Locust (Python) 或 Artillery (Node.js) 進行負載測試。

> **警告**：絕對不要對 ECPay 測試環境做壓測！ECPay 有 IP 層限流，觸發後需等 30 分鐘。
> 壓測對象應為**你自己的 server**，測試的是你的系統在高並發下能否正確組裝參數、處理回呼。

## 容錯設計建議

- **重試策略**：API 呼叫失敗時使用指數退避（1s → 5s → 30s），最多重試 3 次
- **失敗告警**：重試上限後通知管理員人工處理
- 大型系統的進階容錯模式請參考你的框架或基礎設施文件

## 相關文件

- [guides/16-go-live-checklist.md](./16-go-live-checklist.md) — 上線檢查清單
- [guides/15-troubleshooting.md](./15-troubleshooting.md) — 除錯指南
- [guides/22-webhook-events-reference.md](./22-webhook-events-reference.md) — Callback 欄位定義
- [guides/21-error-codes-reference.md](./21-error-codes-reference.md) — 錯誤碼參考
