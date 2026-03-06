> 對應 ECPay API 版本 | 基於 PHP SDK ecpay/sdk | 最後更新：2026-03

# 全方位物流完整指南

## 概述

全方位物流（v2）是新版物流 API，使用 AES 加密 + JSON 格式（與 ECPG/發票相同），提供 RWD 響應式物流選擇介面。支援暫存訂單流程。

### ⚠️ AES-JSON 開發者必讀：雙層錯誤檢查

全方位物流使用 AES-JSON 協議，回應為三層 JSON 結構。**必須做兩次檢查**：

1. 檢查外層 `TransCode === 1`（否則 AES 加密/格式有問題）
2. 解密 Data 後，檢查內層 `RtnCode === 1`（業務邏輯問題）

> 全方位物流 v2 的 **callback 回應**也需要 AES 加密 JSON（三層結構），不同於國內物流的 `1|OK`。

完整錯誤碼參考見 [guides/21](./21-error-codes-reference.md)。

## 與國內物流差異

| 面向 | 國內物流 | 全方位物流 v2 |
|------|---------|-------------|
| 加密方式 | CheckMacValue MD5 | AES |
| 請求格式 | Form POST | JSON POST |
| 物流選擇 | 電子地圖選店 | RWD 頁面含選店 |
| 訂單流程 | 直接建單 | 暫存 → 更新 → 成立 |
| 端點前綴 | /Express/ | /Express/v2/ |

## 前置需求

- MerchantID / HashKey / HashIV（測試：2000132 / 5294y06JbISpM5x9 / v77hoKGq4kWxNNIS）
- SDK Service：`PostWithAesJsonResponseService` 或 `PostWithAesStrResponseService`
- 基礎端點：`https://logistics-stage.ecpay.com.tw/Express/v2/`

```php
$factory = new Factory([
    'hashKey' => '5294y06JbISpM5x9',
    'hashIv'  => 'v77hoKGq4kWxNNIS',
    // hashMethod 不指定，預設 SHA256
]);
```

## AES 請求格式

```json
{
  "MerchantID": "2000132",
  "RqHeader": {
    "Timestamp": 1234567890,
    "Revision": "1.0.0"
  },
  "Data": "AES加密後的Base64字串"
}
```

## HTTP 協議速查（非 PHP 語言必讀）

| 項目 | 規格 |
|------|------|
| 協議模式 | AES-JSON — 詳見 [guides/20-http-protocol-reference.md](./20-http-protocol-reference.md) |
| HTTP 方法 | POST |
| Content-Type | `application/json` |
| 認證 | AES-128-CBC 加密 Data 欄位 — 詳見 [guides/14-aes-encryption.md](./14-aes-encryption.md) |
| 測試環境 | `https://logistics-stage.ecpay.com.tw` |
| 正式環境 | `https://logistics.ecpay.com.tw` |
| 端點前綴 | `/Express/v2/` |
| Revision | `1.0.0` |
| 回應結構 | 三層 JSON（TransCode → 解密 Data → RtnCode） |
| Callback 回應 | AES 加密 JSON（見 [guides/22](./22-webhook-events-reference.md)） |

> **注意**：全方位物流 v2 使用 **AES JSON**（AES-JSON），與國內物流的 **Form + CheckMacValue MD5**（CMV-MD5）完全不同。切勿混淆兩者的認證和請求格式。

> ⚠️ **SNAPSHOT 2026-03** | 來源：`references/Logistics/全方位物流服務API技術文件.md`
> 以下端點及參數僅供整合流程理解，不可直接作為程式碼生成依據。**生成程式碼前必須 web_fetch 來源文件取得最新規格。**

### 端點 URL 一覽

| 功能 | 端點路徑 |
|------|---------|
| 物流選擇頁面重導 | `/Express/v2/RedirectToLogisticsSelection` |
| 暫存訂單建立 | `/Express/v2/CreateTempTrade` |
| 更新暫存訂單 | `/Express/v2/UpdateTempTrade` |
| 成立訂單 | `/Express/v2/CreateByTempTrade` |
| 查詢訂單 | `/Express/v2/QueryLogisticsTradeInfo` |
| 列印物流單 | `/Express/v2/PrintTradeDocument` |
| B2C 全家退貨 | `/Express/v2/ReturnCVS` |
| B2C 統一超商退貨 | `/Express/v2/ReturnUniMartCVS` |
| B2C 萊爾富退貨 | `/Express/v2/ReturnHilifeCVS` |
| 宅配退貨 | `/Express/v2/ReturnHome` |
| B2C 更新出貨資訊 | `/Express/v2/UpdateShipmentInfo` |
| C2C 更新店到店資訊 | `/Express/v2/UpdateStoreInfo` |
| C2C 取消訂單 | `/Express/v2/CancelC2COrder` |
| 建立測試資料 | `/Express/v2/CreateTestData` |

