> 對應 ECPay API 版本 | 基於 PHP SDK ecpay/sdk | 最後更新：2026-03

# 國內物流完整指南

> **讀對指南了嗎？** 需要全方位物流（AES-JSON 協議）→ [guides/07](./07-logistics-allinone.md)。跨境物流 → [guides/08](./08-logistics-crossborder.md)。需要收款而非出貨 → [guides/01 AIO](./01-payment-aio.md)。

## 概述

國內物流支援超商取貨（全家/統一/萊爾富/OK）和宅配（黑貓/郵局）。使用 CheckMacValue **MD5** 加密（注意不是 SHA256）。

## 前置需求

- B2B 測試帳號：MerchantID `2000132` / HashKey `5294y06JbISpM5x9` / HashIV `v77hoKGq4kWxNNIS`
- C2C 測試帳號：MerchantID `2000933` / HashKey `XBERn1YOvpM9nfZc` / HashIV `h1ONHk4P4yqbl5LK`
- 加密方式：CheckMacValue **MD5**（與金流不同！）
- 基礎端點：`https://logistics-stage.ecpay.com.tw/`

```php
$factory = new Factory([
    'hashKey'    => '5294y06JbISpM5x9',
    'hashIv'     => 'v77hoKGq4kWxNNIS',
    'hashMethod' => 'md5',  // 重要：國內物流用 MD5
]);
```

### 物流測試帳號對應

| 服務類型 | 測試 MerchantID | 說明 |
|---------|----------------|------|
| B2C 超商 | 2000132 | 統一超商、全家、萊爾富、OK |
| C2C 超商 | 2000933 | 消費者寄件（超商交貨便）|
| 宅配 | 2000132 | 黑貓宅急便、中華郵政 |

> 注意：實際測試帳號以綠界官方文件為準，不同物流類型可能使用不同測試帳號。

## HTTP 協議速查（非 PHP 語言必讀）

| 項目 | 規格 |
|------|------|
| 協議模式 | CMV-MD5 — 詳見 [guides/20-http-protocol-reference.md](./20-http-protocol-reference.md) |
| HTTP 方法 | POST |
| Content-Type | `application/x-www-form-urlencoded` |
| 認證 | CheckMacValue（**MD5**，非 SHA256） — 詳見 [guides/13-checkmacvalue.md](./13-checkmacvalue.md) |
| 測試環境 | `https://logistics-stage.ecpay.com.tw` |
| 正式環境 | `https://logistics.ecpay.com.tw` |
| 回應格式 | 依端點不同：pipe-separated / URL-encoded / JSON / HTML / plain text |
| Callback | Form POST 至 ServerReplyURL，必須回應 `1|OK` |

> **重要**：國內物流的 CheckMacValue 使用 **MD5**（不是 SHA256）。與 AIO 金流的加密方式不同！

> ⚠️ **SNAPSHOT 2026-03** | 來源：`references/Logistics/物流整合API技術文件.md`
> 以下端點及參數僅供整合流程理解，不可直接作為程式碼生成依據。**生成程式碼前必須 web_fetch 來源文件取得最新規格。**

### 端點 URL 一覽

| 功能 | 端點路徑 | 回應格式 |
|------|---------|---------|
| 測試標籤產生 | `/Express/CreateTestData` | pipe-separated |
| 門市電子地圖 | `/Express/map` | HTML |
| 門市訂單建立 | `/Express/Create` | pipe-separated |
| 宅配訂單建立 | `/Express/Create` | pipe-separated |
| 列印 C2C 7-ELEVEN | `/Express/PrintUniMartC2COrderInfo` | HTML |
| 列印 C2C 全家 | `/Express/PrintFAMIC2COrderInfo` | HTML |
| 列印 C2C 萊爾富 | `/Express/PrintHILIFEC2COrderInfo` | HTML |
| 列印 C2C OK 超商 | `/Express/PrintOKMARTC2COrderInfo` | HTML |
| 列印 B2C / 測標 / 宅配 | `/helper/printTradeDocument` | HTML |
| 逆物流 B2C 7-ELEVEN | `/express/ReturnUniMartCVS` | pipe-separated |
| 逆物流 B2C 全家 | `/express/ReturnCVS` | pipe-separated |
| 逆物流 B2C 萊爾富 | `/express/ReturnHilifeCVS` | pipe-separated |
| 逆物流宅配 | `/Express/ReturnHome` | plain text `1|OK` |
| 異動 B2C | `/Helper/UpdateShipmentInfo` | plain text `1|OK` |
| 異動 C2C | `/Express/UpdateStoreInfo` | plain text `1|OK` |
| 取消 C2C 7-ELEVEN | `/Express/CancelC2COrder` | plain text `1|OK` |
| 查詢物流訂單 | `/Helper/QueryLogisticsTradeInfo/V5` | URL-encoded |
| 取得門市清單 | `/Helper/GetStoreList` | JSON |

