> 對應 ECPay API 版本 | 基於 PHP SDK ecpay/sdk | 最後更新：2026-03

# 電子票證整合指南

## 概述

ECPay 電子票證服務讓商家發行和管理數位票券，適用於遊樂園門票、餐廳餐券、活動票券、課程套票等場景。使用 **AES 加密 + JSON 格式**（與 ECPG/發票相同的三層結構）。

### ⚠️ AES-JSON 開發者必讀：雙層錯誤檢查

電子票證使用 AES-JSON 協議，回應為三層 JSON 結構。**必須做兩次檢查**：

1. 檢查外層 `TransCode === 1`（否則 AES 加密/格式有問題）
2. 解密 Data 後，檢查內層 `RtnCode === 1`（業務邏輯問題）

完整錯誤碼參考見 [guides/21](./21-error-codes-reference.md)。

## 前置需求

- 需向綠界申請電子票證服務（獨立開通，非金流帳號自動包含）
- 加密方式：AES-128-CBC（詳見 [guides/14-aes-encryption.md](./14-aes-encryption.md)）
- 測試環境帳號：向綠界客服取得（電子票證無公開測試帳號）

### 測試帳號取得流程

1. 透過綠界客服申請電子票證測試帳號（需提供：公司名稱、統編、聯絡人、使用模式）
2. 審核通過後取得測試環境的 MerchantID / HashKey / HashIV
3. 預估審核時間：3-5 個工作天
4. 測試環境 URL：`https://ecticket-stage.ecpay.com.tw`

```php
$factory = new Factory([
    'hashKey' => '你的HashKey',
    'hashIv'  => '你的HashIV',
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
| 測試環境 | `https://ecticket-stage.ecpay.com.tw` |
| 正式環境 | `https://ecticket.ecpay.com.tw` |
| 回應結構 | 三層 JSON（TransCode → 解密 Data → RtnCode） |
| 測試帳號 | 需向綠界客服個別申請（無公開測試帳號） |

## 模式選擇決策樹

```
需要電子票證？
├── 希望 ECPay 代管款項（降低風險）
│   ├── 票券一次性使用（門票、餐券） → 價金保管 — 使用後核銷
│   └── 票券多次使用（課程套票、月卡） → 價金保管 — 分期核銷
└── 自行處理金流
    └── 純發行 — 使用後核銷
```

### 三種模式快速比較

| 面向 | 價金保管-使用後核銷 | 價金保管-分期核銷 | 純發行-使用後核銷 |
|------|:---:|:---:|:---:|
| 款項代管 | ECPay 代管 | ECPay 代管 | **商家自行處理** |
| 金流風險 | 低（ECPay 保管） | 低（ECPay 保管） | **高（自行負責）** |
| 開發複雜度 | ★★☆ | ★★★ | ★★★ |
| 核銷方式 | 一次核銷 | 分次核銷 | 一次核銷 |
| 適用場景 | 門票、餐券、入場券 | 課程套票、月卡、多次券 | 自有金流體系的票券 |
| 結算時機 | 核銷後撥款 | 每次核銷後撥款 | 不經 ECPay |
| 推薦度 | **入門首選** | 進階 | 特殊需求 |

> **不確定選哪個？** 選「價金保管-使用後核銷」最安全，開發最簡單。

## 三種模式詳解

### 價金保管 — 使用後核銷（推薦入門）

**流程**：消費者購買 → ECPay 代管款項 → 消費者使用票券 → 商家核銷 → ECPay 結算給商家

```
消費者購買票券（透過金流 AIO/ECPG）
    → ECPay 代管款項
    → 發行票券（API）
    → 消費者取得票券 QR Code / 序號
    → 消費者到場使用
    → 商家呼叫核銷 API
    → ECPay 結算款項給商家
```

**適用場景**：遊樂園門票、景點入場券、餐廳餐券、活動票券

**API 端點**（24 個功能）— 端點來源：官方 API 技術文件

#### 完整 API 端點表

