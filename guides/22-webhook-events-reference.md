> 對應 ECPay API 版本 | 最後更新：2026-03

# 統一 Callback/Webhook 參考

> **何時讀本文件**：當你需要了解各服務 callback 的回應格式、重試機制、冪等性處理時。
> - 排查 callback 收不到 → [guides/15](./15-troubleshooting.md) §2
> - 跨服務 callback 時序 → [guides/11](./11-cross-service-scenarios.md) §Callback 時序
> - 各服務的端點 URL → [guides/20](./20-http-protocol-reference.md)

本文件彙整所有 ECPay 服務的 Callback（Webhook）機制，提供統一的欄位定義和安全處理指引。

> **⚠️ 認證方式依服務而異**：金流 AIO → SHA256，國內物流 → **MD5**，ECPG / 發票 / 物流 v2 / 票證 → AES 解密（無 CheckMacValue）。
> 錯用演算法（如把國內物流當 SHA256 計算）會導致所有 callback 驗證永遠失敗。

## ⚡ Callback 回應格式快速核查卡

> 回應格式錯誤 → ECPay 持續重試通知（AIO 每 5-15 分鐘、最多 4 次/天），可能導致重複入帳。

| 服務 | 你的 Callback URL | 必須回應的格式 | 錯誤後果 |
|------|-----------------|--------------|---------|
| AIO 金流 | ReturnURL | `1\|OK` | 重試通知 |
| ECPG 站內付 | OrderResultURL | `{ "TransCode": 1 }` | 重試通知 |
| 國內物流 | ServerReplyURL | `1\|OK` | 重試通知 |
| 全方位 / 跨境物流 | ServerReplyURL | AES 加密 JSON | 重試通知 |
| 電子票證 | NotifyURL | `1\|OK` | 重試通知 |

**重要**：確認你的回應 HTTP Status 為 **200**，否則 ECPay 視為失敗。

## ⚠️ Callback 回應格式速查（跨服務整合必讀）

**各服務要求不同的回應格式，回應錯誤會導致綠界持續重送。**

| 服務 | 你必須回應的格式 | Content-Type | 回錯會如何 |
|------|----------------|-------------|-----------|
| AIO 金流（ReturnURL） | `1\|OK`（純文字） | text/plain | 每 5-15 分鐘重送，每日最多 4 次（持續天數有上限，重試停止後需手動補查） |
| AIO 金流（PaymentInfoURL / PeriodReturnURL） | `1\|OK`（純文字） | text/plain | 同上 |
| ECPG 站內付 | `{ "TransCode": 1 }`（JSON） | application/json | 約每 2 小時重試 |
| 信用卡幕後授權 | `{ "TransCode": 1 }`（JSON） | application/json | 約每 2 小時重試 |
| 非信用卡幕後取號 | `1\|OK`（純文字） | text/plain | 每 5-15 分鐘重送，每日最多 4 次 |
| 國內物流 | `1\|OK`（純文字） | text/plain | 約每 2 小時重試 |
| 全方位 / 跨境物流 | AES 加密 JSON 三層結構 | application/json | 約每 2 小時重試 |
| 電子票證 | `1\|OK`（純文字） | text/plain | 約每 2 小時重試 |

> **跨服務整合注意**：如果你同時使用金流 + 發票 + 物流，建議為各服務使用**不同的 callback URL**，
> 各自回應對應的正確格式。在同一 URL 判斷服務類型雖可行但容易出錯。

### 實作 Callback 的檢查清單

收到通知後，在業務邏輯前，依序檢查：

- [ ] 驗證 CheckMacValue / AES 解密是否通過
- [ ] RtnCode 是否在預期值範圍（AIO: 1=成功, 2=ATM取號, 10100073=CVS取號）
- [ ] 此 MerchantTradeNo 是否已處理過（冪等檢查）
- [ ] **立即回應** `1|OK` 或 `{"TransCode": 1}`（在任何非同步操作之前）
- [ ] 非同步處理業務邏輯（發信、開發票、更新庫存）

## Callback 總覽表