> **冷鏈物流**：部分超商（統一超商、全家）支援冷凍/冷藏配送。相關規格（如 `LogisticsSubType` 冷凍參數）需向綠界確認帳號是否已開通，詳見 `references/Logistics/物流整合API技術文件.md` 查詢官方最新支援說明。

## 物流商支援表

| 代碼 | 物流商 | 類型 | 說明 |
|------|-------|------|------|
| FAMI | 全家 | CVS | 超商取貨 |
| UNIMART | 統一超商 | CVS | 超商取貨 |
| UNIMARTFREEZE | 統一超商（冷凍） | CVS | 冷凍取貨 |
| HILIFE | 萊爾富 | CVS | 超商取貨 |
| OKMART | OK 超商 | CVS | 超商取貨 |
| TCAT | 黑貓宅急便 | HOME | 宅配 |
| POST | 中華郵政 | HOME | 宅配 |

## 電子地圖選店

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/Map.php`

讓消費者在地圖上選擇取貨門市：

```php
$autoSubmitFormService = $factory->create('AutoSubmitFormWithCmvService');
$input = [
    'MerchantID'      => '2000132',
    'MerchantTradeNo' => 'Log' . time(),
    'LogisticsType'   => 'CVS',
    'LogisticsSubType'=> 'FAMI',       // FAMI/UNIMART/HILIFE/OKMART
    'IsCollection'    => 'N',           // Y=貨到付款, N=僅配送
    'ServerReplyURL'  => 'https://你的網站/ecpay/map-result',
];
echo $autoSubmitFormService->generate($input, 'https://logistics-stage.ecpay.com.tw/Express/map');
```

### 處理選店結果

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/GetMapResponse.php`

```php
use Ecpay\Sdk\Response\ArrayResponse;
$arrayResponse = $factory->create(ArrayResponse::class);
$result = $arrayResponse->get($_POST);
// $result 包含：CVSStoreID, CVSStoreName, CVSAddress, CVSTelephone 等
```

## 超商取貨建單

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/CreateCvs.php`

```php
$postService = $factory->create('PostWithCmvStrResponseService');
$input = [
    'MerchantID'       => '2000132',
    'MerchantTradeNo'  => 'CVS' . time(),
    'MerchantTradeDate'=> date('Y/m/d H:i:s'),
    'LogisticsType'    => 'CVS',
    'LogisticsSubType' => 'FAMI',
    'GoodsAmount'      => 100,
    'GoodsName'        => '測試商品',
    'SenderName'       => '寄件人',
    'SenderCellPhone'  => '0912345678',
    'ReceiverName'     => '收件人',
    'ReceiverCellPhone'=> '0987654321',
    'ServerReplyURL'   => 'https://你的網站/ecpay/logistics-notify',
    'ReceiverStoreID'  => '門市代碼',  // 從電子地圖取得
];

try {
    $response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/Create');
    // 回應包含 AllPayLogisticsID（物流交易編號）和 CVSPaymentNo（超商寄貨編號）
} catch (\Exception $e) {
    error_log('ECPay Logistics Create Error: ' . $e->getMessage());
}
```

#### 超商建單回傳欄位

| 欄位 | 說明 |
|------|------|
| AllPayLogisticsID | 綠界物流交易編號（後續查詢、列印、退貨用） |
| CVSPaymentNo | 超商寄貨編號 |
| CVSValidationNo | 驗證碼（統一超商退貨用） |
| MerchantTradeNo | 特店交易編號（你送出的） |
| RtnCode | 回應代碼（1=成功） |
| RtnMsg | 回應訊息 |

### 表單模式建單

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/CreateCvsForm.php`