| 分類 | 操作 | HTTP Method | 端點路徑 |
|------|------|------------|---------|
| 票券作業 | 票券發行 | POST | `/api/Ticket/Issue` |
| 票券作業 | 票券核銷 | POST | `/api/Ticket/Redeem` |
| 票券作業 | 票券退貨 | POST | `/api/Ticket/Refund` |
| 查詢作業 | 查詢履約保障天期 | POST | `/api/Query/GuaranteePeriod` |
| 查詢作業 | 查詢商品資訊 | POST | `/api/Query/ProductInfo` |
| 查詢作業 | 批次查詢商品資訊 | POST | `/api/Query/BatchProductInfo` |
| 查詢作業 | 查詢票券發行結果 | POST | `/api/Query/IssueResult` |
| 查詢作業 | 取得紙本票面資料 | POST | `/api/Query/PrintData` |
| 查詢作業 | 查詢票券明細 | POST | `/api/Query/TicketDetail` |
| 查詢作業 | 查詢訂單退款資訊 | POST | `/api/Query/RefundInfo` |
| 查詢作業 | 查詢訂單資訊 | POST | `/api/Query/OrderInfo` |
| 查詢作業 | 下載訂單明細檔 | POST | `/api/Query/DownloadOrderDetail` |
| 主動通知 | 退款主動通知 | POST（綠界→你） | 由你提供 ServerReplyURL |
| 主動通知 | 核退主動通知 | POST（綠界→你） | 由你提供 ServerReplyURL |

#### PHP 請求範例（票券發行）

```php
$postService = $factory->create('PostWithAesJsonResponseService');

$input = [
    'MerchantID' => getenv('ECPAY_ECTICKET_MERCHANT_ID'),
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '1.0.0'],
    'Data'       => [
        'MerchantID'     => getenv('ECPAY_ECTICKET_MERCHANT_ID'),
        'TicketName'     => '遊樂園入場券',
        'TicketPrice'    => 500,
        'TicketQty'      => 1,
        'ValidDate'      => date('Y/m/d', strtotime('+30 days')),
        'ServerReplyURL' => 'https://你的網站/ecticket/notify',
    ],
];
try {
    $response = $postService->post($input, 'https://ecticket-stage.ecpay.com.tw/api/Ticket/Issue');
} catch (\Exception $e) {
    error_log('ECPay Ticket Issue Error: ' . $e->getMessage());
}
```

#### PHP 請求範例（票券核銷）

```php
$input = [
    'MerchantID' => getenv('ECPAY_ECTICKET_MERCHANT_ID'),
    'RqHeader'   => ['Timestamp' => time(), 'Revision' => '1.0.0'],
    'Data'       => [
        'MerchantID' => getenv('ECPAY_ECTICKET_MERCHANT_ID'),
        'TicketNo'   => '票券序號',
    ],
];
try {
    $response = $postService->post($input, 'https://ecticket-stage.ecpay.com.tw/api/Ticket/Redeem');
} catch (\Exception $e) {
    error_log('ECPay Ticket Redeem Error: ' . $e->getMessage());
}
```

### 價金保管 — 分期核銷

**流程**：與「使用後核銷」類似，但票券可多次使用，每次核銷部分金額。

```
消費者購買 10 堂課程套票（$5000）
    → ECPay 代管 $5000
    → 每次上課核銷 $500（1/10）
    → 第 10 次核銷後全額結算
    → 中途退票：已核銷部分結算，未核銷部分退款
```

**適用場景**：課程套票、健身房月卡、多次入場券

**API 端點**（12 個功能）— 端點來源：官方 API 技術文件

#### 完整 API 端點表

| 分類 | 操作 | HTTP Method | 端點路徑 |
|------|------|------------|---------|
| 退貨 | 訂單退貨 | POST | `/api/Ticket/Refund` |
| 查詢作業 | 查詢履約保障天期 | POST | `/api/Query/GuaranteePeriod` |
| 查詢作業 | 查詢訂單退款資訊 | POST | `/api/Query/RefundInfo` |
| 查詢作業 | 查詢訂單資訊 | POST | `/api/Query/OrderInfo` |
| 查詢作業 | 下載訂單明細檔 | POST | `/api/Query/DownloadOrderDetail` |
| 主動通知 | 退款主動通知 | POST（綠界→你） | 由你提供 ServerReplyURL |

> **與使用後核銷差異**：分期核銷模式的票券發行和核銷由綠界後台管理，API 主要處理退貨和查詢。每次核銷部分金額，適合多次使用的票券場景。

### 純發行 — 使用後核銷

**流程**：商家自行處理金流，ECPay 僅提供票券發行和管理。

```
消費者在你的網站付款（自行處理）
    → 你的伺服器呼叫 ECPay 發行票券
    → 消費者取得票券
    → 消費者使用時核銷
    → 無 ECPay 結算（你自行處理）
```

**適用場景**：已有金流管道的商家、禮物券、兌換券

**API 端點**（21 個功能）— 端點來源：官方 API 技術文件

#### 完整 API 端點表