| 服務 | URL 欄位名 | 觸發時機 | 認證方式 | 必須回應 | 重試機制 |
|------|-----------|---------|---------|---------|---------|
| AIO 金流 | ReturnURL | 付款完成 | CheckMacValue (**SHA256**) | `1\|OK` | 每 5-15 分鐘重送，每日最多 4 次（持續天數有上限，重試停止後需手動補查） |
| AIO 金流 | PaymentInfoURL | ATM/CVS/BARCODE 取號完成 | CheckMacValue (SHA256) | `1\|OK` | 同上 |
| AIO 金流 | PeriodReturnURL | 定期定額每期扣款 | CheckMacValue (SHA256) | `1\|OK` | 同上 |
| AIO 金流 | — | BNPL 無卡分期申請結果 | CheckMacValue (SHA256) | `1\|OK` | 同上 |
| AIO 金流 | OrderResultURL | 前端跳轉（非 server-to-server） | CheckMacValue (SHA256) | HTML 頁面 | 不重試 |
| ECPG 站內付 | OrderResultURL | 付款完成 | AES 解密 Data | JSON `{ "TransCode": 1 }` | 約每 2 小時重試（次數未公開）|
| 信用卡幕後授權 | ReturnURL | 授權結果 | AES 解密 Data | JSON `{ "TransCode": 1 }` | 約每 2 小時重試（次數未公開）|
| 非信用卡幕後取號 | ServerReplyURL | ATM/CVS/BARCODE 付款完成 | CheckMacValue (SHA256) | `1\|OK` | 每 5-15 分鐘重送，每日最多 4 次 |
| 國內物流 | ServerReplyURL | 物流狀態變更 | CheckMacValue (**MD5**) | `1\|OK` | 約每 2 小時重試（次數未公開）|
| 國內物流（逆物流） | ServerReplyURL | 逆物流狀態變更 | CheckMacValue (**MD5**) | `1\|OK` | 約每 2 小時重試（次數未公開）|
| 國內物流 | ClientReplyURL | 消費者選店結果（前端跳轉） | CheckMacValue (MD5) | HTML 頁面 | 不重試 |
| 全方位物流 | ServerReplyURL | 物流狀態變更 | AES 解密 | AES 加密 JSON | 約每 2 小時重試（次數未公開）|
| 跨境物流 | ServerReplyURL | 物流狀態變更 | AES 解密 | AES 加密 JSON（與全方位物流相同） | 約每 2 小時重試（次數未公開）|
| 電子票證 | NotifyURL | 退款/核退通知 | AES 解密 Data | `1\|OK` | 約每 2 小時重試（次數未公開）|
| 電子發票 | — | 通常由 API 主動查詢 | AES 解密 | JSON | — |

> **重試觸發條件**：HTTP 超時、回應非 200 狀態碼、或回應格式不符（如應回 `1|OK` 但回了其他內容）時觸發重試。AIO 的重試次數有上限（每日 4 次），其他服務的重試上限未公開，建議實作冪等處理（見下方 §冪等性處理建議）。

## Callback 認證方式速查

收到 Callback 時，用以下速查判斷該用哪種驗證方式：

| 你收到的格式 | 有什麼欄位 | 該用哪種驗證 | 參考 |
|-------------|-----------|------------|------|
| Form POST (URL-encoded) | 含 `CheckMacValue` | SHA256（金流）或 MD5（物流） | [guides/13](./13-checkmacvalue.md) |
| JSON POST | 含 `Data`（Base64 字串） | AES 解密 | [guides/14](./14-aes-encryption.md) |

> **最常見錯誤**：國內物流的 CheckMacValue 使用 **MD5**（不是 SHA256）。用錯雜湊演算法會導致驗證永遠失敗。
> - 金流 AIO → SHA256
> - 國內物流 → MD5
> - ECPG / 發票 / 全方位物流 / 跨境物流 / 票證 → AES 解密（無 CheckMacValue）

## AIO ReturnURL — 付款成功通知

**觸發時機**：消費者完成付款後，ECPay 主動 POST 到你的 Server。

**HTTP 方法**：POST（application/x-www-form-urlencoded）

**回傳欄位**：

| 欄位 | 說明 |
|------|------|
| MerchantID | 特店編號 |
| MerchantTradeNo | 特店交易編號 |
| RtnCode | 交易狀態碼（**1=成功**） |
| RtnMsg | 交易訊息 |
| TradeNo | 綠界交易編號 |
| TradeAmt | 交易金額 |
| PaymentDate | 付款時間 |
| PaymentType | 付款方式 |
| PaymentTypeChargeFee | 手續費 |
| TradeDate | 交易日期 |
| SimulatePaid | 是否為模擬付款（0=否, 1=是） |
| CheckMacValue | 檢查碼 |

**處理流程**：

1. 解析 POST 參數
2. 驗證 CheckMacValue（見 [guides/13-checkmacvalue.md](./13-checkmacvalue.md)）
3. 確認 RtnCode=1（付款成功）
4. 確認 SimulatePaid=0（非模擬付款）
5. 更新訂單狀態（使用 upsert 確保冪等性）
6. 回應純字串 `1|OK`

```php
$factory = new Factory([
    'hashKey' => 'pwFHCqoQZGmho4w6',
    'hashIv'  => 'EkRm7iFT261dpevs',
]);
$checkoutResponse = $factory->create(VerifiedArrayResponse::class);
$result = $checkoutResponse->get($_POST);  // 自動驗證 CheckMacValue

if ($result['RtnCode'] === '1') {
    if ($result['SimulatePaid'] === '0') {
        // 真實付款，處理訂單
    }
}
echo '1|OK';  // 必須回應
```

**ReturnURL 重要限制**：

- 必須回應純字串 `1|OK`
- 不可放在 CDN 後面
- 僅支援 80/443 埠
- 非 ASCII 域名需用 punycode
- TLS 1.2 必須
- 不可含特殊字元（分號、管道、反引號）

