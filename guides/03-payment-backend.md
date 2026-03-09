> 對應 ECPay API 版本 | 基於 PHP SDK ecpay/sdk | 最後更新：2026-03

# 幕後授權 + 幕後取號指南

## 概述

幕後 API 是純後台操作，消費者不需要看到付款頁面。適合 B2B、電話訂購、自動扣款等場景。
兩套 API 都使用 **AES 加密 + JSON 格式**（與 ECPG 相同的三層結構）。

## 何時使用幕後 API

| 場景 | 推薦方案 | 原因 |
|------|---------|------|
| 一般電商 | AIO 或 ECPG | 消費者需要看到付款介面 |
| 電話訂購 | 信用卡幕後授權 | 客服代為輸入卡號 |
| 自動扣款 | ECPG 綁卡 | Token 模式更安全 |
| 背景產生繳費資訊 | 非信用卡幕後取號 | ATM/CVS 不需消費者互動即可產生 |
| 大型商戶 | 信用卡幕後授權 | 需 PCI DSS 認證 |

> **大多數開發者不需要幕後 API**。如果你的使用者會在網頁/App 上操作，請使用 [AIO](./01-payment-aio.md) 或 [ECPG](./02-payment-ecpg.md)。

> **注意**：本指南所有 PHP 程式碼範例為依據官方 API 文件手寫，未包含在 `scripts/SDK_PHP/example/` 官方範例中。程式碼已參照 `references/Payment/信用卡幕後授權API技術文件.md` 驗證，但建議在測試環境完整驗證後再部署正式環境。

## 前置需求

- MerchantID / HashKey / HashIV（測試帳號同 ECPG：3002607 / pwFHCqoQZGmho4w6 / EkRm7iFT261dpevs）
- SDK Service：`PostWithAesJsonResponseService`
- 加密方式：AES-128-CBC（詳見 [guides/14-aes-encryption.md](./14-aes-encryption.md)）

```php
$factory = new Factory([
    'hashKey' => 'pwFHCqoQZGmho4w6',
    'hashIv'  => 'EkRm7iFT261dpevs',
]);
$postService = $factory->create('PostWithAesJsonResponseService');
```

## HTTP 協議速查（非 PHP 語言必讀）

| 項目 | 規格 |
|------|------|
| 協議模式 | AES-JSON — 詳見 [guides/20-http-protocol-reference.md](./20-http-protocol-reference.md) |
| HTTP 方法 | POST |
| Content-Type | `application/json` |
| 認證 | AES-128-CBC 加密 Data 欄位 — 詳見 [guides/14-aes-encryption.md](./14-aes-encryption.md) |
| 測試環境 | `https://ecpayment-stage.ecpay.com.tw` |
| 正式環境 | `https://ecpayment.ecpay.com.tw` |
| 回應結構 | 三層 JSON（TransCode → 解密 Data → RtnCode） |
| Callback 回應 | 信用卡幕後授權：JSON `{ "TransCode": 1 }`（與 ECPG 相同）；非信用卡幕後取號：`1\|OK`（與 AIO 相同）— 詳見 [guides/22](./22-webhook-events-reference.md) |

### 端點 URL 一覽

#### 信用卡幕後授權

| 功能 | 端點路徑 |
|------|---------|
| 信用卡卡號授權 | `/1.0.0/Cashier/BackAuth` |
| 信用卡請退款 | `/1.0.0/Credit/DoAction` |
| 查詢訂單 | `/1.0.0/Cashier/QueryTrade` |
| 查詢發卡行 | `/1.0.0/Cashier/QueryCardInfo` |
| 信用卡明細查詢 | `/1.0.0/CreditDetail/QueryTrade` |
| 定期定額查詢 | `/1.0.0/Cashier/QueryTrade` |
| 定期定額作業 | `/1.0.0/Cashier/CreditCardPeriodAction` |
| 撥款對帳下載 | `/1.0.0/Cashier/QueryTradeMedia` |

#### 非信用卡幕後取號

| 功能 | 端點路徑 |
|------|---------|
| 產生繳費代碼 | `/1.0.0/Cashier/GenPaymentCode` |
| 查詢訂單 | `/1.0.0/Cashier/QueryTrade` |
| 取號結果查詢 | `/1.0.0/Cashier/QueryPaymentInfo` |
| 超商條碼查詢 | `/1.0.0/Cashier/QueryCVSBarcode` |

## 信用卡幕後授權

### 重要前提

- **需要 PCI DSS 認證**：你的伺服器會直接處理信用卡卡號
- 適合大型商戶、電話訂購中心
- 一般電商建議使用 AIO 或 ECPG

### 整合流程

```
你的伺服器 → AES 加密卡號等資料
            → POST JSON 到綠界幕後授權端點
            → 綠界回傳授權結果（AES 加密）
            → 解密取得授權結果
```