| 分類 | 操作 | HTTP Method | 端點路徑 |
|------|------|------------|---------|
| 票券作業 | 票券發行 | POST | `/api/Ticket/Issue` |
| 票券作業 | 票券核銷 | POST | `/api/Ticket/Redeem` |
| 票券作業 | 票券退貨 | POST | `/api/Ticket/Refund` |
| 查詢作業 | 查詢履約保障天期 | POST | `/api/Query/GuaranteePeriod` |
| 查詢作業 | 查詢商品資訊 | POST | `/api/Query/ProductInfo` |
| 查詢作業 | 批次查詢商品資訊 | POST | `/api/Query/BatchProductInfo` |
| 查詢作業 | 查詢票券發行結果 | POST | `/api/Query/IssueResult` |
| 查詢作業 | 取得紙本票面資料 | POST | `/api/Query/PrintData` |
| 查詢作業 | 查詢票券明細 | POST | `/api/Query/TicketDetail` |
| 查詢作業 | 查詢訂單資訊 | POST | `/api/Query/OrderInfo` |
| 查詢作業 | 下載訂單明細檔 | POST | `/api/Query/DownloadOrderDetail` |
| 主動通知 | 核退主動通知 | POST（綠界→你） | 由你提供 ServerReplyURL |

> **與價金保管差異**：純發行模式不含「查詢訂單退款資訊」和「退款主動通知」，因為金流由商家自行處理，綠界不介入退款流程。

## 價金保管 vs 純發行 比較

| 面向 | 價金保管 | 純發行 |
|------|---------|--------|
| 金流處理 | ECPay 代管款項 | 商家自行處理 |
| 結算時機 | 核銷後結算 | 無結算機制 |
| 風險 | 低（ECPay 保管） | 商家自負 |
| 退票退款 | ECPay 自動處理 | 商家自行處理 |
| 手續費 | 較高（含代管服務） | 較低（僅票券管理） |
| 適用 | 高單價、跨商家、需信任保障 | 自家使用、低成本 |

## 請求格式

所有電子票證 API 都使用 AES 三層結構（端點來源：官方 API 技術文件）：

```php
$input = [
    'MerchantID' => '你的MerchantID',
    'RqHeader'   => [
        'Timestamp' => time(),
        'Revision'  => '1.0.0',
    ],
    'Data'       => [
        'MerchantID' => '你的MerchantID',
        // 業務參數（票券資訊、核銷資訊等）
    ],
];
$response = $postService->post($input, 'https://ecticket-stage.ecpay.com.tw/api/Ticket/Issue');
```

> **注意**：電子票證的 PHP SDK 沒有提供範例程式碼。上述程式碼展示 AES 請求格式，
> 具體必填參數請參考官方 API 技術文件。
>
> ⚠️ **SNAPSHOT 2026-03** | 來源：`references/Ecticket/` 下對應的 reference 檔案
> 以上參數僅供整合流程理解，不可直接作為程式碼生成依據。**生成程式碼前必須 web_fetch 來源文件取得最新規格。**

## 與金流的搭配

典型的票券銷售流程需要搭配金流：

```
步驟 1: 消費者選購票券
步驟 2: 使用 AIO 或 ECPG 收款（見 guides/01 或 02）
步驟 3: 付款成功後，呼叫電子票證 API 發行票券
步驟 4: 將票券序號/QR Code 發送給消費者
步驟 5: 消費者到場使用時，呼叫核銷 API
步驟 6: 如需開發票，搭配電子發票 API（見 guides/04）
```

如需完整的跨服務整合範例，請參考 [guides/11-cross-service-scenarios.md](./11-cross-service-scenarios.md)。

## 非 PHP 語言 HTTP 範例（Node.js）

電子票證使用 AES-JSON 協議，與 B2C 發票格式完全相同。以下為 Node.js 票券發行範例：

