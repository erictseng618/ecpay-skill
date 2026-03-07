> 對應 ECPay API 版本 | 基於 PHP SDK ecpay/sdk | 最後更新：2026-03

# B2C 電子發票完整指南

## 概述

B2C 電子發票適用於**賣給消費者**的情境。支援手機條碼載具、自然人憑證、綠界會員載具、捐贈（愛心碼）等。使用 AES 加密 + JSON 格式。

### ⚠️ AES-JSON 開發者必讀：雙層錯誤檢查

B2C 發票（以及所有 AES-JSON 服務）的回應為**三層 JSON** 結構。**必須做兩次檢查**：

1. 檢查外層 `TransCode === 1`（否則 AES 加密/格式有問題，無需解密 Data）
2. 解密 Data 後，檢查內層 `RtnCode === 1`（業務邏輯問題）

只檢查其中一層會導致錯誤漏檢。完整錯誤碼參考見 [guides/21](./21-error-codes-reference.md)。

## 前置需求

- MerchantID / HashKey / HashIV（測試：2000132 / ejCk326UnaZWKisg / q9jcZX8Ib9LM8wYk）
- PHP SDK：`composer require "ecpay/sdk:^4.0"`
- SDK Service：`PostWithAesJsonResponseService`
- 基礎端點：`https://einvoice-stage.ecpay.com.tw/B2CInvoice/`

## AES 請求格式

與 ECPG 相同的三層結構，但 Revision 固定為 `3.0.0`：

```json
{
  "MerchantID": "2000132",
  "RqHeader": {
    "Timestamp": 1234567890,
    "Revision": "3.0.0"
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
| 測試環境 | `https://einvoice-stage.ecpay.com.tw` |
| 正式環境 | `https://einvoice.ecpay.com.tw` |
| Revision | `3.0.0` |
| 回應結構 | 三層 JSON（TransCode → 解密 Data → RtnCode） |

### 端點 URL 一覽

| 功能 | 端點路徑 |
|------|---------|
| 查詢財政部配號 | `/B2CInvoice/GetGovInvoiceWordSetting` |
| 字軌與配號設定 | `/B2CInvoice/InvoiceWordSetting` |
| 設定字軌號碼狀態 | `/B2CInvoice/UpdateInvoiceWordStatus` |
| 查詢字軌 | `/B2CInvoice/GetInvoiceWordSetting` |
| 開立發票 | `/B2CInvoice/Issue` |
| 延遲開立 | `/B2CInvoice/DelayIssue` |
| 觸發開立 | `/B2CInvoice/TriggerIssue` |
| 編輯延遲開立 | `/B2CInvoice/EditDelayIssue` |
| 取消延遲 | `/B2CInvoice/CancelDelayIssue` |
| 一般折讓 | `/B2CInvoice/Allowance` |
| 線上折讓 | `/B2CInvoice/AllowanceByCollegiate` |
| 作廢發票 | `/B2CInvoice/Invalid` |
| 作廢折讓 | `/B2CInvoice/AllowanceInvalid` |
| 取消線上折讓 | `/B2CInvoice/CancelAllowance` |
| 註銷重開 | `/B2CInvoice/VoidWithReIssue` |
| 查詢發票明細 | `/B2CInvoice/GetIssue` |
| 依關聯編號查詢 | `/B2CInvoice/GetIssueByRelateNo`（⚠️ 此端點未列於官方技術文件目錄，**建議改用 `GetIssueList` 查詢**，如需使用請先向綠界確認） |
| 查詢特定多筆發票 | `/B2CInvoice/GetIssueList` |
| 查詢折讓明細 | `/B2CInvoice/GetAllowance` |
| 查詢作廢發票 | `/B2CInvoice/GetInvalid` |
| 查詢作廢折讓 | `/B2CInvoice/GetAllowanceInvalid` |
| 發送通知 | `/B2CInvoice/InvoiceNotify` |
| 發票列印 | `/B2CInvoice/InvoicePrint` |
| 統一編號驗證 | `/B2CInvoice/CheckCompanyIdentifier` |
| 手機條碼驗證 | `/B2CInvoice/CheckBarcode` |
| 捐贈碼驗證 | `/B2CInvoice/CheckLoveCode` |

> ⚠️ **SNAPSHOT 2026-03** | 來源：`references/Invoice/B2C電子發票介接技術文件.md`
> 以上端點及後續參數表僅供整合流程理解，不可直接作為程式碼生成依據。**生成程式碼前必須 web_fetch 來源文件取得最新規格。**