## AIO PaymentInfoURL — 取號通知（ATM/CVS/BARCODE）

**觸發時機**：ATM 虛擬帳號、超商代碼、條碼產生後通知。

**HTTP 方法**：POST（application/x-www-form-urlencoded）

> **重要**：取號成功的 RtnCode **不是 1**。

**取號成功 RtnCode 對應**：

| 付款方式 | 取號成功 RtnCode |
|---------|-----------------|
| ATM | `2` |
| CVS | `10100073` |
| BARCODE | `10100073` |

**各付款方式額外欄位**：

| 付款方式 | 額外欄位 |
|---------|---------|
| ATM | BankCode（銀行代碼）, vAccount（虛擬帳號）, ExpireDate（繳費期限） |
| CVS | PaymentNo（繳費代碼）, ExpireDate |
| BARCODE | Barcode1, Barcode2, Barcode3, ExpireDate |

**共用欄位**（與 ReturnURL 相同的基礎欄位）：

| 欄位 | 說明 |
|------|------|
| MerchantID | 特店編號 |
| MerchantTradeNo | 特店交易編號 |
| RtnCode | 取號狀態碼（見上表） |
| RtnMsg | 回應訊息 |
| TradeNo | 綠界交易編號 |
| TradeAmt | 交易金額 |
| TradeDate | 交易日期 |
| PaymentType | 付款方式 |
| CheckMacValue | 檢查碼 |

**處理流程**：

1. 解析 POST 參數
2. 驗證 CheckMacValue
3. 根據付款方式檢查 RtnCode（ATM=2, CVS/BARCODE=10100073）
4. 儲存繳費資訊（帳號/代碼/條碼）
5. 通知消費者繳費資訊（Email/推播等）
6. 回應純字串 `1|OK`

> **PaymentInfoURL vs ReturnURL**：ATM/CVS/BARCODE 是非同步付款流程。`PaymentInfoURL` 接收取號結果，`ReturnURL` 接收實際付款結果（RtnCode=1）。兩者都會被呼叫。

## AIO PeriodReturnURL — 定期定額通知

**觸發時機**：每期自動扣款完成後通知。

**HTTP 方法**：POST（application/x-www-form-urlencoded）

**回傳欄位**：

| 欄位 | 說明 |
|------|------|
| MerchantID | 特店編號 |
| MerchantTradeNo | 特店交易編號 |
| RtnCode | 交易狀態碼（1=成功） |
| RtnMsg | 交易訊息 |
| Amount | 本次授權金額 |
| Gwsr | 授權交易單號 |
| AuthCode | 授權碼 |
| ProcessDate | 處理時間（yyyy/MM/dd HH:mm:ss） |
| PeriodType | 週期類型（D=天, M=月, Y=年） |
| Frequency | 執行頻率 |
| ExecTimes | 總執行次數 |
| FirstAuthAmount | 初次授權金額 |
| TotalSuccessTimes | 已成功扣款次數 |
| SimulatePaid | 是否為模擬付款（0=否, 1=是） |
| CheckMacValue | 檢查碼 |

> 完整回傳欄位見 references/Payment/全方位金流API技術文件.md §定期定額付款結果通知。

**處理流程**：

1. 解析 POST 參數
2. 驗證 CheckMacValue
3. 確認 RtnCode=1（扣款成功）
4. 更新訂閱狀態與已扣款次數
5. 判斷 TotalSuccessTimes 是否等於 ExecTimes（訂閱結束）
6. 回應純字串 `1|OK`

**建立定期定額訂單的關鍵參數**：

| 參數 | 說明 |
|------|------|
| PeriodAmount | 每期金額 |
| PeriodType | 週期類型（D=天, M=月, Y=年） |
| Frequency | 每 N 個週期執行一次 |
| ExecTimes | 共執行幾次 |
| PeriodReturnURL | 每期扣款通知 URL |

## AIO BNPL 無卡分期申請結果通知

**觸發時機**：消費者完成 BNPL（裕富/中租）無卡分期審核後，綠界 POST 通知。

**HTTP 方法**：POST（application/x-www-form-urlencoded）

**回傳格式**：與一般 AIO Callback 相同（URL-encoded POST），需驗證 CheckMacValue。

**關鍵欄位**：

| 欄位 | 說明 |
|------|------|
| RtnCode | 交易狀態碼（**2=申請中**，非 1） |
| BNPLTradeNo | 無卡分期申請交易編號 |
| BNPLInstallment | 分期期數 |
| CheckMacValue | 檢查碼 |

> **注意**：BNPL 申請結果的 `RtnCode=2` 代表「申請中」，與 ATM 取號的 `RtnCode=2` 含義不同。
> 完整回傳欄位見 references/Payment/全方位金流API技術文件.md §無卡分期申請結果通知。

**處理流程**：

