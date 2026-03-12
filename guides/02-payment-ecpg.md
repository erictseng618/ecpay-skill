> 對應 ECPay API 版本 | 基於 PHP SDK ecpay/sdk | 最後更新：2026-03

# 站內付 2.0 完整指南

> ⚠️ **ECPG 使用兩個不同 Domain — 打錯立得 HTTP 404**
>
> | API 類別 | 測試 Domain | 正式 Domain |
> |---------|------------|------------|
> | Token 取得 API | `ecpg-stage.ecpay.com.tw` | `ecpg.ecpay.com.tw` |
> | 交易 / 查詢 / 請款 / 退款 API | `ecpayment-stage.ecpay.com.tw` | `ecpayment.ecpay.com.tw` |
>
> 先確認 Domain 再開始撰寫程式碼。

## 概述

站內付 2.0 是 ECPG 最常使用的服務，讓付款體驗嵌入你自己的頁面，消費者不需要跳轉到綠界。使用 AES 加密和 JSON 格式。適合需要自訂付款 UI 或綁卡功能的場景。

### 何時選擇站內付 2.0？

1. **嵌入式支付表單** — 不想讓消費者跳轉到綠界付款頁面
2. **前後端分離架構（React/Vue/Angular/SPA）** — 需要 API 模式而非 Form POST
3. **綁卡與定期定額** — 需要完整的 Token 管理
4. **App 支付** — iOS/Android 原生付款體驗（含 Apple Pay）

> 若只是簡單線上收款，**AIO（[guides/01](./01-payment-aio.md)）更簡單**，30 分鐘即可完成串接。

