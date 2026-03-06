> 對應 ECPay API 版本 | 基於 PHP SDK ecpay/sdk | 最後更新：2026-03

# 全方位金流 AIO 完整指南

> **非 PHP 開發者？** 建議閱讀順序：
> 1. [guides/13](./13-checkmacvalue.md) — 實作你的語言的 CheckMacValue，並通過測試向量驗證
> 2. [guides/20](./20-http-protocol-reference.md) — 確認 AIO 的 HTTP 請求格式（Content-Type、回應格式）
> 3. 回到本文 — 理解 AIO 整合流程和參數，將 PHP 範例翻譯為你的語言
> 4. [guides/24](./24-multi-language-integration.md) — 完整多語言 E2E 範例和 Checklist

## 概述

AIO（All-In-One）是 ECPay 最常用的金流整合方案，將消費者導向綠界標準付款頁面，支援 10+ 種付款方式。適合絕大多數電商場景。

## 前置需求

- MerchantID / HashKey / HashIV（測試：3002607 / pwFHCqoQZGmho4w6 / EkRm7iFT261dpevs）
- PHP SDK：`composer require "ecpay/sdk:^4.0"`
- 加密方式：CheckMacValue SHA256

> **⚠️ 安全提醒**：本指南範例中的 HashKey / HashIV 為公開測試值。
> 正式環境**禁止**在程式碼中硬編碼 — 務必使用環境變數或密鑰管理服務。
> 見 [guides/16-go-live-checklist.md](./16-go-live-checklist.md) §安全性。

## HTTP 協議速查（非 PHP 語言必讀）

| 項目 | 規格 |
|------|------|
| 協議模式 | CMV-SHA256 — 詳見 [guides/20-http-protocol-reference.md](./20-http-protocol-reference.md) |
| HTTP 方法 | POST |
| Content-Type | `application/x-www-form-urlencoded` |
| 認證 | CheckMacValue（SHA256） — 詳見 [guides/13-checkmacvalue.md](./13-checkmacvalue.md) |
| 正式環境 | `https://payment.ecpay.com.tw` |
| 測試環境 | `https://payment-stage.ecpay.com.tw` |
| 建單回應 | HTML 頁面（瀏覽器重導至綠界付款頁） |
| 查詢回應 | URL-encoded 字串 或 JSON（依端點不同） |
| Callback | Form POST 至 ReturnURL，必須回應 `1|OK` |
| Timestamp 有效期 | 查詢 API: 3 分鐘 |
| 重試機制 | 每 5-15 分鐘，每日最多 4 次 |

### 端點 URL 一覽

| 功能 | 端點路徑 | 回應格式 |
|------|---------|---------|
| 建立訂單 | `/Cashier/AioCheckOut/V5` | HTML（重導） |
| 查詢訂單 | `/Cashier/QueryTradeInfo/V5` | URL-encoded |
| 信用卡請退款 | `/CreditDetail/DoAction` | URL-encoded |
| 信用卡明細查詢 | `/CreditDetail/QueryTrade/V2` | JSON |
| 定期定額查詢 | `/Cashier/QueryCreditCardPeriodInfo` | JSON |
| 取號結果查詢 | `/Cashier/QueryPaymentInfo` | URL-encoded |
| 定期定額作業 | `/Cashier/CreditCardPeriodAction` | URL-encoded |
| 對帳檔下載 | `/PaymentMedia/TradeNoAio` | text |
| 信用卡撥款對帳 | `/CreditDetail/FundingReconDetail` | text |

> ⚠️ **對帳端點 Domain 差異**：`/PaymentMedia/TradeNoAio` 使用 `vendor-stage.ecpay.com.tw`（正式：`vendor.ecpay.com.tw`），與其他 AIO 端點的 `payment-stage.ecpay.com.tw` **不同**。打錯 domain 會收到 404。

## 整合流程

```
你的網站                          綠界
  │                               │
  ├─ POST 訂單 ──────────────────→│ /Cashier/AioCheckOut/V5
  │                               │
  │                               ├─ 消費者在綠界頁面付款
  │                               │
  │←─ POST 付款結果（ReturnURL）──┤ Server-to-Server
  │                               │
  │  消費者瀏覽器 ←─ 導回 ────────┤ ClientBackURL
```

## AIO 共用必填參數