1. 解析 POST 參數
2. 驗證 CheckMacValue
3. 確認 RtnCode=2（申請中）
4. 記錄 BNPLTradeNo 與分期期數
5. 回應純字串 `1|OK`

## ECPG OrderResultURL — 站內付結果

**觸發時機**：站內付交易完成後通知。

**HTTP 方法**：POST（application/json）

**外層 JSON 結構**：

```json
{
    "MerchantID": "3002607",
    "RpHeader": { "Timestamp": 1234567890 },
    "TransCode": 1,
    "TransMsg": "Success",
    "Data": "AES加密後的Base64字串"
}
```

**外層欄位**：

| 欄位 | 說明 |
|------|------|
| MerchantID | 特店編號 |
| RpHeader.Timestamp | 回應時間戳 |
| TransCode | 傳輸狀態碼（1=成功） |
| TransMsg | 傳輸訊息 |
| Data | AES 加密的交易資料（Base64 字串） |

**Data 解密後欄位**：

| 欄位 | 說明 |
|------|------|
| RtnCode | 交易狀態碼（1=成功） |
| RtnMsg | 交易訊息 |
| MerchantID | 特店編號 |
| MerchantTradeNo | 特店交易編號 |
| TradeNo | 綠界交易編號 |
| TradeAmt | 交易金額 |
| PaymentDate | 付款時間 |
| PaymentType | 付款方式 |
| Token | 付款 Token |
| TokenExpireDate | Token 到期日 |

**處理流程**：

1. 解析 JSON body
2. 檢查外層 TransCode（1=傳輸成功）
3. AES 解密 Data 欄位（見 [guides/14-aes-encryption.md](./14-aes-encryption.md)）
4. 檢查內層 RtnCode（1=交易成功）
5. 更新訂單狀態
6. 回應 JSON `{ "TransCode": 1 }`

```php
$aesService = $factory->create(AesService::class);

// 先檢查 TransCode 確認 API 是否成功
$transCode = $_POST['TransCode'] ?? null;
if ($transCode != 1) {
    error_log('ECPay TransCode Error: ' . ($_POST['TransMsg'] ?? 'unknown'));
}

// 解密 Data 取得交易細節
$decryptedData = $aesService->decrypt($_POST['Data']);
// $decryptedData 包含：RtnCode, RtnMsg, MerchantID, Token, TokenExpireDate 等
```

> **兩層檢查**：ECPG 需要檢查兩層狀態碼。TransCode 代表「傳輸是否成功」，RtnCode 代表「交易是否成功」。兩者都為 1 才算完全成功。

## 物流 ServerReplyURL — 物流狀態變更

**觸發時機**：物流狀態每次變更時（建單、出貨、配達、退貨等）。

### 國內物流（CMV-MD5 — CheckMacValue MD5）

**HTTP 方法**：POST（application/x-www-form-urlencoded）

**回傳欄位**：

| 欄位 | 說明 |
|------|------|
| AllPayLogisticsID | 綠界物流交易編號 |
| MerchantTradeNo | 特店交易編號 |
| RtnCode | 物流狀態碼（1=成功） |
| RtnMsg | 狀態訊息 |
| LogisticsType | 物流類型（CVS=超商, HOME=宅配） |
| LogisticsSubType | 物流子類型（FAMI/UNIMART/HILIFE/OKMART/TCAT/POST） |
| CheckMacValue | 檢查碼（MD5） |

```php
use Ecpay\Sdk\Response\VerifiedArrayResponse;
$factory = new Factory([
    'hashKey'    => '5294y06JbISpM5x9',
    'hashIv'     => 'v77hoKGq4kWxNNIS',
    'hashMethod' => 'md5',  // 重要：國內物流用 MD5
]);
$verifiedResponse = $factory->create(VerifiedArrayResponse::class);
$result = $verifiedResponse->get($_POST);
// $result 包含：AllPayLogisticsID, MerchantTradeNo, RtnCode, RtnMsg, LogisticsType, LogisticsSubType 等
echo '1|OK';
```

> **注意**：國內物流的 CheckMacValue 使用 **MD5**（不是 SHA256）。與 AIO 金流的加密方式不同！

### 全方位物流（AES-JSON — AES 加密 JSON）

**HTTP 方法**：POST（application/json）

全方位物流的通知是 AES 加密的 JSON（不是 Form POST）。回應也需要 AES 加密。

**接收與回應範例**：

```php
use Ecpay\Sdk\Response\AesJsonResponse as AesParser;
use Ecpay\Sdk\Request\AesRequest as AesGenerater;

// 接收通知
$aesParser = $factory->create(AesParser::class);
$parsedRequest = $aesParser->get(file_get_contents('php://input'));

// 回應（也需要 AES 加密）
$aesGenerater = $factory->create(AesGenerater::class);
$data = [
    'RtnCode' => '1',
    'RtnMsg'  => '',
];
$responseData = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time()],
    'TransCode'  => '1',
    'TransMsg'   => '',
    'Data'       => $data,
];
$response = $aesGenerater->get($responseData);
echo json_encode($response);
```

