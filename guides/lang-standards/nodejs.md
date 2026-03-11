# Node.js — ECPay 整合程式規範

> 本檔為 AI 生成 ECPay 整合程式碼時的 Node.js 專屬規範。
> 加密函式：[guides/13 §Node.js](../13-checkmacvalue.md) + [guides/14 §Node.js](../14-aes-encryption.md)
> E2E 範例：[guides/00 §Quick Start](../00-getting-started.md) + [guides/24](../24-multi-language-integration.md)

## 版本與環境

- **最低版本**：Node.js 18+（原生 `fetch`、穩定 `crypto`）
- **推薦版本**：Node.js 20 LTS+
- **套件管理**：`npm`（package.json）或 `pnpm`

## 推薦依賴

```json
{
  "dependencies": {
    "express": "^4.18",
    "dotenv": "^16.0"
  }
}
```

> **內建 crypto 即可**：Node.js `crypto` 模組已包含 AES-128-CBC 和 SHA256，無需第三方加密庫。

## 命名慣例

```javascript
// 函式 / 變數：camelCase
function generateCheckMacValue(params, hashKey, hashIv) { }
const merchantTradeNo = `ORDER${Date.now()}`;

// 類別：PascalCase
class EcpayPaymentClient { }

// 常數：UPPER_SNAKE_CASE
const ECPAY_PAYMENT_URL = 'https://payment.ecpay.com.tw/Cashier/AioCheckOut/V5';

// 檔案：kebab-case.js 或 camelCase.js
// ecpay-payment.js, ecpayAes.js, ecpay-callback.js

// ⚠️ ECPay 參數名保持 PascalCase（MerchantID, HashKey）— 這是 API 規格，不可轉換
```

## 型別定義（JSDoc）

```javascript
/**
 * @typedef {Object} AioParams
 * @property {string} MerchantID
 * @property {string} MerchantTradeNo
 * @property {string} MerchantTradeDate - yyyy/MM/dd HH:mm:ss
 * @property {'aio'} PaymentType
 * @property {string} TotalAmount - 整數字串
 * @property {string} ReturnURL
 * @property {string} ChoosePayment
 * @property {'1'} EncryptType
 * @property {string} CheckMacValue
 */

/**
 * @typedef {Object} AesRequest
 * @property {string} MerchantID
 * @property {{Timestamp: number, Revision: string}} RqHeader
 * @property {string} Data - AES 加密後 Base64
 */

/**
 * @typedef {Object} CallbackParams
 * @property {string} RtnCode - ⚠️ 字串，用 === '1' 比較
 * @property {string} MerchantTradeNo
 * @property {string} CheckMacValue
 */
```

## 錯誤處理

```javascript
class EcpayApiError extends Error {
  constructor(transCode, rtnCode, message) {
    super(`TransCode=${transCode}, RtnCode=${rtnCode}: ${message}`);
    this.transCode = transCode;
    this.rtnCode = rtnCode;
  }
}

async function callAesApi(url, requestBody, hashKey, hashIv) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30000);

  try {
    const resp = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody),
      signal: controller.signal,
    });

    if (resp.status === 403) {
      throw new EcpayApiError(-1, null, 'Rate Limited — 需等待約 30 分鐘');
    }
    if (!resp.ok) {
      throw new EcpayApiError(-1, null, `HTTP ${resp.status}`);
    }

    const result = await resp.json();

    // 雙層錯誤檢查
    if (result.TransCode !== 1) {
      throw new EcpayApiError(result.TransCode, null, result.TransMsg);
    }
    const data = aesDecrypt(result.Data, hashKey, hashIv);
    if (String(data.RtnCode) !== '1') {
      throw new EcpayApiError(1, data.RtnCode, data.RtnMsg);
    }
    return data;
  } finally {
    clearTimeout(timeout);
  }
}
```

## HTTP Client 配置