> ⚠️ **SNAPSHOT 2026-03** | 來源：`references/Payment/全方位金流API技術文件.md`
> 以下參數表僅供整合流程理解，不可直接作為程式碼生成依據。**生成程式碼前必須 web_fetch 來源文件取得最新規格。**

> 從所有 `scripts/SDK_PHP/example/Payment/Aio/*.php` 交集提取

| 參數 | 類型 | 長度 | 說明 | 範例值 |
|------|------|------|------|--------|
| MerchantID | String | 10 | 特店編號 | 3002607 |
| MerchantTradeNo | String | 20 | 特店交易編號（不可重複，建議含時間戳） | Test1709123456 |
| MerchantTradeDate | String | 20 | 交易時間 `yyyy/MM/dd HH:mm:ss` | 2025/01/01 12:00:00 |
| PaymentType | String | 20 | 固定值 | aio |
| TotalAmount | Int | — | 交易金額（新台幣整數） | 100 |
| TradeDesc | String | 200 | 交易描述（需 URL encode） | 測試交易 |
| ItemName | String | 400 | 商品名稱（多項用 `#` 分隔） | 商品A#商品B |
| ReturnURL | String | 200 | 付款結果通知 URL（Server 端） | https://你的網站/ecpay/notify |
| ChoosePayment | String | 20 | 付款方式 | ALL / Credit / ATM / CVS 等 |
| EncryptType | Int | — | 固定值 1（SHA256） | 1 |
| CheckMacValue | String | — | 檢查碼（SDK 自動產生） | — |

### 選用參數

| 參數 | 型別 | 長度 | 說明 |
|------|------|------|------|
| ClientBackURL | String | 200 | 消費者付款完成後導回的網址（前端）|
| OrderResultURL | String | 200 | 付款完成後導向並帶回結果的網址 |
| NeedExtraPaidInfo | String(1) | 1 | 是否需要額外付款資訊（Y/N）|
| IgnorePayment | String | 100 | 排除的付款方式（用 `#` 分隔）|
| PlatformID | String | 10 | 平台商編號（平台商代收代付模式，一般商店不需填寫）|
| CustomField1~4 | String | 50 | 自訂欄位 |
| Language | String | 3 | 語言（CHT/ENG/KOR/JPN/CHI）|
| StoreID | String | 20 | 門市代號 |

### MerchantTradeNo 注意事項
- **不可重複**，重複會回傳錯誤
- 建議格式：前綴 + 時間戳，如 `'Test' . time()`
- 最長 20 字元，僅允許英數字

## 各付款方式專用參數

| 付款方式 | ChoosePayment | 專用參數 | 金額限制 | 範例檔案 |
|---------|--------------|---------|---------|---------|
| 全部 | ALL | — | — | CreateOrder.php |
| 信用卡 | Credit | Redeem, UnionPay, BindingCard | — | CreateCreditOrder.php |
| 分期 | Credit | CreditInstallment=3,6,18 | — | CreateInstallmentOrder.php |
| 定期定額 | Credit | PeriodAmount,PeriodType,Frequency,ExecTimes,PeriodReturnURL | — | CreatePeriodicOrder.php |
| ATM | ATM | ExpireDate=7（天） | — | CreateAtmOrder.php |
| 超商代碼 | CVS | StoreExpireDate=4320（分鐘）,Desc_1~4,PaymentInfoURL | — | CreateCvsOrder.php |
| 條碼 | BARCODE | StoreExpireDate=5（天）,Desc_1~4,PaymentInfoURL | — | CreateBarcodeOrder.php |
| WebATM | WebATM | — | — | CreateWebAtmOrder.php |
| TWQR | TWQR | — | — | CreateTwqrOrder.php |
| BNPL | BNPL | — | ≥3000 | CreateBnplOrder.php |
| 綠界PAY | ECPay | — | — | — |
| 微信 | WeiXin | — | — | CreateWeiXinOrder.php |

> **分期期數說明**：AIO 支援的分期期數：3, 6, 12, 18, 24, 30 期（依合約而定）。實際可用期數以商店後台設定和信用卡銀行合約為準。
>
> **消費者自費分期**：除了商家吸收手續費的一般分期外，ECPay 也支援「消費者自費分期」，由消費者自行負擔分期手續費。需另外向綠界申請啟用，啟用後可透過 `CreditInstallment` 參數設定。詳見官方文件：`references/Payment/全方位金流API技術文件.md` → 消費者自費分期。

**端點**：`POST https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5`

**SDK 用法**：`$factory->create('AutoSubmitFormWithCmvService')`