## 開立發票

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/Issue.php`

```php
$factory = new Factory([
    'hashKey' => 'ejCk326UnaZWKisg',
    'hashIv'  => 'q9jcZX8Ib9LM8wYk',
]);
$postService = $factory->create('PostWithAesJsonResponseService');

$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'MerchantID'    => '2000132',
        'RelateNumber'  => 'Inv' . time(),     // 自訂關聯編號
        'CustomerPhone' => '0912345678',        // CustomerPhone 或 CustomerEmail 至少填一個
        'Print'         => '0',                 // 0=不列印, 1=列印
        'Donation'      => '0',                 // 0=不捐贈, 1=捐贈
        'CarrierType'   => '1',                 // 載具類型（見下表）
        'TaxType'       => '1',                 // 稅別（見下表）
        'SalesAmount'   => 100,
        'Items'         => [
            [
                'ItemName'    => '測試商品',
                'ItemCount'   => 1,
                'ItemWord'    => '件',
                'ItemPrice'   => 100,
                'ItemTaxType' => '1',
                'ItemAmount'  => 100,
            ],
        ],
        'InvType' => '07',                     // 07=一般, 08=特種
    ],
];
try {
    $response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/Issue');
    // 成功時 Data 包含 InvoiceNo（發票號碼）
} catch (\Exception $e) {
    error_log('ECPay Invoice Issue Error: ' . $e->getMessage());
}
```

### 載具類型（CarrierType）

| 值 | 說明 |
|----|------|
| （空白） | 無載具（紙本或捐贈） |
| 1 | 綠界科技電子發票載具 |
| 2 | 自然人憑證條碼 |
| 3 | 手機條碼 |

### 稅別（TaxType）

| 值 | 說明 |
|----|------|
| 1 | 應稅 |
| 2 | 零稅率 |
| 3 | 免稅 |
| 9 | 混合稅率（Items 中各項目分別指定 ItemTaxType） |

### 發票類型（InvType）

| 值 | 說明 |
|----|------|
| 07 | 一般稅額 |
| 08 | 特種稅額 |

### Items 欄位

| 欄位 | 說明 |
|------|------|
| ItemName | 商品名稱 |
| ItemCount | 數量 |
| ItemWord | 單位（件、個、組…） |
| ItemPrice | 單價 |
| ItemTaxType | 該項稅別（與 TaxType 對應） |
| ItemAmount | 小計（ItemCount × ItemPrice） |

## 延遲開立

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/DelayIssue.php`

適用場景：等付款確認後再正式開立。先建立發票資料，待觸發條件成立後自動開立。

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'MerchantID'    => '2000132',
        'RelateNumber'  => 'Delay' . time(),
        'CustomerName'  => '測試客戶',
        'CustomerAddr'  => '測試地址',
        'CustomerEmail' => 'test@example.com',
        'Print'         => '1',
        'Donation'      => '0',
        'TaxType'       => '1',
        'SalesAmount'   => 100,
        'Items'         => [/* 同上 */],
        'InvType'       => '07',
        'DelayFlag'     => '1',         // 1=延遲開立
        'DelayDay'      => 15,          // 延遲天數
        'Tsr'           => 'tsr' . time(), // 交易序號
        'PayType'       => '2',         // 2=綠界金流
        'PayAct'        => 'ECPAY',
        'NotifyURL'     => 'https://你的網站/ecpay/invoice-notify',
    ],
];
$response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/DelayIssue');
```

### 觸發延遲開立

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/TriggerIssue.php`

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'MerchantID' => '2000132',
        'Tsr'        => '之前的交易序號',
        'PayType'    => '2',
    ],
];
$response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/TriggerIssue');
```

### 取消延遲開立

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/CancelDelayIssue.php`

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => ['MerchantID' => '2000132', 'Tsr' => '之前的交易序號'],
];
$response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/CancelDelayIssue');
```

### 編輯延遲開立

修改已建立但尚未觸發的延遲開立發票內容。端點：`/B2CInvoice/EditDelayIssue`。
參數與 DelayIssue 相同，額外需帶入原始的 `RelateNumber` 以識別要編輯的發票。
詳細參數見 [B2C 電子發票介接技術文件](../references/Invoice/B2C電子發票介接技術文件.md)。

### 開立回應處理

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/GetInvoicedResponse.php`

延遲開立成功後，綠界會 POST 通知到 NotifyURL：

```php
use Ecpay\Sdk\Response\ArrayResponse;
$arrayResponse = $factory->create(ArrayResponse::class);
$result = $arrayResponse->get($_POST);
```

## 作廢發票

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/Invalid.php`

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'MerchantID'  => '2000132',
        'InvoiceNo'   => 'AB12345678',
        'InvoiceDate' => '2025-01-15',
        'Reason'      => '客戶退貨',
    ],
];
$response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/Invalid');
```