> **關鍵差異**：全方位物流的 callback 回應也需要 AES 加密成 JSON 格式，而非純字串 `1|OK`。

### 全方位物流 / 跨境物流 Callback 回應格式

收到全方位物流或跨境物流的 callback 時，需要 **AES 解密**後處理，並回應 **AES 加密的 JSON**：

**收到的 callback body**（JSON POST）：
```json
{
  "MerchantID": "2000132",
  "RpHeader": { "Timestamp": 1234567890 },
  "TransCode": 1,
  "TransMsg": "Success",
  "Data": "AES加密的Base64字串（解密後為物流狀態資料）"
}
```

**你必須回應的格式**（AES 加密 JSON）：
```json
{
  "MerchantID": "2000132",
  "RqHeader": { "Timestamp": 1234567890 },
  "Data": "AES加密({"RtnCode": 1, "RtnMsg": "OK"})"
}
```

> **重要**：全方位/跨境物流的 callback 回應**不是** `1|OK`，而是 AES 加密的 JSON 三層結構。
> 這與國內物流（回 `1|OK`）和 ECPG（回 `{ "TransCode": 1 }`）都不同。
> AES 加解密實作見 [guides/14](./14-aes-encryption.md)。

**物流狀態碼參考**：`scripts/SDK_PHP/example/Logistics/logistics_status.xlsx` 和 `logistics_history.xlsx`

## 逆物流 ServerReplyURL — 逆物流狀態通知

**觸發時機**：退貨物流狀態變更時，綠界 POST 通知到逆物流建單時設定的 `ServerReplyURL`。

**HTTP 方法**：POST（application/x-www-form-urlencoded）

**回傳欄位**：

| 欄位 | 說明 |
|------|------|
| MerchantID | 特店編號 |
| RtnMerchantTradeNo | 特店逆物流交易編號 |
| RtnCode | 物流狀態碼 |
| RtnMsg | 物流狀態說明 |
| AllPayLogisticsID | 綠界物流交易編號 |
| GoodsAmount | 商品金額（用於遺失賠償） |
| UpdateStatusDate | 狀態更新時間 |
| BookingNote | 托運單號（僅宅配） |
| CheckMacValue | 檢查碼（MD5） |

> **注意**：逆物流的 `LogisticsStatus` 為逆物流專用狀態碼，與正物流不同。
> 完整欄位與狀態碼見 references/Logistics/物流整合API技術文件.md §逆物流狀態通知。

**處理流程**：

1. 解析 POST 參數
2. 驗證 CheckMacValue（MD5）
3. 根據 RtnCode 更新退貨物流狀態
4. 回應純字串 `1|OK`

## 物流 ClientReplyURL — 消費者選店結果

**觸發時機**：消費者在 ECPay 地圖選擇超商門市後，前端跳轉回來。

**注意**：這是前端跳轉，非 server-to-server callback。

### 國內物流（電子地圖選店）

```php
use Ecpay\Sdk\Response\ArrayResponse;
$arrayResponse = $factory->create(ArrayResponse::class);
$result = $arrayResponse->get($_POST);
// $result 包含：CVSStoreID, CVSStoreName, CVSAddress, CVSTelephone 等
```

**回傳欄位**：

| 欄位 | 說明 |
|------|------|
| CVSStoreID | 門市代碼 |
| CVSStoreName | 門市名稱 |
| CVSAddress | 門市地址 |
| CVSTelephone | 門市電話 |
| MerchantTradeNo | 特店交易編號 |

### 全方位物流（RWD 物流選擇頁）

消費者選擇完物流後，ClientReplyURL 收到 AES 加密的結果：

```php
use Ecpay\Sdk\Response\AesJsonResponse;
$aesJsonResponse = $factory->create(AesJsonResponse::class);
$result = $aesJsonResponse->get($_POST['ResultData']);
// $result 包含 TempLogisticsID
```

**回傳欄位**：

| 欄位 | 說明 |
|------|------|
| TempLogisticsID | 暫存物流 ID（用於後續 UpdateTempTrade / CreateByTempTrade） |

## 多語言 Webhook Handler 範例

### Node.js — 生產等級 ReturnURL Handler