### 信用卡範例

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/CreateCreditOrder.php`

```php
$input = [
    'MerchantID'       => '3002607',
    'MerchantTradeNo'  => 'Test' . time(),
    'MerchantTradeDate'=> date('Y/m/d H:i:s'),
    'PaymentType'      => 'aio',
    'TotalAmount'      => 100,
    'TradeDesc'        => UrlService::ecpayUrlEncode('測試交易'),  // 官方 SDK 範例做法，見 scripts/SDK_PHP/example/Payment/Aio/CreateCreditOrder.php
    'ItemName'         => '測試商品',
    'ReturnURL'        => 'https://你的網站/ecpay/notify',
    'ChoosePayment'    => 'Credit',
    'EncryptType'      => 1,
];
echo $autoSubmitFormService->generate($input, $actionUrl);
```

### ATM 範例

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/CreateAtmOrder.php`

```php
$input = [
    'MerchantID'       => '3002607',
    'MerchantTradeNo'  => 'Test' . time(),
    'MerchantTradeDate'=> date('Y/m/d H:i:s'),
    'PaymentType'      => 'aio',
    'TotalAmount'      => 100,
    'TradeDesc'        => UrlService::ecpayUrlEncode('交易描述範例'),
    'ItemName'         => '範例商品一批 100 TWD x 1',
    'ReturnURL'        => 'https://你的網站/ecpay/notify',
    'ChoosePayment'    => 'ATM',
    'EncryptType'      => 1,
    'ExpireDate'       => 7,              // ATM 繳費期限（天）
    'PaymentInfoURL'   => 'https://你的網站/ecpay/payment-info',  // 取號結果通知 URL
];
echo $autoSubmitFormService->generate($input, $actionUrl);
```

> **PaymentInfoURL vs ReturnURL**：ATM 付款是非同步流程。`PaymentInfoURL` 接收取號結果（RtnCode=2），`ReturnURL` 接收實際付款結果（RtnCode=1）。

### 超商代碼（CVS）範例

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/CreateCvsOrder.php`

```php
$input = [
    'MerchantID'       => '3002607',
    'MerchantTradeNo'  => 'Test' . time(),
    'MerchantTradeDate'=> date('Y/m/d H:i:s'),
    'PaymentType'      => 'aio',
    'TotalAmount'      => 100,
    'TradeDesc'        => UrlService::ecpayUrlEncode('交易描述範例'),
    'ItemName'         => '範例商品一批 100 TWD x 1',
    'ReturnURL'        => 'https://你的網站/ecpay/notify',
    'ChoosePayment'    => 'CVS',
    'EncryptType'      => 1,
    'StoreExpireDate'  => 4320,         // 繳費期限（分鐘）= 3天
    'Desc_1'           => '範例交易描述 1',
    'Desc_2'           => '範例交易描述 2',
    'Desc_3'           => '範例交易描述 3',
    'Desc_4'           => '範例交易描述 4',
    'PaymentInfoURL'   => 'https://你的網站/ecpay/payment-info',  // 取號結果通知 URL
];
echo $autoSubmitFormService->generate($input, $actionUrl);
```

### 條碼（BARCODE）範例

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/CreateBarcodeOrder.php`

```php
$input = [
    'MerchantID'       => '3002607',
    'MerchantTradeNo'  => 'Test' . time(),
    'MerchantTradeDate'=> date('Y/m/d H:i:s'),
    'PaymentType'      => 'aio',
    'TotalAmount'      => 100,
    'TradeDesc'        => UrlService::ecpayUrlEncode('交易描述範例'),
    'ItemName'         => '範例商品一批 100 TWD x 1',
    'ReturnURL'        => 'https://你的網站/ecpay/notify',
    'ChoosePayment'    => 'BARCODE',
    'EncryptType'      => 1,
    'StoreExpireDate'  => 5,            // 繳費期限（天）
    'Desc_1'           => '範例交易描述 1',
    'Desc_2'           => '範例交易描述 2',
    'Desc_3'           => '範例交易描述 3',
    'Desc_4'           => '範例交易描述 4',
    'PaymentInfoURL'   => 'https://你的網站/ecpay/payment-info',  // 取號結果通知 URL
];
echo $autoSubmitFormService->generate($input, $actionUrl);
```