```javascript
// Node.js 18+ 內建 fetch，適合大部分場景
// 若需連線池管理，使用 undici（Node.js 底層 HTTP 引擎）

// ⚠️ Timestamp 必須是 Unix 秒數，非毫秒
const timestamp = Math.floor(Date.now() / 1000);
```

## Callback Handler 模板

```javascript
const express = require('express');
const crypto = require('crypto');
const app = express();

app.use(express.urlencoded({ extended: false }));

app.post('/ecpay/callback', (req, res) => {
  const params = { ...req.body };

  // 1. 驗證 CheckMacValue（timing-safe）
  const receivedCmv = params.CheckMacValue;
  delete params.CheckMacValue;
  const expectedCmv = generateCheckMacValue(params, HASH_KEY, HASH_IV);

  if (!crypto.timingSafeEqual(
    Buffer.from(receivedCmv),
    Buffer.from(expectedCmv)
  )) {
    return res.status(400).send('CheckMacValue Error');
  }

  // 2. 冪等性檢查
  // if (await isOrderProcessed(params.MerchantTradeNo)) { ... }

  // 3. 業務邏輯（RtnCode 是字串）
  if (params.RtnCode === '1') {
    // 處理付款成功
  }

  // 4. 必須回傳 HTTP 200 + 純文字 "1|OK"
  res.status(200).type('text/plain').send('1|OK');
});

// ⚠️ ECPay Callback URL 僅支援 port 80 (HTTP) / 443 (HTTPS)
// 開發環境使用 ngrok 轉發到本機任意 port
```

## 環境變數

```javascript
// .env（不可提交至版控）
// ECPAY_MERCHANT_ID=3002607
// ECPAY_HASH_KEY=pwFHCqoQZGmho4w6
// ECPAY_HASH_IV=EkRm7iFT261dpevs
// ECPAY_ENV=stage

require('dotenv').config();

const config = {
  merchantId: process.env.ECPAY_MERCHANT_ID,
  hashKey: process.env.ECPAY_HASH_KEY,
  hashIv: process.env.ECPAY_HASH_IV,
  baseUrl: process.env.ECPAY_ENV === 'stage'
    ? 'https://payment-stage.ecpay.com.tw'
    : 'https://payment.ecpay.com.tw',
};
```

## 單元測試模式

```javascript
// ecpay.test.js — Jest / Vitest
const { generateCheckMacValue, aesEncrypt, aesDecrypt } = require('./ecpay-crypto');

describe('CheckMacValue', () => {
  test('SHA256 test vector', () => {
    const params = {
      MerchantID: '3002607',
      MerchantTradeNo: 'Test1234567890',
      MerchantTradeDate: '2025/01/01 12:00:00',
      PaymentType: 'aio',
      TotalAmount: '100',
      TradeDesc: '測試',
      ItemName: '測試商品',
      ReturnURL: 'https://example.com/notify',
      ChoosePayment: 'ALL',
      EncryptType: '1',
    };
    expect(generateCheckMacValue(params, 'pwFHCqoQZGmho4w6', 'EkRm7iFT261dpevs'))
      .toBe('291CBA324D31FB5A4BBBFDF2CFE5D32598524753AFD4959C3BF590C5B2F57FB2');
  });
});

describe('AES', () => {
  test('encrypt/decrypt roundtrip', () => {
    const data = { MerchantID: '2000132', BarCode: '/1234567' };
    const encrypted = aesEncrypt(data, 'ejCk326UnaZWKisg', 'q9jcZX8Ib9LM8wYk');
    const decrypted = aesDecrypt(encrypted, 'ejCk326UnaZWKisg', 'q9jcZX8Ib9LM8wYk');
    expect(decrypted.MerchantID).toBe('2000132');
  });
});
```

## Linter / Formatter

```bash
npm install -D eslint prettier
# 推薦 ESLint flat config（eslint.config.js）
# 設定：semi: true, singleQuote: true, trailingComma: 'all'
```