```javascript
const crypto = require('crypto');

// 測試帳號需向綠界客服申請（電子票證無公開測試帳號）
const MERCHANT_ID = '你的MerchantID';
const HASH_KEY = '你的HashKey';
const HASH_IV = '你的HashIV';
const BASE_URL = 'https://ecticket-stage.ecpay.com.tw';

// AES 加密（與 B2C 發票相同）— 完整實作見 guides/14
function aesEncrypt(data, hashKey, hashIV) {
  const json = JSON.stringify(data);
  const urlEncoded = encodeURIComponent(json)
    .replace(/%20/g, '+').replace(/~/g, '%7E')
    .replace(/!/g, '%21').replace(/\*/g, '%2A')
    .replace(/'/g, '%27').replace(/\(/g, '%28').replace(/\)/g, '%29');
  const key = Buffer.from(hashKey.substring(0, 16), 'utf8');
  const iv = Buffer.from(hashIV.substring(0, 16), 'utf8');
  const cipher = crypto.createCipheriv('aes-128-cbc', key, iv);
  let encrypted = cipher.update(urlEncoded, 'utf8', 'base64');
  encrypted += cipher.final('base64');
  return encrypted;
}

// 票券發行
async function issueTicket() {
  const ticketData = {
    MerchantID: MERCHANT_ID,
    TicketName: '遊樂園入場券',
    TicketPrice: 500,
    TicketQty: 1,
    ValidDate: '2026/12/31',
    ServerReplyURL: 'https://your-domain.com/ecticket/notify',
  };

  const body = JSON.stringify({
    MerchantID: MERCHANT_ID,
    RqHeader: { Timestamp: Math.floor(Date.now() / 1000), Revision: '1.0.0' },
    Data: aesEncrypt(ticketData, HASH_KEY, HASH_IV),
  });

  const res = await fetch(`${BASE_URL}/api/Ticket/Issue`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body,
  });
  const result = await res.json();

  // 雙層錯誤檢查（AES-JSON 必備）
  if (result.TransCode !== 1) {
    throw new Error(`傳輸層錯誤: ${result.TransMsg}`);
  }
  // 解密 Data 後檢查 RtnCode...
}
```

> 上述 `aesEncrypt` 為簡化版。完整加密/解密實作（含 PKCS7 padding、URL decode）見 [guides/14-aes-encryption.md](./14-aes-encryption.md) §Node.js。
> 其他語言開發者：電子票證的 AES 加密方式與 B2C 發票**完全相同**，可直接複用 guides/14 的加密函式。

## 整合提示

1. **建議從「價金保管 — 使用後核銷」開始**，流程最直覺、風險最低
2. 如需多次使用票券，再評估「分期核銷」模式
3. 純發行適合已有自己金流管道的商家
4. 票券 QR Code 建議設定合理的有效期限
5. 核銷時注意防重複核銷（同一張票券不能核銷兩次）
6. 建議實作退票流程，提升消費者體驗

## API 規格索引

| 模式 | 文件 | URL 數量 |
|------|------|---------|
| 價金保管 — 使用後核銷 | `references/Ecticket/價金保管-使用後核銷API技術文件.md` | 24 |
| 價金保管 — 分期核銷 | `references/Ecticket/價金保管-分期核銷API技術文件.md` | 12 |
| 純發行 — 使用後核銷 | `references/Ecticket/純發行-使用後核銷API技術文件.md` | 21 |

## 三種模式的 API 功能對照

端點來源：官方 API 技術文件

| 功能 | 價金保管（使用後核銷） | 價金保管（分期核銷） | 純發行 |
|------|---------------------|-------------------|--------|
| 票券發行 `/api/Ticket/Issue` | 有 | 無（後台管理） | 有 |
| 票券核銷 `/api/Ticket/Redeem` | 有（一次性） | 無（後台管理） | 有（一次性） |
| 票券退貨 `/api/Ticket/Refund` | 有 | 有（訂單退貨） | 有 |
| 查詢履約保障天期 | 有 | 有 | 有 |
| 查詢商品資訊 | 有 | 無 | 有 |
| 批次查詢商品資訊 | 有 | 無 | 有 |
| 查詢票券發行結果 | 有 | 無 | 有 |
| 取得紙本票面資料 | 有 | 無 | 有 |
| 查詢票券明細 | 有 | 無 | 有 |
| 查詢訂單退款資訊 | 有 | 有 | 無 |
| 查詢訂單資訊 | 有 | 有 | 有 |
| 下載訂單明細檔 | 有 | 有 | 有 |
| 退款主動通知 | 有 | 有 | 無 |
| 核退主動通知 | 有 | 無 | 有 |

> 所有電子票證 API 使用 AES 三層結構，加解密方式與 B2C 發票相同，
> 參考 [guides/14-aes-encryption.md](./14-aes-encryption.md)

## 相關文件

- AES 加解密：[guides/14-aes-encryption.md](./14-aes-encryption.md)
- 金流串接（搭配票券銷售）：[guides/01-payment-aio.md](./01-payment-aio.md)
- ECPG 站內付（嵌入式收款）：[guides/02-payment-ecpg.md](./02-payment-ecpg.md)
- 電子發票（搭配開立）：[guides/04-invoice-b2c.md](./04-invoice-b2c.md)
- 跨服務整合場景：[guides/11-cross-service-scenarios.md](./11-cross-service-scenarios.md)
- 除錯指南：[guides/15-troubleshooting.md](./15-troubleshooting.md)
- 上線檢查：[guides/16-go-live-checklist.md](./16-go-live-checklist.md)