### 分期範例

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/CreateInstallmentOrder.php`

```php
$input = [
    // 共用參數見「信用卡範例」（上方 MerchantID ~ EncryptType）
    'ChoosePayment'     => 'Credit',
    'CreditInstallment' => '3,6,18',  // 可分 3/6/18 期
    'EncryptType'       => 1,
];
```

### BNPL 範例

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/CreateBnplOrder.php`

```php
$input = [
    // 共用參數見「信用卡範例」（上方 MerchantID ~ EncryptType）
    'TotalAmount'      => 3000,        // BNPL 最低 3000 元
    'ChoosePayment'    => 'BNPL',
    'EncryptType'      => 1,
];
```

### TWQR 範例

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/CreateTwqrOrder.php`

```php
$input = [
    // 共用參數見「信用卡範例」（上方 MerchantID ~ EncryptType）
    'ChoosePayment'    => 'TWQR',
    'EncryptType'      => 1,
];
```

### 微信支付範例

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/CreateWeiXinOrder.php`

```php
$input = [
    // 共用參數見「信用卡範例」（上方 MerchantID ~ EncryptType）
    'ChoosePayment'    => 'WeiXin',
    'EncryptType'      => 1,
];
```

## 付款結果通知（ReturnURL）

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/GetCheckoutResponse.php`

綠界會 POST 以下欄位到你的 ReturnURL：

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

> ⚠️ **ATM/CVS/BARCODE 特殊 RtnCode**
>
> | RtnCode | 意義 | 說明 |
> |:-------:|------|------|
> | 1 | 付款成功 | 信用卡/WebATM/TWQR 等即時付款 |
> | 2 | ATM 取號成功 | 消費者**尚未繳費**，需等待第二次 Callback（RtnCode=1）|
> | 10100073 | CVS/BARCODE 取號成功 | 同上，等待消費者到超商繳費 |
>
> **不要把 RtnCode=2 或 10100073 當作錯誤！** 這代表取號成功，消費者會在期限內去繳費。

### 各付款方式額外回傳參數

Callback 除了基本欄位外，各付款方式會額外回傳（需設定 `NeedExtraPaidInfo=Y`）：

| 付款方式 | 額外欄位 | 說明 |
|---------|---------|------|
| 信用卡 | `card4no`, `card6no`, `auth_code` | 卡號末四碼、前六碼、授權碼 |
| 信用卡（分期） | `stage`, `stast`, `staed` | 分期期數、頭期金額、各期金額 |
| 信用卡（紅利） | `red_dan`, `red_de_amt`, `red_ok_amt`, `red_yet` | 紅利扣點、折抵金額、實際扣款、剩餘點數 |
| ATM | `ATMAccBank`, `ATMAccNo` | 付款人銀行代碼、帳號末五碼 |
| WebATM | `WebATMAccBank`, `WebATMAccNo`, `WebATMBankName` | 銀行代碼、帳號末五碼、銀行名稱 |
| 超商代碼 | `PaymentNo`, `PayFrom` | 繳費代碼、繳費超商 |
| 超商條碼 | `PayFrom` | 繳費超商 |
| TWQR | `TWQRTradeNo` | 行動支付交易編號 |

> **注意**：額外回傳的參數**全部都需要加入 CheckMacValue 計算**。完整欄位清單見 `references/Payment/全方位金流API技術文件.md` → 額外回傳的參數。

### 驗證流程

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

### ReturnURL 重要限制
- 必須回應純字串 `1|OK`
- 不可放在 CDN 後面
- 僅支援 80/443 埠
- 非 ASCII 域名需用 punycode
- TLS 1.2 必須
- 不可含特殊字元（分號、管道、反引號）
- 重送機制：每 5-15 分鐘重送，每天最多 4 次

## ATM/CVS/BARCODE 取號通知（PaymentInfoURL）

ATM/CVS/BARCODE 付款是**非同步流程**：建立訂單 → 取得繳費資訊 → 消費者去繳費 → 付款完成通知。

取號成功的 RtnCode **不是 1**：
- ATM 取號成功：`RtnCode=2`
- CVS 取號成功：`RtnCode=10100073`
- BARCODE 取號成功：`RtnCode=10100073`

PaymentInfoURL 回呼欄位：

| 付款方式 | 額外欄位 |
|---------|---------|
| ATM | BankCode（銀行代碼）, vAccount（虛擬帳號）, ExpireDate（繳費期限）|
| CVS | PaymentNo（繳費代碼）, ExpireDate |
| BARCODE | Barcode1, Barcode2, Barcode3, ExpireDate |

### 查詢付款資訊

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/QueryPaymentInfo.php`