### 作廢重開

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/VoidWithReIssue.php`

一次完成作廢舊發票 + 開立新發票：

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'VoidModel' => [
            'MerchantID' => '2000132',
            'InvoiceNo'  => 'AB12345678',
            'VoidReason' => '金額錯誤',
        ],
        'IssueModel' => [
            'MerchantID'   => '2000132',
            'RelateNumber' => 'ReIssue' . time(),
            'InvoiceDate'  => date('Y-m-d'),
            'CustomerEmail'=> 'test@example.com',
            'Print'        => '0',
            'Donation'     => '0',
            'TaxType'      => '1',
            'SalesAmount'  => 200,
            'Items'        => [/* 新的商品清單 */],
            'InvType'      => '07',
        ],
    ],
];
$response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/VoidWithReIssue');
```

## 折讓（退款部分金額）

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/Allowance.php`

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'MerchantID'      => '2000132',
        'InvoiceNo'       => 'AB12345678',
        'InvoiceDate'     => '2025-01-15',
        'AllowanceNotify' => 'E',           // E=Email, S=SMS, A=全部, N=不通知
        'NotifyMail'      => 'test@example.com',
        'AllowanceAmount' => 50,
        'Items'           => [
            [
                'ItemSeq'    => 1,
                'ItemName'   => '退款商品',
                'ItemCount'  => 1,
                'ItemWord'   => '件',
                'ItemPrice'  => 50,
                'ItemAmount' => 50,
            ],
        ],
    ],
];
$response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/Allowance');
```

### 學校折讓

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/AllowanceByCollegiate.php`

與一般折讓相同，但多一個 `ReturnURL` 參數，結果非同步通知：

```php
$data = [
    'MerchantID'      => '2000132',
    'InvoiceNo'       => 'AB12345678',
    'InvoiceDate'     => '2025-01-15',
    'AllowanceNotify' => 'E',
    'NotifyMail'      => 'test@example.com',
    'AllowanceAmount' => 50,
    'Items'           => [
        [
            'ItemSeq'    => 1,
            'ItemName'   => '退款商品',
            'ItemCount'  => 1,
            'ItemWord'   => '件',
            'ItemPrice'  => 50,
            'ItemAmount' => 50,
        ],
    ],
    // 學校折讓專屬：結果非同步通知到此 URL
    'ReturnURL' => 'https://你的網站/ecpay/allowance-collegiate-notify',
];
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => $data,
];

try {
    $response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/AllowanceByCollegiate');
} catch (\Exception $e) {
    error_log('ECPay AllowanceByCollegiate Error: ' . $e->getMessage());
}
```

### 折讓回應處理

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/GetAllowanceByCollegiateResponse.php`

### 折讓作廢

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/AllowanceInvalid.php`

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'MerchantID'  => '2000132',
        'InvoiceNo'   => 'AB12345678',
        'AllowanceNo' => '折讓編號',
        'Reason'      => '折讓金額錯誤',
    ],
];
$response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/AllowanceInvalid');
```

## 查驗

### 查驗手機條碼

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/CheckBarcode.php`

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => ['MerchantID' => '2000132', 'BarCode' => '/1234567'],
];
$response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/CheckBarcode');
```

### 查驗愛心碼

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/CheckLoveCode.php`

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => ['MerchantID' => '2000132', 'LoveCode' => '168001'],
];
$response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/CheckLoveCode');
```

## 查詢

### 查詢發票

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/GetIssue.php`

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => ['MerchantID' => '2000132', 'InvoiceNo' => 'AB12345678', 'InvoiceDate' => '2025-01-15'],
];
$response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/GetIssue');
```

### 查詢折讓

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/GetAllowance.php`

端點：`POST /B2CInvoice/GetAllowance`，Data：`MerchantID, InvoiceNo, AllowanceNo`

### 查詢折讓作廢

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/GetAllowanceInvalid.php`

端點：`POST /B2CInvoice/GetAllowanceInvalid`，Data：`MerchantID, InvoiceNo, AllowanceNo`

### 查詢作廢

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/GetInvalid.php`

端點：`POST /B2CInvoice/GetInvalid`，Data：`MerchantID, RelateNumber, InvoiceNo, InvoiceDate`

### 查詢特定多筆發票

端點：`POST /B2CInvoice/GetIssueList`

以日期區間批次查詢多筆發票，支援分頁與多種篩選條件。適合對帳或批次匯出場景。

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'MerchantID'  => '2000132',
        'BeginDate'   => '2025-01-01',
        'EndDate'     => '2025-01-31',
        'NumPerPage'  => 10,           // 每頁筆數
        'ShowingPage' => 1,            // 顯示頁碼
    ],
];
try {
    $response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/GetIssueList');
    // Data 包含 TotalCount（總筆數）、InvoiceData（發票陣列）
} catch (\Exception $e) {
    error_log('ECPay GetIssueList Error: ' . $e->getMessage());
}
```