**注意**：因為你的伺服器直接接觸信用卡卡號，PCI DSS 合規是法律要求。

### PCI DSS 責任範圍比較

| 整合方式 | 你的伺服器接觸卡號？ | PCI DSS 範圍 | 合規成本 |
|---------|-------------------|-------------|---------|
| AIO（全方位金流） | ✗ | 最小（SAQ A） | 低 |
| ECPG（站內付） | ✗ | 最小（SAQ A） | 低 |
| 幕後授權 | **✅ 直接接觸** | **完整（SAQ D）** | **高** |

> **建議**：除非有明確的業務需求（如電話訂購、B2B 大額交易），否則應優先使用 AIO 或 ECPG，避免承擔 PCI DSS 完整合規成本。

### 主要功能

| 功能 | 說明 |
|------|------|
| 幕後授權 | 直接傳卡號進行信用卡授權 |
| 請款 | 對已授權的交易進行請款 |
| 退款 | 對已請款的交易進行退款 |
| 取消授權 | 取消尚未請款的授權 |
| 交易查詢 | 查詢交易狀態 |

### 請求格式範例

所有請求都使用 AES 三層結構（與 ECPG 相同模式）：

```php
$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => [
        'Timestamp' => time(),
    ],
    'Data'       => [
        'MerchantID'      => '3002607',
        'MerchantTradeNo' => 'BA' . time(),
        // ... 其他業務參數（卡號、金額等）
        // 具體參數請查閱官方 API 文件
    ],
];
$response = $postService->post($input, 'https://ecpayment-stage.ecpay.com.tw/1.0.0/Cashier/BackAuth');
```

### API 規格

端點：`POST /1.0.0/Cashier/BackAuth`

端點和完整參數詳見官方文件：[references/Payment/信用卡幕後授權API技術文件.md](../references/Payment/信用卡幕後授權API技術文件.md)（16 個 URL），
其中授權交易參數頁面為：https://developers.ecpay.com.tw/45958.md

#### BackAuth 常用核心參數

| 參數名稱 | 型別 | 必填 | 說明 |
|----------|------|------|------|
| MerchantTradeNo | string (20) | ✅ | 特店交易編號，不可重複 |
| MerchantTradeDate | string | ✅ | 特店交易時間，格式 `yyyy/MM/dd HH:mm:ss` |
| TotalAmount | int | ✅ | 交易金額（整數，不含小數） |
| TradeDesc | string | ✅ | 交易描述 |
| CardNo | string | ✅ | 信用卡卡號 |
| CardValidMM | string | ✅ | 信用卡有效月份（MM） |
| CardValidYY | string | ✅ | 信用卡有效年份（YY） |
| CardCVV2 | string | ✅ | 信用卡背面末三碼 |
| ReturnURL | string | ✅ | 付款結果通知 URL（Server POST） |
| OrderResultURL | string | — | 前端導回 URL（可選） |

> 以上為常用核心參數。完整參數（含分期、定期定額、3D 驗證等進階欄位）請查閱官方 API 技術文件。

> ⚠️ **SNAPSHOT 2026-03** | 來源：`references/Payment/信用卡幕後授權API技術文件.md`
> 以上參數表僅供整合流程理解，不可直接作為程式碼生成依據。**生成程式碼前必須 web_fetch 來源文件取得最新規格。**

> ⚠️ **AES-JSON 雙層錯誤檢查**：幕後授權回應需先檢查外層 `TransCode`（1=成功），
> 再解密 Data 檢查內層 `RtnCode`（1=交易成功）。兩層都必須為成功才代表交易成功。

> **重要**：幕後授權的 PHP SDK 沒有提供範例程式碼。上述程式碼僅展示 AES 請求格式。
> 具體端點 URL 和必填參數請務必參考官方 API 技術文件。

## 非信用卡幕後取號

### 適用場景

- 在背景為 ATM / 超商代碼 / 條碼產生繳費資訊
- 不需要消費者在頁面上操作
- 適合自動化系統（如自動產生繳費單）

### 整合流程

```
你的伺服器 → AES 加密訂單資料
            → POST JSON 到綠界幕後取號端點
            → 綠界回傳繳費資訊（AES 加密）
            → 解密取得繳費代碼
            → 將繳費代碼提供給消費者（Email/SMS/頁面顯示）
            → 消費者去 ATM/超商繳費
            → 綠界 POST 付款結果到你的 ReturnURL
```

### 取號結果對照

| 付款方式 | 回傳繳費資訊 | 消費者操作 |
|---------|------------|----------|
| ATM | BankCode（銀行代碼）+ vAccount（虛擬帳號） | 至 ATM 轉帳 |
| 超商代碼 | PaymentNo（繳費代碼） | 至超商繳費機輸入代碼 |
| 條碼 | Barcode1 + Barcode2 + Barcode3 | 至超商出示條碼 |