```php
$postService = $factory->create('PostWithCmvVerifiedEncodedStrResponseService');
$input = [
    'MerchantID'      => '3002607',
    'MerchantTradeNo' => '你的訂單編號',
    'TimeStamp'       => time(),
];
$response = $postService->post(
    $input,
    'https://payment-stage.ecpay.com.tw/Cashier/QueryPaymentInfo'
);
```

## 定期定額（訂閱制）

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/CreatePeriodicOrder.php`

### 建立定期定額訂單

```php
$input = [
    'MerchantID'       => '3002607',
    'MerchantTradeNo'  => 'Sub' . time(),
    'MerchantTradeDate'=> date('Y/m/d H:i:s'),
    'PaymentType'      => 'aio',
    'TotalAmount'      => 299,
    'TradeDesc'        => '月訂閱方案',
    'ItemName'         => '月訂閱 x1',
    'ReturnURL'        => 'https://你的網站/ecpay/notify',
    'ChoosePayment'    => 'Credit',
    'EncryptType'      => 1,
    'PeriodAmount'     => 299,     // 每期金額
    'PeriodType'       => 'M',     // D=天, M=月, Y=年
    'Frequency'        => 1,       // 每 1 個月執行一次
    'ExecTimes'        => 12,      // 共執行 12 次
    'PeriodReturnURL'  => 'https://你的網站/ecpay/period-notify',
];
echo $autoSubmitFormService->generate(
    $input,
    'https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5'
);
```

### PeriodReturnURL 每期通知

每次扣款完成後，綠界會 POST 到 `PeriodReturnURL`，包含：
- RtnCode（1=成功）
- PeriodType、Frequency、ExecTimes
- TotalSuccessTimes（已成功次數）
- TotalSuccessAmount（已成功金額）

### 定期定額管理

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/CreditCardPeriodAction.php`

```php
$postService = $factory->create('PostWithCmvEncodedStrResponseService');
$input = [
    'MerchantID'      => '3002607',
    'MerchantTradeNo' => '你的訂閱訂單編號',
    'Action'          => 'Cancel',  // Cancel=取消, ReAuth=重新授權
    'TimeStamp'       => time(),
];
$response = $postService->post(
    $input,
    'https://payment-stage.ecpay.com.tw/Cashier/CreditCardPeriodAction'
);
```

### 查詢定期定額

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/QueryPeridicTrade.php`

```php
$postService = $factory->create('PostWithCmvJsonResponseService');
$input = [
    'MerchantID'      => '3002607',
    'MerchantTradeNo' => '你的訂閱訂單編號',
    'TimeStamp'       => time(),
];
$response = $postService->post(
    $input,
    'https://payment-stage.ecpay.com.tw/Cashier/QueryCreditCardPeriodInfo'
);
```

#### 定期定額失敗重試機制

| 失敗次數 | 綠界行為 | 建議商家動作 |
|:-------:|---------|-----------|
| 1-3 次 | 自動重試（間隔 3-5 天） | 監控，無需介入 |
| 4-5 次 | 自動重試（間隔延長） | 通知消費者更新付款資訊 |
| **6 次** | **自動取消合約** | 通知消費者重新訂閱 |

> 連續扣款失敗 6 次後，綠界將自動終止該定期定額合約。
> 商家應在第 3 次失敗時主動通知消費者，避免合約被取消。
> 扣款結果通知至 `PeriodReturnURL`。

## 信用卡請款 / 退款 / 取消

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/Capture.php`

```php
$postService = $factory->create('PostWithCmvEncodedStrResponseService');
$input = [
    'MerchantID'      => '3002607',
    'MerchantTradeNo' => '你的訂單編號',
    'TradeNo'         => '綠界交易編號',
    'Action'          => 'C',          // C=請款, R=退款, E=取消授權, N=放棄
    'TotalAmount'     => 100,
];

try {
    $response = $postService->post(
        $input,
        'https://payment-stage.ecpay.com.tw/CreditDetail/DoAction'
    );
    // 回應格式：RtnCode|RtnMsg，例如 "1|OK"
} catch (\Exception $e) {
    error_log('ECPay Capture Error: ' . $e->getMessage());
    // 依業務需求處理（通知管理員、重試等）
}
```

| Action | 說明 |
|--------|------|
| C | 請款（關帳） |
| R | 退款（可部分退款） |
| E | 取消授權 |
| N | 放棄（取消請款） |