同樣參數但使用 `AutoSubmitFormWithCmvService`，多一個 `ClientReplyURL`。

### 統一超商冷凍取貨

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/CreateUnimartFreeze.php`

`LogisticsSubType` 改為 `UNIMARTFREEZE`，其餘同一般超商取貨。

## 宅配建單

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/CreateHome.php`

```php
$input = [
    'MerchantID'          => '2000132',
    'MerchantTradeNo'     => 'HOME' . time(),
    'MerchantTradeDate'   => date('Y/m/d H:i:s'),
    'LogisticsType'       => 'HOME',
    'LogisticsSubType'    => 'TCAT',       // TCAT=黑貓, POST=郵局
    'GoodsAmount'         => 100,
    'GoodsName'           => '測試商品',
    'SenderName'          => '寄件人',
    'SenderCellPhone'     => '0912345678',
    'SenderZipCode'       => '106',
    'SenderAddress'       => '台北市大安區測試路1號',
    'ReceiverName'        => '收件人',
    'ReceiverCellPhone'   => '0987654321',
    'ReceiverZipCode'     => '110',
    'ReceiverAddress'     => '台北市信義區測試路2號',
    'Temperature'         => '0001',       // 0001=常溫, 0002=冷藏, 0003=冷凍
    'Distance'            => '00',         // 00=同縣市, 01=外縣市, 02=離島
    'Specification'       => '0001',       // 0001=60cm, 0002=90cm, 0003=120cm, 0004=150cm
    'ScheduledPickupTime' => '4',          // 4=不限時
    'ScheduledDeliveryTime'=> '4',         // 4=不限時
    'ServerReplyURL'      => 'https://你的網站/ecpay/logistics-notify',
];

try {
    $response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/Create');
    // 回應包含 AllPayLogisticsID（物流交易編號）
} catch (\Exception $e) {
    error_log('ECPay Home Delivery Create Error: ' . $e->getMessage());
}
```

#### 宅配建單回傳欄位

| 欄位 | 說明 |
|------|------|
| AllPayLogisticsID | 綠界物流交易編號 |
| MerchantTradeNo | 特店交易編號 |
| RtnCode | 回應代碼（1=成功） |
| RtnMsg | 回應訊息 |

### 宅配表單模式

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/CreateHomeForm.php`

## 物流狀態通知

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/GetLogisticStatueResponse.php`

物流狀態變更時，綠界 POST 到 ServerReplyURL：

```php
use Ecpay\Sdk\Response\VerifiedArrayResponse;
$verifiedResponse = $factory->create(VerifiedArrayResponse::class);
$result = $verifiedResponse->get($_POST);
// $result 包含：AllPayLogisticsID, MerchantTradeNo, RtnCode, RtnMsg, LogisticsType, LogisticsSubType 等
echo '1|OK';
```

**物流狀態碼參考**：`scripts/SDK_PHP/example/Logistics/logistics_status.xlsx` 和 `logistics_history.xlsx`

## 退貨

### 超商退貨

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/ReturnFamiCvs.php`, `scripts/SDK_PHP/example/Logistics/Domestic/ReturnUniMartCvs.php`

```php
$input = [
    'MerchantID'     => '2000132',
    'GoodsAmount'    => 100,
    'ServiceType'    => '4',
    'SenderName'     => '退貨人',
    'ServerReplyURL' => 'https://你的網站/ecpay/return-notify',
];
// 全家退貨
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/express/ReturnCVS');
// 統一退貨
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/express/ReturnUniMartCVS');
```

> **注意**：超商退貨（CVS Return）建單的回傳結果中不會包含 `AllPayLogisticsID`。
> 需改用 `RtnMerchantTradeNo`（綠界回傳的退貨交易編號）追蹤退貨狀態。
> 退貨物流狀態會透過 `ServerReplyURL` 通知。

### 宅配退貨

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/ReturnHome.php`