## 物流選擇頁面重導

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/RedirectToLogisticsSelection.php`

```php
$postService = $factory->create('PostWithAesStrResponseService');
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '1.0.0'],
    'Data'       => [
        'TempLogisticsID' => '0',  // 0=新建
        'GoodsAmount'     => 100,
        'GoodsName'       => '測試商品',
        'SenderName'      => '寄件人',
        'SenderZipCode'   => '106',
        'SenderAddress'   => '台北市大安區測試路1號',
        'ServerReplyURL'  => 'https://你的網站/ecpay/logistics-notify',
        'ClientReplyURL'  => 'https://你的網站/ecpay/logistics-result',
    ],
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/v2/RedirectToLogisticsSelection');
echo $response['body'];  // 輸出 HTML 頁面
```

### 冷凍物流選擇

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/RedirectWithUnimartFreeze.php`

同上，但 Data 中加入 `'Temperature' => '0003'`。

### 處理暫存訂單回應

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/TempTradeEstablishedResponse.php`

消費者選擇完物流後，ClientReplyURL 收到結果：

```php
use Ecpay\Sdk\Response\AesJsonResponse;
$aesJsonResponse = $factory->create(AesJsonResponse::class);
$result = $aesJsonResponse->get($_POST['ResultData']);
// $result 包含 TempLogisticsID
```

## 暫存訂單流程

### 更新暫存訂單

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/UpdateTempTrade.php`

```php
$postService = $factory->create('PostWithAesJsonResponseService');
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '1.0.0'],
    'Data'       => [
        'TempLogisticsID' => '暫存物流ID',
        'SenderName'      => '更新後的寄件人',
    ],
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/v2/UpdateTempTrade');
```

### 正式成立訂單

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/CreateByTempTrade.php`

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '1.0.0'],
    'Data'       => [
        'TempLogisticsID' => '2264',  // 暫存物流ID
    ],
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/v2/CreateByTempTrade');
```

## 物流狀態通知

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/LogisticsStatusNotify.php`

全方位物流的通知是 AES 加密的 JSON（不是 Form POST）：

```php
use Ecpay\Sdk\Response\AesJsonResponse as AesParser;
use Ecpay\Sdk\Request\AesRequest as AesGenerater;

// 接收通知
$aesParser = $factory->create(AesParser::class);
$parsedRequest = $aesParser->get(file_get_contents('php://input'));

// 回應（也需要 AES 加密）
$aesGenerater = $factory->create(AesGenerater::class);
$data = [
    'RtnCode' => 1,
    'RtnMsg'  => '',
];
$responseData = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time()],
    'TransCode'  => 1,
    'TransMsg'   => '',
    'Data'       => $data,
];
$response = $aesGenerater->get($responseData);
echo json_encode($response);
```

#### 全方位物流 Callback 回應範例

全方位物流的 callback 回應**不是** `1|OK`（那是國內物流），而是 **AES 加密的 JSON 三層結構**。

**你收到的 callback body**：
```json
{
  "MerchantID": "2000132",
  "RpHeader": { "Timestamp": 1709654400 },
  "TransCode": 1,
  "TransMsg": "Success",
  "Data": "AES加密的Base64字串"
}
```

**處理步驟**：
1. 解密 `Data` 欄位（使用 [guides/14](./14-aes-encryption.md) 的 `aesDecrypt` 函式）
2. 從解密結果取得物流狀態
3. 更新本地訂單狀態
4. 回應 AES 加密的 JSON：

**你必須回應的格式**：
```php
// PHP 範例
$responseData = ['RtnCode' => 1, 'RtnMsg' => 'OK'];
$encryptedData = $postService->encrypt($responseData);
echo json_encode([
    'MerchantID' => '2000132',
    'RqHeader' => ['Timestamp' => time()],
    'Data' => $encryptedData,
]);
```

> **常見錯誤**：用 `echo '1|OK'` 回應全方位物流 callback — 這會導致 ECPay 認為處理失敗並持續重送。
> 正確做法是回應 AES 加密的 JSON，格式與 API 請求的三層結構相同。

## 查詢物流訂單

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/QueryLogisticsTradeInfo.php`

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '1.0.0'],
    'Data'       => [
        'MerchantID' => '2000132',
        'LogisticsID'=> '物流編號',
    ],
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/v2/QueryLogisticsTradeInfo');
```

## 列印

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/PrintTradeDocument.php`

```php
$postService = $factory->create('PostWithAesStrResponseService');
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '1.0.0'],
    'Data'       => [
        'MerchantID'       => '2000132',
        'LogisticsID'      => ['1769543'],  // 陣列，可多筆
        'LogisticsSubType' => 'FAMI',
    ],
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/v2/PrintTradeDocument');
echo $response['body'];
```