### 部分退款範例

`Action=R` 時，`TotalAmount` 填入**欲退款的金額**（非原訂單金額）。同一筆訂單可多次部分退款，累計退款金額不得超過原交易金額。

```php
$input = [
    'MerchantID'      => '3002607',
    'MerchantTradeNo' => '你的訂單編號',
    'TradeNo'         => '綠界交易編號',
    'Action'          => 'R',
    'TotalAmount'     => 50,  // 退款 50 元（原交易 100 元）
];
$response = $postService->post(
    $input,
    'https://payment-stage.ecpay.com.tw/CreditDetail/DoAction'
);
```

### 退款注意事項

- **已關帳（已請款）**：`Action=R` 可退款，`TotalAmount` 填退款金額。支援多次部分退款，累計不得超過原交易金額
- **未關帳（未請款）**：僅能取消授權（`Action=E`）或放棄（`Action=N`），不支援部分取消
- 退款後無法復原，請確認金額正確再執行

> 完整退款參數規格請 web_fetch `references/Payment/全方位金流API技術文件.md` 中「信用卡請退款功能」對應 URL。

## 查詢訂單

### 一般查詢

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/QueryTrade.php`

```php
$postService = $factory->create('PostWithCmvVerifiedEncodedStrResponseService');
$input = [
    'MerchantID'      => '3002607',
    'MerchantTradeNo' => '你的訂單編號',
    'TimeStamp'       => time(),
];

try {
    $response = $postService->post(
        $input,
        'https://payment-stage.ecpay.com.tw/Cashier/QueryTradeInfo/V5'
    );
    // $response 為 key=value 格式字串，已自動驗證 CheckMacValue
} catch (\Exception $e) {
    error_log('ECPay QueryTrade Error: ' . $e->getMessage());
}
```

### PaymentType 回覆值對照

查詢訂單或 Callback 中的 `PaymentType` 欄位，常見回覆值：

| 回覆值 | 付款方式 |
|--------|---------|
| `Credit_CreditCard` | 信用卡（一般） |
| `Flexible_Installment` | 永豐 30 期分期 |
| `TWQR_OPAY` | TWQR 行動支付 |
| `ATM_BOT` | ATM 台灣銀行 |
| `ATM_CHINATRUST` | ATM 中國信託 |
| `ATM_FIRST` | ATM 第一銀行 |
| `ATM_LAND` | ATM 土地銀行 |
| `ATM_CATHAY` | ATM 國泰世華 |
| `ATM_PANHSIN` | ATM 板信銀行 |
| `ATM_KGI` | ATM 凱基銀行 |
| `CVS_CVS` | 超商代碼 |
| `CVS_OK` | OK 超商代碼 |
| `CVS_FAMILY` | 全家超商代碼 |
| `CVS_HILIFE` | 萊爾富超商代碼 |
| `CVS_IBON` | 7-11 ibon 代碼 |
| `BARCODE_BARCODE` | 超商條碼 |
| `BNPL_URICH` | 裕富無卡分期 |
| `BNPL_ZINGALA` | 中租銀角零卡 |
| `DigitalPayment_Jkopay` | 街口支付 |
| `DigitalPayment_IPASS` | 一卡通 iPASS MONEY |

> 完整清單見 `references/Payment/全方位金流API技術文件.md` → 回覆付款方式一覽表。

### 信用卡交易查詢

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/QueryCreditTrade.php`

```php
$postService = $factory->create('PostWithCmvJsonResponseService');
$input = [
    'MerchantID'      => '3002607',
    'CreditRefundId'  => '信用卡退款編號',
    'CreditAmount'    => 100,
    'CreditCheckCode' => '授權碼',
];
$response = $postService->post(
    $input,
    'https://payment-stage.ecpay.com.tw/CreditDetail/QueryTrade/V2'
);
```

## 下載對帳檔