```javascript
const express = require('express');
const crypto = require('crypto');
const app = express();
app.use(express.urlencoded({ extended: true }));

// CheckMacValue 計算（完整實作見 guides/13）
function ecpayUrlEncode(source) {
  let encoded = encodeURIComponent(source).replace(/%20/g, '+').replace(/~/g, '%7e');
  encoded = encoded.toLowerCase();
  const replacements = { '%2d': '-', '%5f': '_', '%2e': '.', '%21': '!', '%2a': '*', '%28': '(', '%29': ')' };
  for (const [old, char] of Object.entries(replacements)) {
    encoded = encoded.split(old).join(char);
  }
  return encoded;
}

function generateCheckMacValue(params, hashKey, hashIv) {
  const filtered = Object.entries(params).filter(([k]) => k !== 'CheckMacValue');
  const sorted = filtered.sort((a, b) => a[0].toLowerCase().localeCompare(b[0].toLowerCase()));
  const paramStr = sorted.map(([k, v]) => `${k}=${v}`).join('&');
  const raw = `HashKey=${hashKey}&${paramStr}&HashIV=${hashIv}`;
  return crypto.createHash('sha256').update(ecpayUrlEncode(raw), 'utf8').digest('hex').toUpperCase();
}

app.post('/ecpay/notify', (req, res) => {
  const HASH_KEY = process.env.ECPAY_HASH_KEY;
  const HASH_IV = process.env.ECPAY_HASH_IV;
  const MY_MERCHANT_ID = process.env.ECPAY_MERCHANT_ID;

  // 1. 驗證 CheckMacValue
  const cmv = generateCheckMacValue(req.body, HASH_KEY, HASH_IV);
  if (!crypto.timingSafeEqual(Buffer.from(cmv), Buffer.from(req.body.CheckMacValue || ''))) {
    console.error('CheckMacValue 驗證失敗');
    return res.send('0|CheckMacValue Error');
  }

  // 2. 驗證 MerchantID
  if (req.body.MerchantID !== MY_MERCHANT_ID) {
    console.error('MerchantID 不符');
    return res.send('0|MerchantID Error');
  }

  // 3. 檢查 SimulatePaid（正式環境拒絕模擬付款）
  if (process.env.NODE_ENV === 'production' && req.body.SimulatePaid === '1') {
    console.warn('正式環境收到模擬付款，忽略');
    return res.send('1|OK');
  }

  // 4. 冪等性處理（upsert）
  if (req.body.RtnCode === '1') {
    // INSERT ... ON CONFLICT DO NOTHING（見上方冪等性 SQL）
    // 比對金額與本地訂單記錄
    console.log(`付款成功: ${req.body.MerchantTradeNo}, 金額: ${req.body.TradeAmt}`);
  }

  // 5. 必須回應
  res.send('1|OK');
});
```

### Python — 生產等級 ReturnURL Handler

```python
from fastapi import FastAPI, Request
import hashlib, urllib.parse, hmac, os

app = FastAPI()

HASH_KEY = os.environ['ECPAY_HASH_KEY']
HASH_IV = os.environ['ECPAY_HASH_IV']
MY_MERCHANT_ID = os.environ['ECPAY_MERCHANT_ID']

def ecpay_url_encode(source: str) -> str:
    encoded = urllib.parse.quote_plus(source).replace('~', '%7e').lower()
    for old, new in {'%2d': '-', '%5f': '_', '%2e': '.', '%21': '!', '%2a': '*', '%28': '(', '%29': ')'}.items():
        encoded = encoded.replace(old, new)
    return encoded

def generate_cmv(params: dict) -> str:
    filtered = {k: v for k, v in params.items() if k != 'CheckMacValue'}
    sorted_params = sorted(filtered.items(), key=lambda x: x[0].lower())
    param_str = '&'.join(f'{k}={v}' for k, v in sorted_params)
    raw = f"HashKey={HASH_KEY}&{param_str}&HashIV={HASH_IV}"
    return hashlib.sha256(ecpay_url_encode(raw).encode('utf-8')).hexdigest().upper()

@app.post('/ecpay/notify')
async def notify(request: Request):
    form = dict(await request.form())

    # 1. 驗證 CheckMacValue（timing-safe）
    expected = generate_cmv(form)
    if not hmac.compare_digest(expected, form.get('CheckMacValue', '')):
        return '0|CheckMacValue Error'

    # 2. 驗證 MerchantID
    if form.get('MerchantID') != MY_MERCHANT_ID:
        return '0|MerchantID Error'

    # 3. 檢查 SimulatePaid（正式環境拒絕模擬付款）
    if os.environ.get('ENV') == 'production' and form.get('SimulatePaid') == '1':
        return '1|OK'

    # 4. 冪等性處理 + 金額比對
    if form.get('RtnCode') == '1':
        # INSERT ... ON CONFLICT DO NOTHING
        # 比對 TradeAmt 與本地訂單金額
        pass

    return '1|OK'
```

> **安全清單**（上方範例已包含）：
> 1. CheckMacValue 驗證（timing-safe 比較）
> 2. MerchantID 驗證（確認是自己的訂單）
> 3. SimulatePaid 檢查（正式環境拒絕模擬付款）
> 4. 冪等性（upsert 防重複處理）
> 5. 金額比對（防止金額被竄改）
> 6. HashKey/HashIV 從環境變數讀取（禁止硬編碼）

## Callback 安全必做清單

### 1. 驗證來源

| 認證模式 | 驗證方式 | 適用服務 |
|---------|---------|---------|
| CMV-SHA256 | 計算 CheckMacValue（SHA256）並比對 | AIO 金流 |
| AES-JSON | AES 解密成功即可視為來自 ECPay | ECPG 站內付、全方位物流、電子發票 |
| CMV-MD5 | 計算 CheckMacValue（MD5）並比對 | 國內物流 |