> **只做 Web 整合？** 直接跳到 [一般付款流程](#一般付款流程)。
> **只做 App 整合？** 直接跳到 [Web vs App 整合差異](#web-vs-app-整合差異)。

> **⚠️⚠️⚠️ ECPG 最常見錯誤：Domain 打錯 = 404**
>
> ECPG 使用**兩個不同的 domain**，搞混必定 404：
>
> | 用途 | Domain | 端點範例 |
> |------|--------|---------|
> | Token / 建立交易 | **ecpg**(-stage).ecpay.com.tw | GetTokenbyTrade, CreatePayment |
> | 查詢 / 請退款 | **ecpayment**(-stage).ecpay.com.tw | QueryTrade, DoAction |
>
> **錯誤範例**：把 QueryTrade 打到 `ecpg.ecpay.com.tw` → 404
> **正確做法**：對照下方[端點 URL 一覽](#端點-url-一覽)確認每個 API 的 domain

### 內部導航

| 區塊 | 說明 |
|------|------|
| [ECPG vs AIO 差異](#ecpg-vs-aio-差異) | 選型比較 |
| [HTTP 協議速查](#http-協議速查非-php-語言必讀) | 端點、加密、請求格式 |
| [一般付款流程](#一般付款流程) | GetToken → CreatePayment → 處理回應 |
| [前端 JavaScript SDK 整合](#前端-javascript-sdk-整合) | JS SDK 嵌入付款表單 |
| [綁卡付款流程](#綁卡付款流程) | Token 綁定 + 扣款 |
| [會員綁卡管理](#會員綁卡管理) | 查詢/刪除綁卡 |
| [請款 / 退款](#請款--退款) | DoAction 操作 |
| [定期定額管理](#定期定額管理) | 訂閱扣款管理 |
| [查詢](#查詢) | 訂單/信用卡/付款資訊/定期定額查詢 |
| [對帳](#對帳) | 對帳檔下載 |
| [Web vs App 整合差異](#web-vs-app-整合差異) | iOS/Android 原生 SDK + WebView |
| [安全注意事項](#安全注意事項) | GetResponse 安全處理 |
| [常見錯誤碼速查](#常見錯誤碼速查) | TransCode + RtnCode |

## ECPG vs AIO 差異

| 面向 | AIO | ECPG |
|------|-----|------|
| 付款頁面 | 導向綠界頁面 | 嵌入你的頁面 |
| 加密方式 | CheckMacValue (SHA256) | AES-128-CBC |
| 請求格式 | Form POST (URL-encoded) | JSON POST |
| 請求結構 | 扁平 key=value | 三層：MerchantID + RqHeader + Data |
| 綁卡功能 | 有限 | 完整（Token 綁定） |
| 前後端分離 | 不需要 | 前端取 Token → 後端建立交易 |
| App 整合 | 無 | 支援（原生 SDK 取 Token） |

## 前置需求

- MerchantID / HashKey / HashIV（測試：3002607 / pwFHCqoQZGmho4w6 / EkRm7iFT261dpevs）
- PHP SDK：`composer require "ecpay/sdk:^4.0"`
- SDK Service：`PostWithAesJsonResponseService`

## HTTP 協議速查（非 PHP 語言必讀）

| 項目 | 規格 |
|------|------|
| 協議模式 | AES-JSON — 詳見 [guides/20-http-protocol-reference.md](./20-http-protocol-reference.md) |
| HTTP 方法 | POST |
| Content-Type | `application/json` |
| 認證 | AES-128-CBC 加密 Data 欄位 — 詳見 [guides/14-aes-encryption.md](./14-aes-encryption.md) |
| Token 環境 | `https://ecpg-stage.ecpay.com.tw`（測試） / `https://ecpg.ecpay.com.tw`（正式） |
| 交易/查詢環境 | `https://ecpayment-stage.ecpay.com.tw`（測試） / `https://ecpayment.ecpay.com.tw`（正式） |
| 回應結構 | 三層 JSON（TransCode → 解密 Data → RtnCode） |
| Callback 回應 | `1\|OK`（官方規格 9058.md） |

> **注意**：ECPG 使用**兩個不同 domain** — Token 相關（GetTokenbyTrade/GetTokenbyUser/CreatePayment）走 `ecpg`，查詢/請退款走 `ecpayment`。詳見 [guides/20 ECPG 端點表](./20-http-protocol-reference.md)。

> ⚠️ **SNAPSHOT 2026-03** | 來源：`references/Payment/站內付2.0API技術文件Web.md`（或 App 版）
> 以下端點及參數僅供整合流程理解，不可直接作為程式碼生成依據。**生成程式碼前必須 web_fetch 來源文件取得最新規格。**

### 端點 URL 一覽

| 功能 | 端點路徑 | Base Domain |
|------|---------|------------|
| **── Token / 建立交易（ecpg domain）──** | | |
| 以交易取 Token | `/Merchant/GetTokenbyTrade` | **ecpg** |
| 以會員取 Token | `/Merchant/GetTokenbyUser` | **ecpg** |
| 建立交易 | `/Merchant/CreatePayment` | **ecpg** |
| 綁卡取 Token | `/Merchant/GetTokenbyBindingCard` | **ecpg** |
| 建立綁卡 | `/Merchant/CreateBindCard` | **ecpg** |
| 以卡號付款 | `/Merchant/CreatePaymentWithCardID` | **ecpg** |
| 查詢會員綁卡 | `/Merchant/GetMemberBindCard` | **ecpg** |
| 刪除會員綁卡 | `/Merchant/DeleteMemberBindCard` | **ecpg** |
| ⚠️ *上方 5 個綁卡端點尚無獨立官方文件 URL，參數規格以 SDK 範例為準* | | |
| **── 查詢 / 請退款（ecpayment domain）──** | | |
| 信用卡請退款 | `/1.0.0/Credit/DoAction` | **ecpayment** |
| 查詢訂單 | `/1.0.0/Cashier/QueryTrade` | **ecpayment** |
| 信用卡明細查詢 | `/1.0.0/CreditDetail/QueryTrade` | **ecpayment** |
| 定期定額查詢 | `/1.0.0/Cashier/QueryTrade` | **ecpayment** |
| 定期定額作業 | `/1.0.0/Cashier/CreditCardPeriodAction` | **ecpayment** |
| 取號結果查詢 | `/1.0.0/Cashier/QueryPaymentInfo` | **ecpayment** |
| 下載撥款對帳檔 | `/1.0.0/Cashier/QueryTradeMedia` | **ecpayment** |

## AES 三層請求結構

所有 ECPG API 都使用相同的外層結構：

```json
{
  "MerchantID": "3002607",
  "RqHeader": {
    "Timestamp": 1234567890
  },
  "Data": "AES加密後的Base64字串"
}
```

Data 欄位的加解密流程：見 [guides/14-aes-encryption.md](./14-aes-encryption.md)

## 一般付款流程

### 步驟 1：前端取得 Token

前端根據付款方式，呼叫不同的 GetToken API 取得 `PayToken`。

#### 8 種付款方式的 GetToken 差異

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/Create*Order/GetToken.php`

| 付款方式 | ChoosePaymentList | 專用參數物件 | 範例檔案 |
|---------|------------------|-------------|---------|
| 全部 | "0" | CardInfo + UnionPayInfo + ATMInfo + CVSInfo + BarcodeInfo | CreateAllOrder/GetToken.php |
| 信用卡 | "1" | CardInfo（Redeem, OrderResultURL） | CreateCreditOrder/GetToken.php |
| 分期 | "2,8" | CardInfo（CreditInstallment, FlexibleInstallment） | CreateInstallmentOrder/GetToken.php |
| ATM | "3" | ATMInfo（ExpireDate） | CreateAtmOrder/GetToken.php |
| 超商代碼 | "4" | CVSInfo（StoreExpireDate） | CreateCvsOrder/GetToken.php |
| 條碼 | "5" | BarcodeInfo（StoreExpireDate） | CreateBarcodeOrder/GetToken.php |
| 銀聯 | "6" | UnionPayInfo（OrderResultURL） | CreateUnionPayOrder/GetToken.php |
| Apple Pay | "7" | （無額外參數） | CreateApplePayOrder/GetToken.php |

**端點**：`POST https://ecpg-stage.ecpay.com.tw/Merchant/GetTokenbyTrade`

**完整 GetToken 請求**（以全方位為例）：

```php
$postService = $factory->create('PostWithAesJsonResponseService');
$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => ['Timestamp' => time()],
    'Data'       => [
        'MerchantID'       => '3002607',
        'RememberCard'     => 1,
        'PaymentUIType'    => 2,
        'ChoosePaymentList'=> '0',
        'OrderInfo' => [
            'MerchantTradeDate' => date('Y/m/d H:i:s'),
            'MerchantTradeNo'   => 'Test' . time(),
            'TotalAmount'       => 100,
            'ReturnURL'         => 'https://你的網站/ecpay/notify',
            'TradeDesc'         => '測試交易',
            'ItemName'          => '測試商品',
        ],
        'CardInfo' => [
            'Redeem'            => '0',
            'OrderResultURL'    => 'https://你的網站/ecpay/result',
            'CreditInstallment' => '3,6,12',
        ],
        'ATMInfo'     => ['ExpireDate' => 3],
        'CVSInfo'     => ['StoreExpireDate' => 10080],
        'BarcodeInfo' => ['StoreExpireDate' => 7],
        'ConsumerInfo'=> [
            'MerchantMemberID' => 'member001',
            'Email'  => 'test@example.com',
            'Phone'  => '0912345678',
            'Name'   => '測試',
            'CountryCode' => '158',
        ],
    ],
];
try {
    $response = $postService->post($input, 'https://ecpg-stage.ecpay.com.tw/Merchant/GetTokenbyTrade');
    // 解密 Data 取得 Token
    $token = $response['Data']['Token'] ?? null;
    if (!$token) {
        error_log('ECPG GetToken failed: ' . json_encode($response));
    }
} catch (\Exception $e) {
    error_log('ECPG GetToken Error: ' . $e->getMessage());
}
```

回應的 Data 解密後包含 `Token`，傳給前端 JavaScript SDK 顯示付款介面。

### 前端 JavaScript SDK 整合

後端 GetToken 呼叫取得 Token 後，在前端使用 ECPay JavaScript SDK：

```
> 原始範例：scripts/SDK_PHP/example/Payment/Ecpg/CreateCreditOrder/WebJS.html
```

**1. 引入 ECPay JavaScript SDK**
```html
<!-- 測試環境 -->
<script src="https://ecpg-stage.ecpay.com.tw/Scripts/sdk-1.0.0.js"></script>
<!-- 正式環境 -->
<script src="https://ecpg.ecpay.com.tw/Scripts/sdk-1.0.0.js"></script>
```

> **JS SDK 版本**：上方 `sdk-1.0.0.js` 為本文件撰寫時的版本。ECPay 可能更新 SDK 版本，
> 請以[綠界站內付官方文件](https://developers.ecpay.com.tw/)中的最新版本路徑為準。

> **CSP（Content Security Policy）設定**：若你的網站啟用了 CSP header，需允許 ECPay domain：
> - `script-src`: 加入 `https://ecpg.ecpay.com.tw`（正式）或 `https://ecpg-stage.ecpay.com.tw`（測試）
> - `frame-src`: 同上（SDK 會使用 iframe 渲染付款表單）
> - `connect-src`: 同上（SDK 內部 API 呼叫）

**2. 初始化 SDK**
```javascript
// envi: 0=正式, 1=測試
// type: 1=Web
ECPay.initialize(envi, 1, function(errMsg) {
    console.error('SDK 初始化失敗:', errMsg);
});
```

**3. 渲染付款 UI**
```javascript
// _token: 後端 GetTokenbyTrade 取得的 Token
// language: 'zh-TW', 'en-US', etc.
ECPay.createPayment(_token, language, function(errMsg) {
    console.error('建立付款 UI 失敗:', errMsg);
}, 'V2');
```

**4. 取得 PayToken（消費者填完付款資訊後）**
```javascript
ECPay.getPayToken(function(payToken, errMsg) {
    if (errMsg) {
        console.error('取得 PayToken 失敗:', errMsg);
        return;
    }
    // 將 payToken 送到後端建立交易
    submitPayment(payToken);
});
```

> ⚠️ **常見陷阱：payToken 是字串**
> `getPayToken` 回呼的第一個參數 `payToken` 是**純字串**（如 `"a1b2c3d4..."`）。
> 常見錯誤是將整個回呼物件或包裝過的結構送往後端，導致後端收到 `[object Object]` 而非 Token 字串。
> 確認送往後端的值為 `typeof payToken === 'string'`。

#### 語系設定

付款介面支援切換語系，透過 `createPayment` 的第二個參數指定：

```javascript
// 語系作為 createPayment 的第二個參數傳入
ECPay.createPayment(_token, 'en-US', function(errMsg) {
    if (errMsg != null) console.error(errMsg);
}, 'V2');
```

支援語系：`zh-TW`（繁體中文，預設）、`en-US`（英文）。

查詢目前語系設定：`ECPay.getLanguage()` — 回傳當前 SDK 語系字串。

#### WebJS 範例檔案對照

| 付款方式 | WebJS 範例檔案 |
|---------|---------------|
| 信用卡 | `scripts/SDK_PHP/example/Payment/Ecpg/CreateCreditOrder/WebJS.html` |
| 分期 | `scripts/SDK_PHP/example/Payment/Ecpg/CreateInstallmentOrder/WebJS.html` |
| ATM | `scripts/SDK_PHP/example/Payment/Ecpg/CreateAtmOrder/WebJS.html` |
| 超商代碼 | `scripts/SDK_PHP/example/Payment/Ecpg/CreateCvsOrder/WebJS.html` |
| 條碼 | `scripts/SDK_PHP/example/Payment/Ecpg/CreateBarcodeOrder/WebJS.html` |
| 銀聯 | `scripts/SDK_PHP/example/Payment/Ecpg/CreateUnionPayOrder/WebJS.html` |
| Apple Pay | `scripts/SDK_PHP/example/Payment/Ecpg/CreateApplePayOrder/WebJS.html` |
| 全部 | `scripts/SDK_PHP/example/Payment/Ecpg/CreateAllOrder/WebJS.html` |
| 綁卡 | `scripts/SDK_PHP/example/Payment/Ecpg/CreateBindCardOrder/WebJS.html` |

### 步驟 2：後端建立交易

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/CreateOrder.php`

消費者在前端完成付款後，前端取得 `PayToken`，送到後端：

```php
$postService = $factory->create('PostWithAesJsonResponseService');
$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => ['Timestamp' => time()],
    'Data'       => [
        'MerchantID'      => '3002607',
        'PayToken'        => $_POST['PayToken'],
        'MerchantTradeNo' => $_POST['MerchantTradeNo'],
    ],
];
try {
    $response = $postService->post($input, 'https://ecpg-stage.ecpay.com.tw/Merchant/CreatePayment');
    // 檢查 TransCode 是否為 1（成功）
} catch (\Exception $e) {
    error_log('ECPG CreatePayment Error: ' . $e->getMessage());
}
```

### 步驟 3：處理回應

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/GetResponse.php`

ReturnURL / OrderResultURL 收到的 POST 需要 AES 解密。

> ⚠️ **常見陷阱：OrderResultURL 是 Form POST，ReturnURL 是 JSON POST**
> 站內付 2.0 有兩個 Callback URL，格式不同（官方規格 15076.md / 9058.md）：
> - **OrderResultURL**：3D 驗證完成後，綠界透過瀏覽器 Form POST（`Content-Type: application/x-www-form-urlencoded`）將結果導至特店頁面。資料放在表單欄位 **`ResultData`**（AES 加密的 Base64 字串），**不是** JSON body。非 PHP 語言常見錯誤：用 `request.json()` 解析 → 出錯。**正確做法**：用 form data 讀取（如 Python `request.form['ResultData']`、Node.js `req.body.ResultData`），再 AES 解密。
> - **ReturnURL**：Server-to-Server POST（`Content-Type: application/json`），JSON body 直接包含三層結構（TransCode + Data），用 `json_decode(file_get_contents('php://input'))` 讀取。

ReturnURL 收到的 JSON 結構（OrderResultURL 則需先從 `ResultData` 欄位 AES 解密才得到此結構）：

```json
{
    "MerchantID": "3002607",
    "RpHeader": { "Timestamp": 1234567890 },
    "TransCode": 1,
    "TransMsg": "Success",
    "Data": "AES加密後的Base64字串"
}
```

解密處理：

```php
$aesService = $factory->create(AesService::class);

// ReturnURL 是 JSON POST（application/json），需從 php://input 讀取
$jsonBody = json_decode(file_get_contents('php://input'), true);
// OrderResultURL 則是 Form POST，資料在 $_POST['ResultData']

// 先檢查 TransCode 確認 API 是否成功
$transCode = $jsonBody['TransCode'] ?? null;
if ($transCode != 1) {
    error_log('ECPay TransCode Error: ' . ($jsonBody['TransMsg'] ?? 'unknown'));
}

// 解密 Data 取得交易細節
$decryptedData = $aesService->decrypt($jsonBody['Data']);
// $decryptedData 包含：RtnCode, RtnMsg, MerchantID, Token, TokenExpireDate 等

// 回應 1|OK（官方規格 9058.md）
echo '1|OK';
```

#### Response 欄位表

所有 ECPG API 回應的外層結構一致：

```json
{
  "MerchantID": "3002607",
  "RpHeader": { "Timestamp": 1234567890 },
  "TransCode": 1,
  "TransMsg": "Success",
  "Data": "AES加密的Base64字串（解密後為 JSON）"
}
```

| 欄位 | 型別 | 說明 |
|------|------|------|
| MerchantID | String | 特店代號 |
| RpHeader.Timestamp | Long | 回應時間戳 |
| TransCode | Int | 外層狀態碼（1=成功） |
| TransMsg | String | 外層訊息 |
| Data | String | AES 加密的業務資料（Base64） |

Data 解密後常見欄位：

| 欄位 | 說明 |
|------|------|
| RtnCode | 業務結果碼（1=成功） |
| RtnMsg | 業務結果訊息 |
| TradeNo | ECPay 交易編號 |
| MerchantTradeNo | 特店訂單編號 |

#### 3D Secure 驗證跳轉（必處理）

> ⚠️ 自 2025/8 起 3D Secure 2.0 已強制實施，信用卡交易的 CreatePayment 回應中**幾乎一定會包含 `ThreeDURL`**。

CreatePayment 的 Data 解密後，若包含 `ThreeDURL` 欄位（非空字串），代表此筆交易需要 3D 驗證。**前端必須將消費者導向該 URL 完成驗證**，否則交易將逾時失敗。

```javascript
// 後端 CreatePayment 回應解密後回傳給前端
const result = await response.json();

if (result.ThreeDURL) {
    // 必須跳轉至 3D 驗證頁面
    window.location.href = result.ThreeDURL;
} else if (result.RtnCode === 1) {
    // 不需 3D 驗證，交易直接成功
    showSuccess(result);
} else {
    showError(result.RtnMsg);
}
```

> **注意**：3D 驗證完成後，綠界會將結果 POST 至 OrderResultURL（前端顯示）和 ReturnURL（後端通知），流程與一般付款回呼相同。

## 綁卡付款流程

### 步驟 1：取得綁卡 Token

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/GetTokenbyBindingCard.php`

```php
$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => ['Timestamp' => time()],
    'Data'       => [
        'PlatformID' => '',  // 綁卡 API 可為空字串
        'MerchantID' => '3002607',
        'ConsumerInfo' => [
            'MerchantMemberID' => 'member001',
            'Email'  => 'test@example.com',
            'Phone'  => '0912345678',
            'Name'   => '測試',
            'CountryCode' => '158',
        ],
        'OrderInfo' => [
            'MerchantTradeDate' => date('Y/m/d H:i:s'),
            'MerchantTradeNo'   => 'Bind' . time(),
            'TotalAmount'       => '100',  // 字串型別，綁卡驗證金額
            'TradeDesc'         => '綁卡驗證',
            'ItemName'          => '綁卡',
            'ReturnURL'         => 'https://你的網站/ecpay/notify',
        ],
        'OrderResultURL' => 'https://你的網站/ecpay/bind-result',
        'CustomField'    => '自訂欄位',
    ],
];
$response = $postService->post($input, 'https://ecpg-stage.ecpay.com.tw/Merchant/GetTokenbyBindingCard');
```

### 步驟 2：前端 3D 驗證後建立綁卡

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/CreateBindCard.php`

```php
$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => ['Timestamp' => time()],
    'Data'       => [
        'MerchantID'       => '3002607',
        'BindCardPayToken' => $_POST['BindCardPayToken'],
        'MerchantMemberID' => 'member001',
    ],
];
$response = $postService->post($input, 'https://ecpg-stage.ecpay.com.tw/Merchant/CreateBindCard');
```

### 步驟 3：處理綁卡結果

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/GetCreateBindCardResponse.php`

```php
$resultData = json_decode($_POST['ResultData'], true);
$aesService = $factory->create(AesService::class);
$decrypted = $aesService->decrypt($resultData['Data']);
// $decrypted 包含：BindCardID, CardInfo (Card6No, Card4No 等), OrderInfo
```

### 步驟 4：日後用綁卡扣款

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/CreatePaymentWithCardID.php`

```php
$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => ['Timestamp' => time()],
    'Data'       => [
        'PlatformID' => '',
        'MerchantID' => '3002607',
        'BindCardID' => '綁卡時取得的ID',
        'OrderInfo'  => [
            'MerchantTradeDate' => date('Y/m/d H:i:s'),
            'MerchantTradeNo'   => 'Pay' . time(),
            'TotalAmount'       => 500,
            'ReturnURL'         => 'https://你的網站/ecpay/notify',
            'TradeDesc'         => '綁卡扣款',
            'ItemName'          => '商品',
        ],
        'ConsumerInfo' => [
            'MerchantMemberID' => 'member001',
            'Email'  => 'test@example.com',
            'Phone'  => '0912345678',
            'Name'   => '測試',
            'CountryCode' => '158',
            'Address'=> '測試地址',
        ],
        'CustomField' => '',
    ],
];
$response = $postService->post($input, 'https://ecpg-stage.ecpay.com.tw/Merchant/CreatePaymentWithCardID');
```

## 會員綁卡管理

### 查詢會員綁卡

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/GetMemberBindCard.php`

```php
$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => ['Timestamp' => time()],
    'Data'       => [
        'PlatformID'       => '',
        'MerchantID'       => '3002607',
        'MerchantMemberID' => 'member001',
        'MerchantTradeNo'  => 'Query' . time(),
    ],
];
$response = $postService->post($input, 'https://ecpg-stage.ecpay.com.tw/Merchant/GetMemberBindCard');
```

### 刪除會員綁卡

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/DeleteMemberBindCard.php`

```php
$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => ['Timestamp' => time()],
    'Data'       => [
        'PlatformID' => '',
        'MerchantID' => '3002607',
        'BindCardID' => '要刪除的綁卡ID',
    ],
];
$response = $postService->post($input, 'https://ecpg-stage.ecpay.com.tw/Merchant/DeleteMemberBindCard');
```

### 綁卡管理（讓消費者自行管理綁定的信用卡）

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/DeleteCredit.php`

此端點 `GetTokenbyUser` 取得 Token 後，消費者可在綠界管理頁面中自行檢視和刪除已綁定的信用卡。

```php
$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => ['Timestamp' => time()],
    'Data'       => [
        'MerchantID'  => '3002607',
        'ConsumerInfo'=> [
            'MerchantMemberID' => 'member001',
            'Email'  => 'test@example.com',
            'Phone'  => '0912345678',
            'Name'   => '測試',
            'CountryCode' => '158',
        ],
    ],
];
$response = $postService->post($input, 'https://ecpg-stage.ecpay.com.tw/Merchant/GetTokenbyUser');
```

## 請款 / 退款

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/Capture.php`

**注意**：ECPG 的請款/退款端點在 `ecpayment-stage.ecpay.com.tw`，不是 `ecpg-stage`。

```php
$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => ['Timestamp' => time()],
    'Data'       => [
        'PlatformID'      => '3002607',  // 一般商店填 MerchantID；平台模式填平台商 ID
        'MerchantID'      => '3002607',
        'MerchantTradeNo' => '你的訂單編號',
        'TradeNo'         => '綠界交易編號',
        'Action'          => 'C',  // C=請款, R=退款, E=取消, N=放棄
        'TotalAmount'     => 100,
    ],
];
$response = $postService->post($input, 'https://ecpayment-stage.ecpay.com.tw/1.0.0/Credit/DoAction');
```

## 定期定額管理

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/CreditPeriodAction.php`

```php
$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => ['Timestamp' => time()],
    'Data'       => [
        'PlatformID'      => '3002607',  // 一般商店填 MerchantID；平台模式填平台商 ID
        'MerchantID'      => '3002607',
        'MerchantTradeNo' => '你的訂閱訂單編號',
        'Action'          => 'ReAuth',  // ReAuth=重新授權, Cancel=取消
    ],
];
$response = $postService->post($input, 'https://ecpayment-stage.ecpay.com.tw/1.0.0/Cashier/CreditCardPeriodAction');
```

## 查詢

### 一般查詢

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/QueryTrade.php`

```php
$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => ['Timestamp' => time()],
    'Data'       => [
        'PlatformID'      => '3002607',  // 一般商店填 MerchantID；平台模式填平台商 ID
        'MerchantID'      => '3002607',
        'MerchantTradeNo' => '你的訂單編號',
    ],
];
$response = $postService->post($input, 'https://ecpayment-stage.ecpay.com.tw/1.0.0/Cashier/QueryTrade');
```

### 信用卡交易查詢

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/QueryCreditTrade.php`

端點：`POST https://ecpayment-stage.ecpay.com.tw/1.0.0/CreditDetail/QueryTrade`

### 付款資訊查詢

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/QueryPaymentInfo.php`

端點：`POST https://ecpayment-stage.ecpay.com.tw/1.0.0/Cashier/QueryPaymentInfo`

### 定期定額查詢

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/QueryPeridicTrade.php`

端點：`POST https://ecpayment-stage.ecpay.com.tw/1.0.0/Cashier/QueryTrade`（同一般查詢端點）

## 對帳

> 原始範例：`scripts/SDK_PHP/example/Payment/Ecpg/QueryTradeMedia.php`

此 API 需要手動 AES 加解密，且回傳 CSV 而非 JSON，因此使用 `CurlService` 手動設定 header：

```php
use Ecpay\Sdk\Services\AesService;
use Ecpay\Sdk\Services\CurlService;

$aesService = $factory->create(AesService::class);
$curlService = $factory->create(CurlService::class);

$data = [
    'MerchantID'  => '3002607',
    'DateType'    => '2',
    'BeginDate'   => '2025-01-01',
    'EndDate'     => '2025-01-31',
    'PaymentType' => '01',  // 注意：是 '01' 不是 '0'
];

$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => ['Timestamp' => time()],
    'Data'       => $aesService->encrypt($data),
];

// 手動設定 JSON header 並呼叫
$curlService->setHeaders(['Content-Type:application/json']);
$result = $curlService->run(json_encode($input), 'https://ecpayment-stage.ecpay.com.tw/1.0.0/Cashier/QueryTradeMedia');

// 回傳是 CSV 檔案內容，直接存檔
$filepath = 'QueryTradeMedia' . time() . '.csv';
file_put_contents($filepath, $result);
```

> **注意**：此 API 回傳的是 CSV 格式的對帳資料，不是 JSON。需用 `CurlService` 的 `run()` 方法（而非 `post()`）並手動設定 `Content-Type:application/json` header。

## Web vs App 整合差異

ECPG 支援 Web 和 App 兩種整合方式：

| 面向 | Web | App (iOS/Android) |
|------|-----|-------------------|
| 取 Token 方式 | JavaScript SDK | 原生 SDK (ECPayPaymentGatewayKit) |
| 付款 UI | Web 頁面中的 iframe 或嵌入式元件 | 原生 SDK 提供的付款畫面 |
| 後端 API | 完全相同 | 完全相同 |
| GetToken 端點 | 相同 | 相同 |
| CreatePayment | 相同 | 相同 |

### 原生 SDK vs WebView 方案比較

| 比較項目 | 原生 SDK（ECPayPaymentGatewayKit） | WebView 嵌入 |
|---------|----------------------------------|-------------|
| 付款體驗 | 原生 UI，體驗最佳 | 網頁嵌入，體驗次之 |
| 開發成本 | 需整合原生 SDK，iOS/Android 各一份 | 共用 Web 付款頁面，開發量較少 |
| 維護成本 | SDK 版本升級需重新發布 App | Web 端更新即可，無需發布 App |
| Apple Pay 支援 | 完整支援（需原生 SDK） | 不支援 |
| 3D Secure | SDK 內建處理 | 需自行處理 WebView 導向 |
| 適用場景 | 重視付款體驗、需要 Apple Pay | 快速上線、跨平台共用 |

> **建議**：如需 Apple Pay 或追求最佳付款體驗，使用原生 SDK；如需快速上線或以 React Native / Flutter 開發，使用 WebView 方案。

### iOS 原生 SDK 初始化概要

> 官方文件：`references/Payment/站內付2.0API技術文件App.md` — iOS APP SDK / 初始化、使用說明

**1. 安裝 SDK**

透過 CocoaPods 或手動匯入 `ECPayPaymentGatewayKit.framework`：

```ruby
# Podfile（如官方提供 CocoaPods 支援）
pod 'ECPayPaymentGatewayKit'
```

**2. 初始化 SDK**

```swift
import ECPayPaymentGatewayKit

// 建立 SDK 實例
// serverType: .Stage（測試）或 .Prod（正式）
let ecpaySDK = ECPayPaymentGatewayManager(
    serverType: .Stage,
    merchantID: "3002607"
)
```

**3. 取得付款畫面**

```swift
// token: 從後端 GetTokenbyTrade API 取得
ecpaySDK.createPayment(token: token, language: "zh-TW") { result in
    switch result {
    case .success(let payToken):
        // 將 payToken 送到後端呼叫 CreatePayment
        self.submitPayment(payToken: payToken)
    case .failure(let error):
        print("付款失敗: \(error.localizedDescription)")
    }
}
```

**4. 自訂 Title Bar 顏色**（選用）

```swift
ecpaySDK.setTitleBarColor(UIColor(red: 0.0, green: 0.5, blue: 0.3, alpha: 1.0))
```

### Android 原生 SDK 初始化概要

> 官方文件：`references/Payment/站內付2.0API技術文件App.md` — Android APP SDK / 初始化、使用說明

**1. 安裝 SDK**

在 `build.gradle` 加入 ECPay SDK 依賴（或手動匯入 .aar 檔案）：

```groovy
dependencies {
    implementation files('libs/ECPayPaymentGatewayKit.aar')
}
```

**2. 初始化 SDK**

```kotlin
import com.ecpay.paymentgatewaykit.ECPayPaymentGatewayManager

// serverType: ServerType.Stage（測試）或 ServerType.Prod（正式）
val ecpaySDK = ECPayPaymentGatewayManager(
    context = this,
    serverType = ServerType.Stage,
    merchantID = "3002607"
)
```

**3. 取得付款畫面**

```kotlin
// token: 從後端 GetTokenbyTrade API 取得
ecpaySDK.createPayment(token = token, language = "zh-TW") { result ->
    if (result.isSuccess) {
        val payToken = result.payToken
        // 將 payToken 送到後端呼叫 CreatePayment
        submitPayment(payToken)
    } else {
        Log.e("ECPay", "付款失敗: ${result.errorMessage}")
    }
}
```

**4. 設定畫面方向**（選用）

```kotlin
ecpaySDK.setScreenOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT)
```

### Apple Pay 前置準備

> 官方文件：`references/Payment/站內付2.0API技術文件App.md` — 準備事項 / Apple Pay開發者前置準備說明

使用 Apple Pay 付款需完成以下前置作業：

| 步驟 | 說明 |
|------|------|
| 1. Apple Developer 帳號 | 需擁有付費的 Apple Developer Program 帳號 |
| 2. Merchant ID 註冊 | 在 Apple Developer 後台建立 Merchant ID |
| 3. 憑證申請 | 產生 Payment Processing Certificate 並提供給綠界 |
| 4. Xcode 設定 | 在 Xcode 專案的 Capabilities 啟用 Apple Pay 並綁定 Merchant ID |
| 5. 綠界後台設定 | 在綠界商戶後台啟用 Apple Pay 並上傳憑證 |
| 6. 域名驗證 | 將 Apple 提供的驗證檔案放在你的網站根目錄 |

> **注意**：Apple Pay 僅支援 iOS 原生 SDK 方式整合，WebView 方案不支援 Apple Pay。GetToken 時 `ChoosePaymentList` 須帶 `"7"`。

> **iOS Apple Pay 進階**：如需自訂 Apple Pay 付款體驗或延遲付款授權，
> 請參閱官方文件 `references/Payment/站內付2.0API技術文件App.md` 中的 Apple Pay 專區。

### App 端整合流程

1. **iOS**：透過 CocoaPods 或手動匯入整合 ECPay SDK
2. **Android**：透過 Gradle 依賴或手動匯入 .aar 整合 ECPay SDK
3. App 呼叫原生 SDK 的 `createPayment` 方法，傳入 Token（從後端 GetTokenbyTrade 取得）
4. 消費者在原生付款畫面完成付款
5. SDK 回傳 `PayToken` 給 App
6. App 將 `PayToken` 送到後端，呼叫 `CreatePayment`（與 Web 相同）

### App 專屬注意事項

- App 端的 `OrderResultURL` 需設定為可被 App 攔截的 URL scheme 或 Universal Link
- 3D Secure 驗證在 App 中會開啟 WebView
- 測試時需使用實機，模擬器可能無法完整測試付款流程
- Apple Pay 僅支援 iOS 原生 SDK，不支援 WebView 或 Android

### iOS (Swift) WebView 整合範例

```swift
import WebKit

class PaymentViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.navigationDelegate = self
        view.addSubview(webView)

        // 從後端取得 ECPG Token 後，載入付款頁面
        if let url = URL(string: "https://你的後端/ecpg/payment-page?token=\(payToken)") {
            webView.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 攔截付款完成的回呼 URL
        if let url = navigationAction.request.url,
           url.host == "你的網站" && url.path.contains("/payment/complete") {
            handlePaymentResult(url: url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
```

### Android (Kotlin) WebView 整合範例

```kotlin
class PaymentActivity : AppCompatActivity() {
    private lateinit var webView: WebView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_payment)

        webView = findViewById(R.id.paymentWebView)
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val url = request?.url?.toString() ?: return false
                // 攔截付款完成的回呼 URL
                if (url.contains("/payment/complete")) {
                    handlePaymentResult(url)
                    return true
                }
                return false
            }
        }

        // 從後端取得 ECPG Token 後，載入付款頁面
        val payToken = intent.getStringExtra("payToken")
        webView.loadUrl("https://你的後端/ecpg/payment-page?token=$payToken")
    }
}
```

### React Native 整合建議

```javascript
import { WebView } from 'react-native-webview';

function PaymentScreen({ payToken, onComplete }) {
  return (
    <WebView
      source={{ uri: `https://你的後端/ecpg/payment-page?token=${payToken}` }}
      onNavigationStateChange={(navState) => {
        if (navState.url.includes('/payment/complete')) {
          onComplete(navState.url);
        }
      }}
      javaScriptEnabled={true}
      domStorageEnabled={true}
    />
  );
}
```

### App 環境注意事項

| 項目 | 說明 |
|------|------|
| WebView User-Agent | 建議設定自訂 User-Agent，避免被當作爬蟲攔截 |
| Deep Link 回呼 | iOS 使用 Universal Link、Android 使用 App Links 處理付款完成回呼 |
| 外部瀏覽器 vs WebView | WebView 嵌入體驗好但需處理回呼；外部瀏覽器相容性高但體驗較差 |
| 3D Secure | 3D 驗證會在 WebView 中開啟，確保 WebView 支援 JavaScript 和 DOM Storage |
| Cookie 設定 | iOS 需允許 third-party cookies（`WKWebViewConfiguration.websiteDataStore`） |

詳細 App SDK 規格見：`references/Payment/站內付2.0API技術文件App.md`（39 個 URL）

## 安全注意事項

> ⚠️ **安全必做清單**
> 1. 驗證 MerchantID 為自己的
> 2. 比對金額與訂單記錄
> 3. 防重複處理（記錄已處理的 MerchantTradeNo）
> 4. 異常時仍回應 `1|OK`（避免重送風暴）
> 5. 記錄完整日誌（遮蔽 HashKey/HashIV）

### GetResponse 安全處理

AES 解密後務必驗證：

```php
$decryptedData = $aesService->decrypt($_POST['Data']);

// 驗證 MerchantID
if ($decryptedData['MerchantID'] !== env('ECPAY_MERCHANT_ID')) {
    error_log('ECPG: MerchantID mismatch');
    return;
}

// 驗證金額一致性
$order = findOrder($decryptedData['MerchantTradeNo']);
if ((int)$decryptedData['TradeAmt'] !== $order->amount) {
    error_log('ECPG: Amount mismatch');
    return;
}

// 冪等性檢查
if ($order->isPaid()) {
    return;
}
```

### Content Security Policy (CSP)

若你的網站設有嚴格 CSP，需允許 ECPG JavaScript SDK 的 domain：

```
Content-Security-Policy: script-src 'self' https://ecpg-stage.ecpay.com.tw https://ecpg.ecpay.com.tw;
                         frame-src 'self' https://ecpg-stage.ecpay.com.tw https://ecpg.ecpay.com.tw;
```

> 正式環境只需保留 `https://ecpg.ecpay.com.tw`，移除 `-stage`。

### CORS 注意事項

ECPG API 為 server-to-server 呼叫，**不可從前端直接呼叫**（會被 CORS 擋住）。正確架構：

1. 前端：使用 ECPG JavaScript SDK 取得 Token
2. 後端：用 Token 呼叫 CreatePayment API
3. 前端**不要**直接呼叫 `ecpg.ecpay.com.tw` 的 API

### Token 安全存儲

若使用綁卡功能，Token 應妥善保管：

- Token 存儲在資料庫中應加密（AES-256 或使用 KMS）
- 不要將 Token 傳到前端或寫入日誌
- 設定 Token 過期機制（定期清理不活躍的綁卡）
- ECPay 的 Token 不等同信用卡卡號，但仍屬敏感資訊

### 防止重複付款

消費者可能重複點擊付款按鈕。建議：

1. **前端**：點擊後立即 disable 按鈕
2. **後端**：同一 `MerchantTradeNo` 不重複建立交易
3. **資料庫**：對 `MerchantTradeNo` 建立 UNIQUE constraint

## 常見錯誤碼速查

| TransCode | 含義 | 解決方式 |
|-----------|------|---------|
| 1 | API 呼叫成功 | 檢查 Data 中的 RtnCode |
| 其他 | API 層級錯誤 | 檢查 TransMsg 取得錯誤描述 |

> 完整錯誤碼清單見 [guides/15-troubleshooting.md](./15-troubleshooting.md)

## 完整範例檔案對照

| 檔案 | 用途 | 端點 |
|------|------|------|
| CreateAllOrder/GetToken.php | 全方位 Token | ecpg/GetTokenbyTrade |
| CreateCreditOrder/GetToken.php | 信用卡 Token | ecpg/GetTokenbyTrade |
| CreateInstallmentOrder/GetToken.php | 分期 Token | ecpg/GetTokenbyTrade |
| CreateAtmOrder/GetToken.php | ATM Token | ecpg/GetTokenbyTrade |
| CreateCvsOrder/GetToken.php | CVS Token | ecpg/GetTokenbyTrade |
| CreateBarcodeOrder/GetToken.php | 條碼 Token | ecpg/GetTokenbyTrade |
| CreateUnionPayOrder/GetToken.php | 銀聯 Token | ecpg/GetTokenbyTrade |
| CreateApplePayOrder/GetToken.php | Apple Pay Token | ecpg/GetTokenbyTrade |
| CreateOrder.php | 建立交易 | ecpg/CreatePayment |
| GetResponse.php | 回應解密 | — |
| GetTokenbyBindingCard.php | 綁卡 Token | ecpg/GetTokenbyBindingCard |
| CreateBindCard.php | 建立綁卡 | ecpg/CreateBindCard |
| GetCreateBindCardResponse.php | 綁卡結果 | — |
| CreatePaymentWithCardID.php | 綁卡扣款 | ecpg/CreatePaymentWithCardID |
| GetMemberBindCard.php | 查詢綁卡 | ecpg/GetMemberBindCard |
| DeleteMemberBindCard.php | 刪除綁卡 | ecpg/DeleteMemberBindCard |
| DeleteCredit.php | 刪除信用卡 | ecpg/GetTokenbyUser |
| Capture.php | 請款/退款 | ecpayment/Credit/DoAction |
| CreditPeriodAction.php | 定期定額管理 | ecpayment/CreditCardPeriodAction |
| QueryTrade.php | 查詢訂單 | ecpayment/QueryTrade |
| QueryCreditTrade.php | 信用卡查詢 | ecpayment/CreditDetail/QueryTrade |
| QueryPaymentInfo.php | 付款資訊查詢 | ecpayment/QueryPaymentInfo |
| QueryPeridicTrade.php | 定期定額查詢 | ecpayment/QueryTrade |
| QueryTradeMedia.php | 對帳 | ecpayment/QueryTradeMedia |

## 相關文件

- Web API 規格：`references/Payment/站內付2.0API技術文件Web.md`（34 個 URL）
- App API 規格：`references/Payment/站內付2.0API技術文件App.md`（39 個 URL）
- AES 加解密：[guides/14-aes-encryption.md](./14-aes-encryption.md)
- 除錯指南：[guides/15-troubleshooting.md](./15-troubleshooting.md)
- 上線檢查：[guides/16-go-live-checklist.md](./16-go-live-checklist.md)