```php
$input = [
    'MerchantID'       => '2000132',
    'AllPayLogisticsID'=> '物流編號',
    'GoodsAmount'      => 100,
    'Temperature'      => '0001',
    'Distance'         => '00',
    'ServerReplyURL'   => 'https://你的網站/ecpay/return-notify',
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/ReturnHome');
```

### 退貨回應處理

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/GetReturnResponse.php`

```php
$verifiedResponse = $factory->create(VerifiedArrayResponse::class);
$result = $verifiedResponse->get($_POST);
```

## 更新出貨 / 門市資訊

### 更新出貨資訊

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/UpdateShipmentInfo.php`

```php
$input = [
    'MerchantID'       => '2000132',
    'AllPayLogisticsID'=> '物流編號',
    'ShipmentDate'     => '2025/01/20',
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Helper/UpdateShipmentInfo');
```

### 更新門市資訊（C2C）

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/UpdateStoreInfo.php`

```php
// 使用 C2C 帳號
$input = [
    'MerchantID'       => '2000933',
    'AllPayLogisticsID'=> '物流編號',
    'CVSPaymentNo'     => '寄貨編號',
    'CVSValidationNo'  => '驗證碼',
    'StoreType'        => '01',
    'ReceiverStoreID'  => '新門市代碼',
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/UpdateStoreInfo');
```

## 取消 C2C 訂單

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/CancelC2cOrder.php`

```php
$input = [
    'MerchantID'       => '2000933',
    'AllPayLogisticsID'=> '物流編號',
    'CVSPaymentNo'     => '寄貨編號',
    'CVSValidationNo'  => '驗證碼',
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/CancelC2COrder');
```

## 查詢物流訂單

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/QueryLogisticsTradeInfo.php`

```php
$postService = $factory->create('PostWithCmvVerifiedEncodedStrResponseService');
$input = [
    'MerchantID'       => '2000132',
    'AllPayLogisticsID'=> '物流編號',
    'TimeStamp'        => time(),
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Helper/QueryLogisticsTradeInfo/V5');
```

## 列印托運單

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/PrintTradeDocument.php`

```php
$autoSubmitFormService = $factory->create('AutoSubmitFormWithCmvService');
$input = [
    'MerchantID'       => '2000132',
    'AllPayLogisticsID'=> '物流編號',
];
echo $autoSubmitFormService->generate($input, 'https://logistics-stage.ecpay.com.tw/helper/printTradeDocument');
```

### C2C 列印標籤

> ⚠️ C2C 列印功能需使用 **C2C 帳號**（MerchantID: 2000933），不是 B2B 帳號。

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/PrintFamic2cOrderInfo.php`, `scripts/SDK_PHP/example/Logistics/Domestic/PrintUniMartc2cOrderInfo.php`, `scripts/SDK_PHP/example/Logistics/Domestic/PrintHilifec2cOrderInfo.php`, `scripts/SDK_PHP/example/Logistics/Domestic/PrintOkmartc2cOrderInfo.php`

| 超商 | 端點 | 參數 |
|------|------|------|
| 全家 | /Express/PrintFAMIC2COrderInfo | MerchantID, AllPayLogisticsID, CVSPaymentNo |
| 統一 | /Express/PrintUniMartC2COrderInfo | + CVSValidationNo |
| 萊爾富 | /Express/PrintHILIFEC2COrderInfo | MerchantID, AllPayLogisticsID, CVSPaymentNo |
| OK | /Express/PrintOKMARTC2COrderInfo | MerchantID, AllPayLogisticsID, CVSPaymentNo |

## 查詢門市清單

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/GetStoreList.php`

```php
$postService = $factory->create('PostWithCmvJsonResponseService');
$input = [
    'MerchantID' => '2000132',
    'CvsType'    => 'All',  // All/FAMI/UNIMART/HILIFE/OKMART/UNIMARTFREEZE
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Helper/GetStoreList');
```

## 建立測試資料

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/CreateTestData.php`

```php
$autoSubmitFormService = $factory->create('AutoSubmitFormWithCmvService');
$input = [
    'MerchantID'       => '2000132',
    'LogisticsSubType' => 'FAMI',
    'ClientReplyURL'   => 'https://你的網站/ecpay/test-data-result',
];
echo $autoSubmitFormService->generate($input, 'https://logistics-stage.ecpay.com.tw/Express/CreateTestData');
```

### 處理測試資料結果

> 原始範例：`scripts/SDK_PHP/example/Logistics/Domestic/GetCreateTestDataResponse.php`

## 完整範例檔案對照（24 個）

| 檔案 | 用途 | SDK Service |
|------|------|-------------|
| Map.php | 電子地圖 | AutoSubmitFormWithCmvService |
| GetMapResponse.php | 地圖結果 | ArrayResponse |
| CreateCvs.php | 超商建單 | PostWithCmvStrResponseService |
| CreateCvsForm.php | 超商建單（表單） | AutoSubmitFormWithCmvService |
| CreateUnimartFreeze.php | 冷凍取貨 | PostWithCmvStrResponseService |
| CreateHome.php | 宅配建單 | PostWithCmvStrResponseService |
| CreateHomeForm.php | 宅配建單（表單） | AutoSubmitFormWithCmvService |
| GetLogisticStatueResponse.php | 狀態通知 | VerifiedArrayResponse |
| ReturnFamiCvs.php | 全家退貨 | PostWithCmvStrResponseService |
| ReturnUniMartCvs.php | 統一退貨 | PostWithCmvStrResponseService |
| ReturnHome.php | 宅配退貨 | PostWithCmvStrResponseService |
| GetReturnResponse.php | 退貨回應 | VerifiedArrayResponse |
| UpdateShipmentInfo.php | 更新出貨 | PostWithCmvStrResponseService |
| UpdateStoreInfo.php | 更新門市 | PostWithCmvStrResponseService |
| CancelC2cOrder.php | 取消C2C | PostWithCmvStrResponseService |
| QueryLogisticsTradeInfo.php | 查詢 | PostWithCmvVerifiedEncodedStrResponseService |
| PrintTradeDocument.php | 列印 | AutoSubmitFormWithCmvService |
| PrintFamic2cOrderInfo.php | 全家C2C列印 | AutoSubmitFormWithCmvService |
| PrintUniMartc2cOrderInfo.php | 統一C2C列印 | AutoSubmitFormWithCmvService |
| PrintHilifec2cOrderInfo.php | 萊爾富C2C列印 | AutoSubmitFormWithCmvService |
| PrintOkmartc2cOrderInfo.php | OKC2C列印 | AutoSubmitFormWithCmvService |
| GetStoreList.php | 門市清單 | PostWithCmvJsonResponseService |
| CreateTestData.php | 測試資料 | AutoSubmitFormWithCmvService |
| GetCreateTestDataResponse.php | 測試資料結果 | VerifiedArrayResponse |

> ⚠️ **安全必做清單（ServerReplyURL）**
> 1. 驗證 MerchantID 為自己的
> 2. 比對物流單號與訂單記錄
> 3. 防重複處理（記錄已處理的 AllPayLogisticsID）
> 4. 異常時仍回應 `1|OK`（避免重送風暴）
> 5. 記錄完整日誌（遮蔽 HashKey/HashIV）
> 6. CheckMacValue 驗證**必須**使用 timing-safe 比較函式（見 [guides/13](./13-checkmacvalue.md) 各語言實作），禁止使用 `==` 或 `===` 直接比對

## 相關文件

- 官方 API 規格：`references/Logistics/物流整合API技術文件.md`（36 個 URL）
- 物流狀態碼：`scripts/SDK_PHP/example/Logistics/logistics_status.xlsx`
- CheckMacValue：[guides/13-checkmacvalue.md](./13-checkmacvalue.md)
- 除錯指南：[guides/15-troubleshooting.md](./15-troubleshooting.md)
- 上線檢查：[guides/16-go-live-checklist.md](./16-go-live-checklist.md)