### 2. HTTPS 必須

Callback URL 必須使用 HTTPS（TLS 1.2+）。

### 3. IP 白名單（選用）

ECPay 的 callback 來源 IP 範圍可至特店後台查詢，可作為額外的安全防線。

### 4. 防重放攻擊

記錄已處理的 MerchantTradeNo / AllPayLogisticsID，避免重複處理。

> **時間窗口建議**：對 AES-JSON 服務（ECPG/發票/物流 v2），可驗證解密後的 `RpHeader.Timestamp` 與伺服器時間差距在 ±5 分鐘內，超出則拒絕。對 CMV-SHA256（AIO），檢查 `MerchantTradeDate` 時間差距作為輔助驗證。

### 5. 超時控制

Callback handler 必須在 10 秒內回應，否則 ECPay 視為失敗。

### 6. 物流 ServerReplyURL 安全清單

> 來源：guides/06-logistics-domestic.md 及 guides/07-logistics-allinone.md

1. 驗證 MerchantID 為自己的
2. 比對物流單號與訂單記錄
3. 防重複處理（記錄已處理的 AllPayLogisticsID）
4. 異常時仍回應 `1|OK`（避免重送風暴）
5. 記錄完整日誌（遮蔽 HashKey/HashIV）

## 冪等性實作建議

Callback 可能因 ECPay 重試而重複到達。你的處理邏輯必須具備冪等性——重複處理同一筆通知不應產生副作用。

### 冪等鍵設計

使用 `MerchantTradeNo`（金流）或 `AllPayLogisticsID`（物流）作為冪等鍵。

### SQL Upsert 範例

```sql
-- 金流 Callback 冪等處理
INSERT INTO payment_notifications (merchant_trade_no, rtn_code, trade_amt, payment_date, raw_data)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (merchant_trade_no) DO UPDATE SET
  rtn_code = EXCLUDED.rtn_code,
  updated_at = NOW()
WHERE payment_notifications.rtn_code != '1';  -- 已成功的不覆蓋
```

```sql
-- 物流 callback 冪等性
-- 物流狀態會多次變更，用 (allpay_logistics_id, rtn_code) 組合做 PRIMARY KEY
INSERT INTO logistics_callbacks (allpay_logistics_id, rtn_code, merchant_trade_no, logistics_type, logistics_sub_type, raw_payload)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (allpay_logistics_id, rtn_code) DO NOTHING;
```

> 上方範例為 PostgreSQL 語法（`$1` 佔位符 + `ON CONFLICT`）。其他資料庫等價寫法：

#### MySQL 等價寫法

```sql
INSERT INTO payment_notifications (merchant_trade_no, status, received_at)
VALUES ('MN20240301001', 'paid', NOW())
ON DUPLICATE KEY UPDATE status = VALUES(status);
```

#### SQLite 等價寫法

```sql
INSERT OR IGNORE INTO payment_notifications (merchant_trade_no, status, received_at)
VALUES ('MN20240301001', 'paid', datetime('now'));
```

### Node.js 冪等 Callback Handler

```javascript
app.post('/ecpay/notify', async (req, res) => {
  // 1. 驗證 CheckMacValue
  if (!verifyCheckMacValue(req.body)) {
    return res.status(400).send('Invalid CheckMacValue');
  }

  // 2. 冪等 Upsert（防重複）
  const result = await db.query(
    `INSERT INTO notifications (trade_no, status) VALUES ($1, $2)
     ON CONFLICT (trade_no) DO NOTHING RETURNING *`,
    [req.body.MerchantTradeNo, req.body.RtnCode]
  );

  // 3. 僅新插入時處理業務邏輯
  if (result.rowCount > 0) {
    await processOrder(req.body);
  }

  // 4. 立即回應（無論是否已處理過）
  res.send('1|OK');
});
```

### 設計原則

1. **先存後處理**：收到 Callback 立即存入 DB，再做業務邏輯
2. **Upsert 而非 Insert**：用 `ON CONFLICT` 防止重複插入
3. **已成功不覆蓋**：已標記為成功的交易不應被後續 Callback 覆蓋
4. **永遠回應**：無論是否已處理過，都回應 `1|OK`，否則 ECPay 會持續重送

## 重試機制說明

ECPay 的 callback 重試行為：

| 服務 | 重試頻率 | 每日次數 | 持續天數 |
|------|---------|---------|---------|
| AIO 金流 | 每 5-15 分鐘 | 最多 4 次 | 持續數天 |
| ECPG 站內付 | 約每 2 小時 | 約 4 次 | 持續數天 |
| 國內物流 | 約每 2 小時 | 約 4 次 | 持續數天 |
| 全方位物流 | 約每 2 小時 | 約 4 次 | 持續數天 |

**重試觸發條件**：