### AIO 對帳

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/DownloadReconcileCsv.php`

```php
$autoSubmitFormService = $factory->create('AutoSubmitFormWithCmvService');
$input = [
    'MerchantID'    => '3002607',
    'DateType'      => '2',
    'BeginDate'     => '2025-01-01',
    'EndDate'       => '2025-01-31',
    'MediaFormated' => '0',
];
echo $autoSubmitFormService->generate(
    $input,
    'https://vendor-stage.ecpay.com.tw/PaymentMedia/TradeNoAio'
);
```

#### 對帳檔格式說明

> ⚠️ 對帳端點使用 `vendor(-stage).ecpay.com.tw`，與其他 AIO 端點不同。

對帳檔為 **CSV/TSV 純文字格式**，主要欄位：

| 欄位 | 說明 |
|------|------|
| MerchantTradeNo | 特店訂單編號 |
| TradeNo | 綠界交易編號 |
| TradeDate | 交易日期 |
| TradeAmt | 交易金額 |
| PaymentType | 付款方式 |
| HandlingCharge | 手續費 |
| PaymentDate | 撥款日期 |

> 對帳檔通常在 **T+1 營業日**生成。建議每日排程下載前一日對帳檔，比對本地訂單記錄。
> 信用卡撥款對帳使用另一端點 `/CreditDetail/FundingReconDetail`。

### 信用卡對帳

> 原始範例：`scripts/SDK_PHP/example/Payment/Aio/DownloadCreditReconcileCsv.php`

```php
$input = [
    'MerchantID'  => '3002607',
    'PayDateType' => 'close',
    'StartDate'   => '2025-01-01',
    'EndDate'     => '2025-01-31',
];
echo $autoSubmitFormService->generate(
    $input,
    'https://payment-stage.ecpay.com.tw/CreditDetail/FundingReconDetail'
);
```

## 完整範例檔案對照

| 檔案 | 用途 | SDK Service |
|------|------|-------------|
| CreateOrder.php | 全部付款 (ALL) | AutoSubmitFormWithCmvService |
| CreateCreditOrder.php | 信用卡 | AutoSubmitFormWithCmvService |
| CreateInstallmentOrder.php | 分期 | AutoSubmitFormWithCmvService |
| CreatePeriodicOrder.php | 定期定額 | AutoSubmitFormWithCmvService |
| CreateAtmOrder.php | ATM | AutoSubmitFormWithCmvService |
| CreateCvsOrder.php | 超商代碼 | AutoSubmitFormWithCmvService |
| CreateBarcodeOrder.php | 條碼 | AutoSubmitFormWithCmvService |
| CreateWebAtmOrder.php | WebATM | AutoSubmitFormWithCmvService |
| CreateTwqrOrder.php | TWQR | AutoSubmitFormWithCmvService |
| CreateBnplOrder.php | BNPL (≥3000) | AutoSubmitFormWithCmvService |
| CreateWeiXinOrder.php | 微信支付 | AutoSubmitFormWithCmvService |
| GetCheckoutResponse.php | 付款結果處理 | VerifiedArrayResponse |
| QueryTrade.php | 查詢訂單 | PostWithCmvVerifiedEncodedStrResponseService |
| QueryPaymentInfo.php | 查詢付款資訊 | PostWithCmvVerifiedEncodedStrResponseService |
| QueryCreditTrade.php | 信用卡交易查詢 | PostWithCmvJsonResponseService |
| QueryPeridicTrade.php | 定期定額查詢 | PostWithCmvJsonResponseService |
| Capture.php | 請款/退款/取消 | PostWithCmvEncodedStrResponseService |
| CreditCardPeriodAction.php | 定期定額管理 | PostWithCmvEncodedStrResponseService |
| DownloadReconcileCsv.php | AIO 對帳 | AutoSubmitFormWithCmvService |
| DownloadCreditReconcileCsv.php | 信用卡對帳 | AutoSubmitFormWithCmvService |

## 參數邊界情況

| 參數 | 限制 | 說明 |
|------|------|------|
| MerchantTradeNo | 最大 20 字元 | 僅允許英數字，超過會被拒絕 |
| TotalAmount | 最小值 1 | 不可為 0，必須為正整數 |
| TradeDesc | 最大 200 字元 | 需 URL encode |
| ItemName | 最大 400 字元 | 含特殊字元 `#` 時需注意（`#` 是多品項分隔符號） |
| ItemName 含 `#` | 用於多品項分隔 | 若品名本身含 `#`，需 URL encode 為 `%23` |
| 金額一致性 | 必須 | `TotalAmount` 必須等於各 `ItemPrice × ItemCount` 的加總 |

## 生產等級 ReturnURL 處理

> ⚠️ **安全必做清單**
> 1. 驗證 MerchantID 為自己的
> 2. 比對金額與訂單記錄
> 3. 防重複處理（記錄已處理的 MerchantTradeNo）
> 4. 異常時仍回應 `1|OK`（避免重送風暴）
> 5. 記錄完整日誌（遮蔽 HashKey/HashIV）