> 完整篩選參數（Query_Award、Query_Invalid 等）見 `references/Invoice/B2C電子發票介接技術文件.md` → 查詢特定多筆發票。

## 發票通知

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/InvoiceNotify.php`

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'MerchantID' => '2000132',
        'InvoiceNo'  => 'AB12345678',
        'NotifyMail' => 'test@example.com',
        'Notify'     => 'E',         // E=Email, S=SMS, A=全部
        'InvoiceTag' => 'I',         // I=開立, II=作廢, A=折讓, AI=折讓作廢, AW=折讓中獎
        'Notified'   => 'C',         // C=已通知, N=未通知
    ],
];
$response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/InvoiceNotify');
```

## 字軌設定查詢

> 原始範例：`scripts/SDK_PHP/example/Invoice/B2C/GetInvoiceWordSetting.php`

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'MerchantID'      => '2000132',
        'InvoiceYear'     => '109',     // 民國年
        'InvoiceTerm'     => 0,         // 0=全部, 1=一月, 2=三月...
        'UseStatus'       => 0,         // 0=全部, 1=已使用, 2=未使用
        'InvoiceCategory' => 1,         // 1=B2C
    ],
];
$response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/GetInvoiceWordSetting');
```

## 法規提醒

- 電子發票開立後需在 **48 小時內**上傳財政部
- 捐贈發票不可作廢
- 已折讓的發票需先作廢折讓才能作廢發票

## 完整範例檔案對照（19 個）

| 檔案 | 用途 | 端點 |
|------|------|------|
| Issue.php | 開立發票 | /B2CInvoice/Issue |
| DelayIssue.php | 延遲開立 | /B2CInvoice/DelayIssue |
| TriggerIssue.php | 觸發延遲開立 | /B2CInvoice/TriggerIssue |
| CancelDelayIssue.php | 取消延遲開立 | /B2CInvoice/CancelDelayIssue |
| Invalid.php | 作廢 | /B2CInvoice/Invalid |
| VoidWithReIssue.php | 作廢重開 | /B2CInvoice/VoidWithReIssue |
| Allowance.php | 折讓 | /B2CInvoice/Allowance |
| AllowanceByCollegiate.php | 學校折讓 | /B2CInvoice/AllowanceByCollegiate |
| AllowanceInvalid.php | 折讓作廢 | /B2CInvoice/AllowanceInvalid |
| CheckBarcode.php | 查驗條碼 | /B2CInvoice/CheckBarcode |
| CheckLoveCode.php | 查驗愛心碼 | /B2CInvoice/CheckLoveCode |
| GetIssue.php | 查詢發票 | /B2CInvoice/GetIssue |
| GetAllowance.php | 查詢折讓 | /B2CInvoice/GetAllowance |
| GetAllowanceInvalid.php | 查詢折讓作廢 | /B2CInvoice/GetAllowanceInvalid |
| GetInvalid.php | 查詢作廢 | /B2CInvoice/GetInvalid |
| InvoiceNotify.php | 發票通知 | /B2CInvoice/InvoiceNotify |
| GetInvoiceWordSetting.php | 字軌設定 | /B2CInvoice/GetInvoiceWordSetting |
| GetInvoicedResponse.php | 開立回應處理 | — |
| GetAllowanceByCollegiateResponse.php | 學校折讓回應 | — |

> ⚠️ **安全必做清單**
> 1. 驗證 MerchantID 為自己的
> 2. 防重複處理（記錄已處理的 InvoiceNo）
> 3. 記錄完整日誌（遮蔽 HashKey/HashIV）

## 查詢財政部配號

端點：`POST /B2CInvoice/GetGovInvoiceWordSetting`

查詢財政部核發的字軌配號結果，確認可使用的發票號碼區間。

### 參數說明

| 參數 | 必填 | 說明 |
|------|------|------|
| MerchantID | 是 | 特店代號 |
| InvoiceYear | 是 | 民國年（例：`113`） |
| InvoiceTerm | 否 | 期數，0=全部、1=一月…6=十一月 |

```php
$factory = new Factory([
    'hashKey' => 'ejCk326UnaZWKisg',
    'hashIv'  => 'q9jcZX8Ib9LM8wYk',
]);
$postService = $factory->create('PostWithAesJsonResponseService');