### 請求格式範例

```php
$input = [
    'MerchantID' => '3002607',
    'RqHeader'   => [
        'Timestamp' => time(),
    ],
    'Data'       => [
        'MerchantID'       => '3002607',
        'MerchantTradeNo'  => 'BG' . time(),
        'MerchantTradeDate'=> date('Y/m/d H:i:s'),
        'TotalAmount'      => 1000,
        'TradeDesc'        => '背景取號測試',
        'ItemName'         => '測試商品',
        'ReturnURL'        => 'https://你的網站/ecpay/notify',
        'ChoosePayment'    => 'ATM',  // ATM / CVS / BARCODE
        // ... 其他參數請查閱官方 API 文件
    ],
];
$response = $postService->post($input, 'https://ecpayment-stage.ecpay.com.tw/1.0.0/Cashier/GenPaymentCode');
```

### 主要功能

| 功能 | 說明 |
|------|------|
| ATM 幕後取號 | 背景產生虛擬帳號 |
| 超商代碼幕後取號 | 背景產生超商繳費代碼 |
| 條碼幕後取號 | 背景產生三段條碼 |
| 交易查詢 | 查詢取號狀態與付款狀態 |

### API 規格

端點和完整參數詳見官方文件：`references/Payment/非信用卡幕後取號API技術文件.md`（15 個 URL）

> **重要**：幕後取號的 PHP SDK 沒有提供範例程式碼。上述程式碼僅展示 AES 請求格式。
> 具體端點 URL 和必填參數請務必參考官方 API 技術文件。

## 與 AIO/ECPG 的完整比較

| 面向 | AIO | ECPG | 幕後授權 | 幕後取號 |
|------|-----|------|---------|---------|
| 消費者互動 | 需要（綠界頁面） | 需要（嵌入式） | 不需要 | 不需要 |
| 付款頁面 | 綠界提供 | 你的頁面 | 無 | 無 |
| 加密方式 | CheckMacValue (SHA256) | AES | AES | AES |
| 信用卡 | ✅ | ✅ | ✅（需 PCI DSS） | ✗ |
| ATM/CVS/條碼 | ✅ | ✅ | ✗ | ✅ |
| 適用場景 | 一般電商 | 嵌入式體驗 | 電話訂購/B2B | 自動化系統 |
| PHP SDK 範例 | 20 個 | 24 個 | 無 | 無 |
| 取號結果 | PaymentInfoURL 回呼 | API 回傳 | N/A | API 直接回傳 |

## 信用卡幕後授權 API

### 核心端點

| 操作 | 端點 | Action | 說明 |
|------|------|--------|------|
| 授權 | `/1.0.0/Cashier/BackAuth` | — | 信用卡幕後授權（直接傳卡號） |
| 請款 | `/1.0.0/Credit/DoAction` | C | 對已授權交易請款 |
| 退款 | `/1.0.0/Credit/DoAction` | R | 對已請款交易退款 |
| 取消授權 | `/1.0.0/Credit/DoAction` | N | 放棄尚未請款的授權 |
| 查詢 | `/1.0.0/CreditDetail/QueryTrade` | — | 查詢信用卡交易明細 |

> 端點來源：官方 API 技術文件 `references/Payment/信用卡幕後授權API技術文件.md`
> 完整參數規格請查閱該文件中的官方連結。

## 非信用卡幕後取號 API

### ATM/CVS/BARCODE 取號端點

| 付款方式 | 建單後流程 |
|---------|----------|
| ATM | 取得虛擬帳號 → 消費者轉帳 → ReturnURL 通知 |
| CVS（超商代碼）| 取得繳費代碼 → 消費者至超商繳費 → ReturnURL 通知 |
| BARCODE（條碼）| 取得三段條碼 → 消費者至超商掃碼 → ReturnURL 通知 |

### ReturnURL 回呼格式

消費者付款完成後，綠界會 POST 付款結果（AES-JSON 格式）到你指定的 ReturnURL。解密後回呼包含：
- MerchantID、MerchantTradeNo
- RtnCode（1=付款成功）
- 付款方式相關欄位（BankCode/vAccount 或 PaymentNo 或 Barcode1~3）

> 完整參數規格請查閱 `references/Payment/非信用卡幕後取號API技術文件.md` 中的官方文件連結。

## 相關文件

- 信用卡幕後授權：`references/Payment/信用卡幕後授權API技術文件.md`
- 非信用卡幕後取號：`references/Payment/非信用卡幕後取號API技術文件.md`
- AES 加解密：[guides/14-aes-encryption.md](./14-aes-encryption.md)
- AIO 金流（消費者互動）：[guides/01-payment-aio.md](./01-payment-aio.md)
- ECPG 站內付（嵌入式）：[guides/02-payment-ecpg.md](./02-payment-ecpg.md)