```php
$factory = new Factory([
    'hashKey' => env('ECPAY_HASH_KEY'),
    'hashIv'  => env('ECPAY_HASH_IV'),
]);
$checkoutResponse = $factory->create(VerifiedArrayResponse::class);

try {
    $result = $checkoutResponse->get($_POST);

    // 1. 驗證 MerchantID 是否為自己的
    if ($result['MerchantID'] !== env('ECPAY_MERCHANT_ID')) {
        error_log('ECPay: MerchantID mismatch');
        echo '1|OK';
        return;
    }

    // 2. 比對金額與訂單記錄
    $order = findOrder($result['MerchantTradeNo']);
    if (!$order || (int)$result['TradeAmt'] !== $order->amount) {
        error_log('ECPay: Amount mismatch for ' . $result['MerchantTradeNo']);
        echo '1|OK';
        return;
    }

    // 3. 檢查 SimulatePaid（正式環境應為 '0'）
    if ($result['SimulatePaid'] !== '0') {
        error_log('ECPay: SimulatePaid detected in production');
        echo '1|OK';
        return;
    }

    // 4. 防重複處理（冪等性）
    if ($order->isPaid()) {
        echo '1|OK';
        return;
    }

    // 5. 處理付款結果
    if ($result['RtnCode'] === '1') {
        $order->markAsPaid($result['TradeNo']);
    }

    // 6. 記錄日誌（遮蔽敏感欄位）
    $logData = $result;
    unset($logData['CheckMacValue']);
    error_log('ECPay Payment: ' . json_encode($logData));

} catch (\Exception $e) {
    error_log('ECPay ReturnURL Error: ' . $e->getMessage());
}

// 無論成功或失敗，都必須回應 1|OK
echo '1|OK';
```

### CSRF 防護

AIO 表單是 POST 到 ECPay，不需要在 ECPay 端做 CSRF 保護。但你自己的「建立訂單」端點需要：

1. 在自己的「建立訂單」API 驗證 CSRF token
2. 驗證通過後才組裝參數並產生提交到 ECPay 的表單

### IP 白名單建議

建議 ReturnURL/PaymentInfoURL 端點檢查來源 IP，僅允許綠界伺服器回呼。可透過綠界客服索取回呼 IP 範圍。

### ReturnURL 重送機制

若未收到 `1|OK` 回應，綠界會在付款完成後的每 5-15 分鐘重送通知，每天最多重送 4 次。務必實作冪等性處理以避免重複入帳。

## 常見錯誤碼速查

| 錯誤碼 (RtnCode) | 含義 | 解決方式 |
|------------------|------|---------|
| 1 | 付款成功 | 正常處理訂單 |
| 2 | ATM 取號成功 | 等待消費者繳費，非最終結果 |
| 10100073 | CVS/BARCODE 取號成功 | 等待消費者繳費，非最終結果 |
| 10200095 | 交易已付款 | 重複付款，檢查訂單狀態 |
| 10200047 | MerchantTradeNo 重複 | 使用不同的訂單編號 |
| 10200073 | CheckMacValue 驗證失敗 | 檢查 HashKey/HashIV 和加密邏輯 |
| 10200115 | 信用卡授權逾時 | 請消費者重新付款 |
| 10200009 | 訂單已過期 | 檢查 ExpireDate 設定 |
| 10200058 | 信用卡授權失敗 | 請消費者確認卡片資訊 |
| 10300006 | 超商繳費期限已過 | 重新建立訂單 |
| 10100058 | ATM 繳費期限已過 | 重新建立訂單取號 |
| 10200050 | 金額不符 | 檢查 TotalAmount |
| 10100001 | 超商代碼已失效 | 重新取號 |
| 10200043 | 3D 驗證失敗 | 請消費者重試 |
| 10200105 | BNPL 金額未達最低 | TotalAmount 需 >= 3000 |

> 完整錯誤碼清單見 [guides/15-troubleshooting.md](./15-troubleshooting.md)

## 相關文件

- 官方 API 規格：`references/Payment/全方位金流API技術文件.md`（45 個 URL）
- CheckMacValue 解說：[guides/13-checkmacvalue.md](./13-checkmacvalue.md)
- 除錯指南：[guides/15-troubleshooting.md](./15-troubleshooting.md)
- 上線檢查：[guides/16-go-live-checklist.md](./16-go-live-checklist.md)