$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'MerchantID'  => '2000132',
        'InvoiceYear' => '113',
        'InvoiceTerm' => 0,         // 0=全部
    ],
];
try {
    $response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/GetGovInvoiceWordSetting');
    // Data 包含財政部核發的字軌配號清單
} catch (\Exception $e) {
    error_log('ECPay GetGovInvoiceWordSetting Error: ' . $e->getMessage());
}
```

## 字軌與配號設定

端點：`POST /B2CInvoice/InvoiceWordSetting`

設定特店使用的發票字軌與號碼區間，需先透過 `GetGovInvoiceWordSetting` 查詢財政部核發的配號。

### 參數說明

| 參數 | 必填 | 說明 |
|------|------|------|
| MerchantID | 是 | 特店代號 |
| InvoiceYear | 是 | 民國年（例：`113`） |
| InvoiceTerm | 是 | 期數（1=一月、2=三月…6=十一月） |
| InvoiceHeader | 是 | 字軌英文字頭（例：`AB`） |
| InvoiceStart | 是 | 起始號碼（例：`00000001`） |
| InvoiceEnd | 是 | 結束號碼（例：`00000050`） |
| InvoiceCategory | 是 | 1=B2C |

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'MerchantID'      => '2000132',
        'InvoiceYear'     => '113',
        'InvoiceTerm'     => 1,              // 1=一月
        'InvoiceHeader'   => 'AB',
        'InvoiceStart'    => '00000001',
        'InvoiceEnd'      => '00000050',
        'InvoiceCategory' => 1,              // 1=B2C
    ],
];
try {
    $response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/InvoiceWordSetting');
} catch (\Exception $e) {
    error_log('ECPay InvoiceWordSetting Error: ' . $e->getMessage());
}
```

## 設定字軌號碼狀態

端點：`POST /B2CInvoice/UpdateInvoiceWordStatus`

啟用或停用已設定的字軌號碼區間。

### 參數說明

| 參數 | 必填 | 說明 |
|------|------|------|
| MerchantID | 是 | 特店代號 |
| InvoiceYear | 是 | 民國年（例：`113`） |
| InvoiceTerm | 是 | 期數 |
| InvoiceHeader | 是 | 字軌英文字頭 |
| InvoiceStart | 是 | 起始號碼 |
| InvoiceEnd | 是 | 結束號碼 |
| Status | 是 | 狀態（`0`=停用、`1`=啟用） |
| InvoiceCategory | 是 | 1=B2C |

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'MerchantID'      => '2000132',
        'InvoiceYear'     => '113',
        'InvoiceTerm'     => 1,
        'InvoiceHeader'   => 'AB',
        'InvoiceStart'    => '00000001',
        'InvoiceEnd'      => '00000050',
        'Status'          => '1',            // 1=啟用, 0=停用
        'InvoiceCategory' => 1,              // 1=B2C
    ],
];
try {
    $response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/UpdateInvoiceWordStatus');
} catch (\Exception $e) {
    error_log('ECPay UpdateInvoiceWordStatus Error: ' . $e->getMessage());
}
```

## 依關聯編號查詢發票

端點：`POST /B2CInvoice/GetIssueByRelateNo`

以開立時指定的 `RelateNumber`（自訂關聯編號）查詢發票，適合用於以訂單編號反查發票。

### 參數說明

| 參數 | 必填 | 說明 |
|------|------|------|
| MerchantID | 是 | 特店代號 |
| RelateNumber | 是 | 開立發票時帶入的自訂關聯編號 |

```php
$input = [
    'MerchantID' => '2000132',
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '3.0.0'],
    'Data'       => [
        'MerchantID'   => '2000132',
        'RelateNumber' => '你的訂單關聯編號',
    ],
];
try {
    $response = $postService->post($input, 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/GetIssueByRelateNo');
    // Data 包含 InvoiceNo（發票號碼）、InvoiceDate 等發票資訊
} catch (\Exception $e) {
    error_log('ECPay GetIssueByRelateNo Error: ' . $e->getMessage());
}
```

## 相關文件

- 官方 API 規格：`references/Invoice/B2C電子發票介接技術文件.md`（36 個 URL）
- AES 加解密：[guides/14-aes-encryption.md](./14-aes-encryption.md)
- B2B 發票：[guides/05-invoice-b2b.md](./05-invoice-b2b.md)
- 除錯指南：[guides/15-troubleshooting.md](./15-troubleshooting.md)
- 上線檢查：[guides/16-go-live-checklist.md](./16-go-live-checklist.md)