## B2C 退貨

### 全家退貨

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/B2C/ReturnFamiCVS.php`

```php
$input['Data'] = [
    'MerchantID'     => '2000132',
    'LogisticsID'    => '物流編號',
    'GoodsAmount'    => 100,
    'ServiceType'    => '4',
    'SenderName'     => '退貨人',
    'ServerReplyURL' => 'https://你的網站/ecpay/return-notify',
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/v2/ReturnCVS');
```

### 萊爾富退貨

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/B2C/ReturnHilifeCvs.php`

端點：`POST /Express/v2/ReturnHilifeCVS`
Data 多一個 `SenderPhone` 欄位。

### 統一退貨

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/B2C/ReturnUnimartCvs.php`

端點：`POST /Express/v2/ReturnUniMartCVS`

### 宅配退貨

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/Home/ReturnHome.php`

```php
$input['Data'] = [
    'MerchantID'     => '2000132',
    'LogisticsID'    => '物流編號',
    'GoodsAmount'    => 100,
    'Temperature'    => '0001',
    'Distance'       => '00',
    'Specification'  => '0001',
    'ServerReplyURL' => 'https://你的網站/ecpay/return-notify',
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/v2/ReturnHome');
```

## B2C 更新出貨

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/B2C/UpdateShipmentInfo.php`

```php
$input['Data'] = [
    'MerchantID'   => '2000132',
    'LogisticsID'  => '物流編號',
    'ShipmentDate' => '2021/10/25',
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/v2/UpdateShipmentInfo');
```

## B2C 建立測試資料

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/B2C/CreateTestData.php`

```php
$input['Data'] = [
    'MerchantID'       => '2000132',
    'LogisticsSubType' => 'FAMI',
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/v2/CreateTestData');
```

## C2C 操作

### 取消 C2C 訂單

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/C2C/CancelC2cOrder.php`

```php
$input['Data'] = [
    'MerchantID'       => '2000132',
    'LogisticsID'      => '物流編號',
    'CVSPaymentNo'     => '寄貨編號',
    'CVSValidationNo'  => '驗證碼',
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/v2/CancelC2COrder');
```

### 更新門市資訊

> 原始範例：`scripts/SDK_PHP/example/Logistics/AllInOne/C2C/UpdateStoreInfo.php`

```php
$input['Data'] = [
    'MerchantID'       => '2000132',
    'LogisticsID'      => '物流編號',
    'CVSPaymentNo'     => '寄貨編號',
    'CVSValidationNo'  => '驗證碼',
    'StoreType'        => '01',
    'ReceiverStoreID'  => '新門市代碼',
];
$response = $postService->post($input, 'https://logistics-stage.ecpay.com.tw/Express/v2/UpdateStoreInfo');
```

## 完整範例檔案對照（16 個）

| 檔案 | 用途 |
|------|------|
| RedirectToLogisticsSelection.php | 物流選擇頁面 |
| RedirectWithUnimartFreeze.php | 冷凍物流選擇 |
| TempTradeEstablishedResponse.php | 暫存回應 |
| UpdateTempTrade.php | 更新暫存 |
| CreateByTempTrade.php | 正式建單 |
| LogisticsStatusNotify.php | 狀態通知 |
| QueryLogisticsTradeInfo.php | 查詢 |
| PrintTradeDocument.php | 列印 |
| B2C/ReturnFamiCVS.php | 全家退貨 |
| B2C/ReturnHilifeCvs.php | 萊爾富退貨 |
| B2C/ReturnUnimartCvs.php | 統一退貨 |
| B2C/UpdateShipmentInfo.php | 更新出貨 |
| B2C/CreateTestData.php | 測試資料 |
| C2C/CancelC2cOrder.php | 取消C2C |
| C2C/UpdateStoreInfo.php | 更新門市 |
| Home/ReturnHome.php | 宅配退貨 |

> ⚠️ **安全必做清單（ServerReplyURL）**
> 1. 驗證 MerchantID 為自己的
> 2. 比對物流單號與訂單記錄
> 3. 防重複處理（記錄已處理的 AllPayLogisticsID）
> 4. 異常時仍回應 AES 加密 JSON `{ "TransCode": "1" }`（避免重送風暴）
> 5. 記錄完整日誌（遮蔽 HashKey/HashIV）

## 相關文件

- 官方 API 規格：`references/Logistics/全方位物流服務API技術文件.md`（27 個 URL）
- AES 加解密：[guides/14-aes-encryption.md](./14-aes-encryption.md)
- 國內物流（舊版）：[guides/06-logistics-domestic.md](./06-logistics-domestic.md)
- 除錯指南：[guides/15-troubleshooting.md](./15-troubleshooting.md)
- 上線檢查：[guides/16-go-live-checklist.md](./16-go-live-checklist.md)