- 你的 server 未回應正確格式（`1|OK` 或對應 JSON）
- HTTP 回應碼非 200
- 連線逾時（超過 10 秒）

**建議**：同時實作主動查詢（QueryTradeInfo）作為補充機制，不要完全依賴 callback。

## 失敗恢復策略

當你的 server 錯過 callback 時：

### 1. 主動查詢

使用對應的 QueryTrade API 主動查詢訂單狀態：

| 服務 | 查詢端點 |
|------|---------|
| AIO 金流 | `/Cashier/QueryTradeInfo/V5` |
| AIO 取號結果 | `/Cashier/QueryPaymentInfo` |
| ECPG 站內付 | `/1.0.0/Cashier/QueryTrade` |
| 國內物流 | `/Helper/QueryLogisticsTradeInfo/V5` |
| 全方位物流 | `/Express/v2/QueryLogisticsTradeInfo` |

### 2. 對帳檔

每日下載對帳檔比對（見 [guides/01-payment-aio.md](./01-payment-aio.md) 對帳區塊）：

| 功能 | 端點 |
|------|------|
| 交易對帳檔下載 | `/PaymentMedia/TradeNoAio` |
| 信用卡撥款對帳 | `/CreditDetail/FundingReconDetail` |

### 3. 監控告警

設定 callback 接收頻率監控，異常時觸發告警。建議監控項目：

- Callback 接收頻率驟降
- RtnCode 非成功的比例異常
- CheckMacValue / AES 解密驗證失敗率上升
- 回應時間接近 10 秒上限

### 4. 程式化失敗恢復

當排程掃描發現未確認訂單時，主動查詢 ECPay API 確認實際狀態。

**恢復策略**：

| 步驟 | 動作 | 注意事項 |
|------|------|---------|
| 1 | 查詢超過 5 分鐘未確認的訂單 | `LIMIT 100` 避免 API 限流 |
| 2 | 呼叫 QueryTradeInfo/V5（AIO）或解密 callback | 使用 [guides/13](./13-checkmacvalue.md) 的 CMV 函式 |
| 3 | 比對 `TradeStatus=1` 更新訂單狀態 | 間隔 200ms + jitter 避免限流 |
| 4 | 每 5 分鐘排程掃描 | Python: `schedule`，Node.js: `setInterval`，Java: `@Scheduled` |

```sql
-- 待確認訂單查詢 SQL
SELECT merchant_trade_no FROM orders
WHERE status = 'pending'
  AND created_at < NOW() - INTERVAL '5 minutes'
ORDER BY created_at ASC
LIMIT 100;  -- 每次最多處理 100 筆，避免 API 限流
```

## 消費爭議（Dispute / Chargeback）處理

### 處理流程

消費爭議通常由信用卡持卡人向發卡銀行提出，綠界會通知特店進行舉證。

| 步驟 | 動作 | 時限 |
|------|------|------|
| 1 | 收到綠界消費爭議通知（email/電話） | — |
| 2 | 準備交易證據（訂單記錄、出貨證明、物流簽收記錄、客服對話記錄） | 通常 7-14 天 |
| 3 | 透過綠界特店後台或客服回覆舉證資料 | 依通知時限 |
| 4 | 綠界轉交發卡銀行審理 | 約 30-90 天 |
| 5 | 結果通知（勝訴維持交易 / 敗訴退款） | — |

### 預防措施

- 保留所有交易記錄和物流配送證明至少 180 天
- 商品描述與實際出貨一致，避免消費者因「貨不對版」提出爭議
- 大額交易建議使用 3D Secure 驗證（已強制實施）
- 退款申請儘速處理，避免消費者直接向銀行申請 chargeback

### 程式化建議

```sql
-- 交易證據保留表
CREATE TABLE transaction_evidence (
  merchant_trade_no VARCHAR(20) PRIMARY KEY,
  order_details JSONB,          -- 訂單明細
  shipping_proof TEXT,           -- 物流追蹤號/簽收記錄
  customer_communication TEXT,   -- 客服對話摘要
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  retained_until TIMESTAMP DEFAULT CURRENT_TIMESTAMP + INTERVAL '180 days'
);
```

> **注意**：消費爭議的具體通知格式和流程依綠界與各銀行的合約而異。建議向綠界客服 (02-2655-1775) 確認最新的爭議處理規範。

## 相關文件

- [guides/01-payment-aio.md](./01-payment-aio.md) — AIO 金流完整指南
- [guides/02-payment-ecpg.md](./02-payment-ecpg.md) — ECPG 站內付指南
- [guides/06-logistics-domestic.md](./06-logistics-domestic.md) — 國內物流指南
- [guides/07-logistics-allinone.md](./07-logistics-allinone.md) — 全方位物流指南
- [guides/13-checkmacvalue.md](./13-checkmacvalue.md) — CheckMacValue 驗證
- [guides/14-aes-encryption.md](./14-aes-encryption.md) — AES 加解密
- [guides/21-error-codes-reference.md](./21-error-codes-reference.md) — 錯誤碼參考
