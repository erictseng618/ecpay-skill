> 對應 ECPay API 版本 | 基於 PHP SDK ecpay/sdk | 最後更新：2026-03

# 除錯指南 + 錯誤碼 + 常見陷阱

> 若需確認最新 API 錯誤碼定義或參數規格，可從 `references/` 對應檔案 web_fetch 取得最新官方文件。

## 症狀速查表

> 不知道錯誤碼？從你看到的**症狀**開始找：

| 你遇到的症狀 | 最可能原因 | 前往 |
|-------------|-----------|------|
| CheckMacValue 驗證失敗 | HashKey/HashIV 錯誤、Hash 方法搞混（SHA256 vs MD5） | [§1](#1-checkmacvalue-驗證失敗) |
| ReturnURL 收不到通知 | URL 格式、防火牆、未回應 `1\|OK` | [§2](#2-returnurl-收不到通知) |
| HTTP 403 Forbidden | API 速率限制，需等 30 分鐘 | [§3](#3-http-403-forbidden) |
| 付款頁面空白 | 使用了 iframe（AIO 不支援） | [§6](#6-iframe-交易失敗) |
| LINE/FB 內無法交易 | WebView 安全限制 | [§4](#4-ios-linefacebook-無法交易) |
| RtnCode=2 | **不是錯誤** — ATM 取號成功 | [§9](#9-atm-取號-rtncode2-不是錯誤) |
| RtnCode=10100073 | **不是錯誤** — CVS/BARCODE 取號成功 | [§10](#10-cvsbarcode-取號-rtncode10100073-不是錯誤) |
| HTTP 404 Not Found | ECPG 雙 Domain 搞混（ecpg vs ecpayment） | [§14](#14-ecpg-404-雙-domain-錯誤) |
| AES 解密失敗 / TransCode≠1 | Key/IV 長度非 16 bytes、URL encode 順序錯 | [§13](#13-aes-解密失敗) |
| MerchantTradeNo 重複 | 訂單編號已存在 | [§12](#12-merchanttradeno-重複) |
| ItemName 亂碼或截斷 | 超過 400 bytes | [§5](#5-itemname-亂碼或被截斷) |
| BNPL 被拒 | 金額 < 3,000 元 | [§7](#7-bnpl-被拒) |
| 定期定額停止扣款 | 連續 6 次授權失敗 | [§8](#8-定期定額停止扣款) |

---

## 快速排查決策樹

> **錯誤碼查找**：如果你知道具體的 RtnCode 或 TransCode 數字，直接查 [guides/21-error-codes-reference.md](./21-error-codes-reference.md)。
> 本指南聚焦於**排查流程**（不知道問題在哪時怎麼找），guides/21 聚焦於**錯誤碼對照**（知道錯誤碼要查含義）。

```
API 回傳錯誤？
├── CheckMacValue 錯誤 → 見第 1 節
├── HTTP 403 → 速率限制，等 30 分鐘
├── RtnCode 不是 1
│   ├── ATM: RtnCode=2 是正常的（取號成功）
│   ├── CVS/BARCODE: RtnCode=10100073 是正常的
│   ├── 金額相關: 10200050/10200105 → 查 [guides/21](./21-error-codes-reference.md)
│   ├── 訂單重複: 10200047 → 見第 12 節
│   └── 其他: 查 guides/21-error-codes-reference.md
├── AES 解密失敗 → 見第 13 節
├── 收不到通知 → 見第 2 節
├── ItemName 被截斷 → 見第 5 節
└── 網路層問題
    ├── DNS 解析失敗 → 確認 FQDN 正確、DNS 伺服器可用
    ├── TLS 握手失敗 → 確認 TLS 1.2+ 啟用、憑證未過期
    ├── 連線逾時 → 檢查防火牆規則、API endpoint 可達性
    └── 回應逾時 → 設定合理的 timeout（建議 30 秒）

前端問題？
├── 付款頁面空白 → 不可用 iframe
├── LINE/FB 無法付款 → WebView 限制
├── Apple Pay 看不到 → 非 Safari
└── WebATM 無法使用 → 手機不支援
```

---

## 1. CheckMacValue 驗證失敗

**最常見的問題**。按以下順序逐步排查：

### 四步驟排查法

**Step 1：確認 HashKey / HashIV 來源正確**
```
測試環境金流：HashKey=pwFHCqoQZGmho4w6  HashIV=EkRm7iFT261dpevs
測試環境物流：HashKey=5294y06JbISpM5x9  HashIV=v77hoKGq4kWxNNIS
```
✓ 檢查你的 config 中的值是否與上方完全一致（區分大小寫）。最常見原因就是複製貼上時多了空格。

**Step 2：確認 Hash 方法是否正確**
| 服務 | 必須使用 |
|------|---------|
| AIO 金流 | **SHA256** |
| 國內物流 | **MD5**（最常搞混） |
| ECPG / 發票 / 全方位物流 | **AES**（不用 CheckMacValue） |

**Step 3：用測試向量驗證你的實作**

複製 [guides/13-checkmacvalue.md](./13-checkmacvalue.md) 中對應語言的測試向量，確認你的函式能產生正確的 CheckMacValue。如果測試向量通過但實際呼叫失敗，問題出在參數值（進入 Step 4）。

**Step 4：檢查參數值細節**
1. 排序方式：Key 不區分大小寫（case-insensitive）
2. URL encode 行為：空格必須是 `+`（Node.js 的 `encodeURIComponent` 是 `%20`，需替換）
3. 轉小寫和 .NET 特殊字元替換
4. 最終結果必須是**大寫**

詳細的語言特定陷阱見 [guides/13-checkmacvalue.md](./13-checkmacvalue.md)。

**CheckMacValue 錯誤時的實際 HTTP 回應**：

AIO 建單失敗時，回傳 HTML 頁面中會包含錯誤訊息（非 JSON）：
```
HTTP/1.1 200 OK
Content-Type: text/html

<html>...CheckMacValue驗證失敗...RtnCode=10200073...</html>
```

AIO 查詢 API 回傳：
```
TradeStatus=10200073&RtnMsg=CheckMacValue verify fail
```

AES-JSON 服務回傳：
```json
{ "MerchantID": "2000132", "TransCode": 999, "TransMsg": "CheckMacValue Error", "Data": "" }
```

> 看到這些回應，優先排查 HashKey/HashIV 和 Hash 方法（SHA256 vs MD5）是否正確。

## 2. ReturnURL 收不到通知

排查步驟（依優先度排序，先排查最常見原因）：

**高優先度（最常見失敗原因）：**
1. **回應格式**：必須回應純字串 `1|OK`（不可有 HTML 標籤、BOM、換行、HTTP header 之外的內容）
2. **URL 格式**：必須是完整的 `https://` URL（不可是 http://，不可是 localhost）
3. **超時**：ReturnURL 必須在 **10 秒內**回應 `1|OK`；耗時邏輯需放入非同步佇列（見 [guides/23](./23-performance-scaling.md)）

**中優先度：**
4. **埠號**：僅支援 80/443（不可用 8080、3000 等非標準埠）
5. **SSL**：必須 TLS 1.2，自簽憑證會被拒
6. **防火牆**：確認你的伺服器允許綠界 IP 存取（ECPay 不公開 IP 白名單，建議開放全部 IP）

**低優先度（邊界情況）：**
7. **CDN**：不可放在 CDN 後面（可能改變 request 格式）
8. **編碼**：非 ASCII 域名需用 punycode
9. **特殊字元**：URL 中不可含分號 `;`、管道 `|`、反引號 `` ` ``

> **回應超時值**：綠界等待 ReturnURL 回應約 **10 秒**。超時會被視為失敗並觸發重送。
> **最佳實踐**：ReturnURL 只做狀態更新（驗證 + upsert + 回應 `1|OK`），
> 耗時操作（開發票、建物流單、發通知信）放入非同步佇列。
> 詳見 [guides/23-performance-scaling.md](./23-performance-scaling.md) §Webhook 佇列架構。

**重送機制**：如果沒收到 `1|OK`，綠界會每 5-15 分鐘重送，每天最多 4 次。

## 3. HTTP 403 Forbidden

**原因**：API 速率限制（Rate Limiting）。

**解決**：
- 等待 30 分鐘後再試
- 避免在短時間內大量呼叫 API
- 檢查是否有迴圈或重試邏輯不當

> **速率限制詳情**：ECPay 未公開具體的 QPS（每秒請求數）限制。已知行為：
> - 觸發條件：短時間大量 API 呼叫（基於 IP + MerchantID）
> - 恢復時間：約 30 分鐘
> - 建議間隔：至少 200ms（每秒最多 5 次呼叫）
> - 批次操作：使用佇列機制，見 [guides/23](./23-performance-scaling.md) §排隊機制

## 4. iOS LINE/Facebook 無法交易

**原因**：LINE/Facebook 的內建瀏覽器（WebView）有安全限制。

**解決**：
- 引導使用者在外部瀏覽器開啟
- 使用 ECPG 站內付（嵌入式）可能有更好的相容性

## 5. ItemName 亂碼或被截斷

**原因**：
- `ItemName` 最長 400 字元（byte），中文字 UTF-8 佔 3 bytes
- 超過會被截斷

**解決**：
- 控制商品名稱長度
- 多商品用 `#` 分隔：`商品A 100 TWD x 1#商品B 200 TWD x 2`

**多商品 ItemName 格式範例**：
```
商品A 100 TWD x 1#商品B 200 TWD x 2#運費 60 TWD x 1
```
> 每個品項用 `#` 分隔。品項格式為自由文字，但建議包含價格和數量方便消費者辨識。
> 總字元（bytes）不得超過 400。中文一字 = 3 bytes (UTF-8)。

## 6. iframe 交易失敗

**原因**：ECPay 付款頁面不支援 iframe。

**解決**：
- 使用新視窗或頁面導向
- 或改用 ECPG 站內付（設計上就是嵌入式）

## 7. BNPL 被拒

**原因**：BNPL（先買後付）最低金額為 **3,000 元**。

**解決**：確認 `TotalAmount >= 3000`。

## 8. 定期定額停止扣款

**原因**：連續 **6 次**授權失敗會自動取消。

**解決**：
- 在失敗時通知用戶更新信用卡
- 使用 `CreditCardPeriodAction` 的 `ReAuth` 重新授權
- 監控 `PeriodReturnURL` 的每期通知

## 9. ATM 取號 RtnCode=2 不是錯誤

ATM 取號成功的 `RtnCode` 是 `2`（不是 `1`）。

| 情境 | RtnCode | 意義 |
|------|---------|------|
| 信用卡付款成功 | 1 | 交易成功 |
| ATM 取號成功 | **2** | 取號成功（消費者尚未繳費） |
| ATM 繳費成功 | 1 | 繳費完成 |

## 10. CVS/BARCODE 取號 RtnCode=10100073 不是錯誤

超商代碼/條碼取號成功的 `RtnCode` 是 `10100073`。

| 情境 | RtnCode | 意義 |
|------|---------|------|
| CVS/BARCODE 取號成功 | **10100073** | 取號成功 |
| CVS/BARCODE 繳費成功 | 1 | 繳費完成 |

## 11. 測試 vs 正式環境混用

**常見錯誤**：用測試帳號打正式環境，或反過來。

**排查**：
- 測試環境 URL 含 `-stage`
- 正式環境 URL 不含 `-stage`
- MerchantID / HashKey / HashIV 是配對的，不可混用

## 12. MerchantTradeNo 重複

**原因**：同一個 MerchantID 下，`MerchantTradeNo` 不可重複。

**解決**：
- 使用時間戳 + 隨機數：`'ORD' . time() . rand(100, 999)`
- 最長 20 字元，僅英數字

## 13. AES 解密失敗

排查步驟：
1. **Key/IV 長度**：必須取前 16 bytes
2. **加解密順序**：加密前先 URL encode，解密後才 URL decode（ECPay 獨有）
3. **Padding**：PKCS7
4. **Base64**：確認沒有多餘的換行或空格

詳見：[guides/14-aes-encryption.md](./14-aes-encryption.md)

## 14. ECPG 404 雙 Domain 錯誤

**症狀**：呼叫 ECPG 站內付 API 回傳 HTTP 404 Not Found。

**原因**：ECPG 使用**兩個不同的 Domain**，API 打錯 Domain 會得到 404：

| API | 正確 Domain |
|-----|-----------|
| GetTokenbyTrade（取 Token） | `ecpg-stage.ecpay.com.tw` |
| CreateTrade、QueryTrade、DoAction 等 | `ecpayment-stage.ecpay.com.tw` |

**解決**：確認每個 API 的 Domain。詳見 [guides/02-payment-ecpg.md](./02-payment-ecpg.md) 頂部端點對照表。

## 15. Apple Pay 限制

- 僅在 **Safari** 瀏覽器可見（2025/4/1 起同步顯示在其他瀏覽器）
- 需要向綠界申請啟用

## 16. WebATM 限制

- **手機瀏覽器不支援**（需要讀卡機）
- 僅支援桌面瀏覽器

## 17. 微信支付 / TWQR 限制

- 需要向綠界另外申請啟用
- 微信支付需要微信商戶號

## 18. URL 含特殊編碼

如果 API 回傳的 URL 含 `%26`（&）、`%3C`（<）等：
- 需要 `urldecode()` 處理後再使用
- 不要直接拿 URL-encoded 的值做業務邏輯

## 19. 僅限新台幣

ECPay 所有服務僅支援 **新台幣 (TWD)**，不支援多幣別。

## 20. 3D Secure 2.0

- **2025/8/1 起強制啟用** 3D Secure 2.0
- 測試環境 SMS 驗證碼固定為 `1234`

## 21. ChoosePayment=ALL 排除特定付款方式

如果用 `ChoosePayment=ALL` 但想排除某些付款方式，使用 `IgnorePayment` 參數：

```php
'IgnorePayment' => 'ATM#CVS#BARCODE',  // 用 # 分隔
```

## HTTP 層除錯

當 API 回傳異常時，用 curl 手動發送請求隔離問題：

```bash
# AIO 測試（CheckMacValue 需手動計算）
curl -X POST https://payment-stage.ecpay.com.tw/Cashier/QueryTradeInfo/V5 \
  -d "MerchantID=3002607&MerchantTradeNo=你的訂單編號&TimeStamp=$(date +%s)&CheckMacValue=計算後的值"

# ECPG 測試（AES 加密後的 JSON）
curl -X POST https://ecpg-stage.ecpay.com.tw/Merchant/GetTokenbyTrade \
  -H "Content-Type: application/json" \
  -d '{"MerchantID":"3002607","RqHeader":{"Timestamp":1234567890},"Data":"加密後字串"}'
```

若 curl 可以成功但程式碼失敗，問題在你的 HTTP client 設定（如 Content-Type、TLS、timeout）。

## 網路層除錯

### DNS 檢查
```bash
nslookup payment.ecpay.com.tw
# 或
dig payment.ecpay.com.tw
```

### TLS 檢查
```bash
openssl s_client -connect payment.ecpay.com.tw:443 -tls1_2
# 確認 TLS 版本和憑證資訊
```

### 連線可達性
```bash
curl -v --connect-timeout 10 https://payment.ecpay.com.tw
# 觀察 TCP 連線、TLS 握手、HTTP 回應各階段耗時
```

## 日誌記錄建議

### 該記錄什麼
- 完整的請求參數（遮蔽 HashKey、HashIV、CheckMacValue）
- API 回應的 HTTP 狀態碼和 body
- ReturnURL/ServerReplyURL 收到的完整 POST 資料
- 加解密的中間步驟（排查時開啟，正式環境關閉）

### 遮蔽敏感資料範例

```php
function maskSensitiveData($data) {
    $masked = $data;
    $sensitiveKeys = ['HashKey', 'HashIV', 'CheckMacValue', 'CardNo', 'CardValidMM', 'CardValidYY', 'CardCVV2', 'Token'];
    foreach ($sensitiveKeys as $key) {
        if (isset($masked[$key])) {
            $masked[$key] = substr($masked[$key], 0, 4) . '****';
        }
    }
    return $masked;
}
```

```javascript
// Node.js 版本
function maskSensitiveData(data) {
  const sensitiveKeys = ['HashKey', 'HashIV', 'CheckMacValue', 'CardNo', 'CardValidMM', 'CardValidYY', 'CardCVV2', 'Token'];
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) =>
      sensitiveKeys.includes(key) && typeof value === 'string'
        ? [key, value.slice(0, 4) + '****']
        : [key, value]
    )
  );
}
```

```python
# Python 版本
def mask_sensitive_data(data: dict) -> dict:
    sensitive_keys = {'HashKey', 'HashIV', 'CheckMacValue', 'CardNo', 'CardValidMM', 'CardValidYY', 'CardCVV2', 'Token'}
    return {
        k: (v[:4] + '****' if k in sensitive_keys and isinstance(v, str) else v)
        for k, v in data.items()
    }
```

## 回報綠界技術支援

遇到無法自行解決的問題時，聯絡綠界技術支援需附上：

1. **MerchantID**（特店編號）
2. **MerchantTradeNo**（交易編號）
3. **發生時間**（精確到秒）
4. **完整的 API 請求和回應**（遮蔽 HashKey/HashIV）
5. **錯誤訊息或錯誤碼**
6. **使用環境**（測試/正式、語言/框架版本）

聯絡方式：
- 技術支援信箱：techsupport@ecpay.com.tw
- 開發者文件：https://developers.ecpay.com.tw
- 特店後台：可在後台提交技術問題單

## 跨服務 Top 5 錯誤碼速查

> 以下為各服務最常見的錯誤情境。完整錯誤碼清單見 [guides/21-error-codes-reference.md](./21-error-codes-reference.md)。

### ECPG 站內付（AES-JSON）

ECPG 使用**雙層錯誤結構**：先檢查外層 `TransCode`，再檢查內層 `RtnCode`。

| 錯誤情境 | 檢查點 | 常見原因 | 解決方式 |
|---------|--------|---------|---------|
| TransCode ≠ 1 | 外層 JSON | AES 加密錯誤、JSON 格式錯誤、Key/IV 長度非 16 bytes | 檢查 AES 加密流程，確認 URL encode/decode 順序 |
| RtnCode ≠ 1（解密 Data 後） | 內層業務 | 參數錯誤、Token 過期、MerchantTradeNo 重複 | 檢查 RtnMsg 取得詳細錯誤 |
| 10200043 | RtnCode | 3D Secure 驗證失敗 | 請消費者重新進行 3D 驗證 |
| 10200058 | RtnCode | 信用卡授權失敗（額度不足、發卡行拒絕） | 請消費者確認卡片資訊或換卡 |
| 10200115 | RtnCode | 信用卡授權逾時 | 請消費者重新付款，檢查 timeout 設定 |

> **TransCode 常見值**：`1` = API 層成功（需進一步檢查 RtnCode）；`非 1` = API 層失敗（AES/格式問題，無需解密 Data）。

### B2C 電子發票（AES-JSON）

| 錯誤情境 | 常見原因 | 解決方式 |
|---------|---------|---------|
| 稅額與金額不符 | `SalesAmount ≠ TaxAmount + 各項 ItemAmount 總和` | 重新計算稅額，確保加總一致 |
| 統一編號格式錯誤 | 統一編號非 8 位數字 | 使用 `/B2CInvoice/CheckCompanyIdentifier` 驗證 |
| RelateNumber 重複 | 同一關聯號碼重複開立 | 使用新的 RelateNumber（如 `'Inv' + timestamp`） |
| 載具格式錯誤 | 手機條碼未以 `/` 開頭、自然人憑證長度不符 | 手機條碼：`/B2CInvoice/CheckBarcode` 驗證；自然人憑證：2 碼英文 + 14 碼字元 |
| 發票作廢失敗 | 超過作廢期限、發票已折讓 | 確認發票狀態，已折讓的發票需先作廢折讓 |

### 國內物流（CMV-MD5）

| 錯誤情境 | 常見原因 | 解決方式 |
|---------|---------|---------|
| CheckMacValue 驗證失敗 | 用 SHA256 而非 **MD5**、排序或 URL encode 錯誤 | 確認國內物流用 **MD5**（不是 SHA256） |
| RtnCode = 0（通用失敗） | 格式：`0\|ErrorMessage`，多種原因 | 檢查 ErrorMessage 取得具體原因 |
| 門市代碼無效 | ReceiverStoreID 已過期或不存在 | 重新呼叫電子地圖（`/Express/map`）取得最新門市代碼 |
| 物流訂單過期 | 超商寄貨編號逾時 | 重新建立物流訂單 |
| 超商退貨缺 AllPayLogisticsID | 超商退貨設計不回傳此欄位 | 改用 `RtnMerchantTradeNo` 追蹤退貨狀態 |

---

## 相關文件

- CheckMacValue：[guides/13-checkmacvalue.md](./13-checkmacvalue.md)
- AES 加解密：[guides/14-aes-encryption.md](./14-aes-encryption.md)
- 上線檢查：[guides/16-go-live-checklist.md](./16-go-live-checklist.md)
- POS 刷卡機：[guides/17-pos-integration.md](./17-pos-integration.md)
- 直播收款：[guides/18-livestream-payment.md](./18-livestream-payment.md)
- 離線發票：[guides/19-invoice-offline.md](./19-invoice-offline.md)
- 錯誤碼集中參考：見 [guides/21-error-codes-reference.md](./21-error-codes-reference.md)
- Callback 處理：見 [guides/22-webhook-events-reference.md](./22-webhook-events-reference.md)
- 效能與擴展：見 [guides/23-performance-scaling.md](./23-performance-scaling.md)
