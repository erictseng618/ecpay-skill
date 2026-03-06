> 對應 ECPay API 版本 | 基於 PHP SDK ecpay/sdk | 最後更新：2026-03

# 測試→上線切換完整檢查清單

> 若需確認最新 API 端點或參數異動，可從 `references/` 對應服務檔案 web_fetch 取得最新官方規格。

## 概述

從測試環境切換到正式環境前，逐項檢查以確保安全、正確、合規。

## 帳號與環境

- [ ] 已向綠界申請正式帳號並通過審核
- [ ] 已取得正式環境的 MerchantID、HashKey、HashIV
- [ ] 已將所有 URL 從 `-stage` 切換到正式域名

### URL 對照

| 服務 | 測試 | 正式 |
|------|------|------|
| 金流 AIO | payment**-stage**.ecpay.com.tw | payment.ecpay.com.tw |
| 站內付 ECPG | ecpg**-stage**.ecpay.com.tw | ecpg.ecpay.com.tw |
| 站內付請款 | ecpayment**-stage**.ecpay.com.tw | ecpayment.ecpay.com.tw |
| 物流 | logistics**-stage**.ecpay.com.tw | logistics.ecpay.com.tw |
| 電子發票 | einvoice**-stage**.ecpay.com.tw | einvoice.ecpay.com.tw |
| 特店後台 | vendor**-stage**.ecpay.com.tw | vendor.ecpay.com.tw |

> **⚠️ ECPG 常見錯誤：雙 Domain 混淆**
>
> ECPG 站內付使用**兩個不同的 domain**：
> - **Token 取得**：`ecpg-stage.ecpay.com.tw`（取得付款 Token）
> - **交易/查詢/請款**：`ecpayment-stage.ecpay.com.tw`（執行交易操作）
>
> 常見錯誤是將所有 ECPG API 都打向 `ecpg` domain，導致交易相關 API 回傳 404。
> 切換正式環境時同樣需要注意：`ecpg.ecpay.com.tw` vs `ecpayment.ecpay.com.tw`。

## 安全性

- [ ] 已更換程式碼中的 MerchantID、HashKey、HashIV 為正式帳號
- [ ] HashKey / HashIV **未出現**在前端程式碼中
- [ ] HashKey / HashIV **未出現**在版本控制（git）中
- [ ] 使用環境變數或加密設定檔管理機敏資料
- [ ] TLS 1.2 已啟用
- [ ] API 金鑰輪換機制已建立（如需要）

#### PCI DSS 範圍影響

不同整合方式影響你的 PCI DSS 合規範圍：

| 整合方式 | PCI 等級 | 說明 |
|---------|---------|------|
| **AIO（跳轉）** | SAQ-A | 最低範圍 — 消費者在綠界頁面輸入卡號，你的伺服器不接觸卡號資料 |
| **ECPG 站內付** | SAQ-A-EP | 中等範圍 — 你的前端頁面嵌入付款元件，但卡號直接送至綠界，不經過你的後端 |
| **幕後授權** | SAQ-D 或更高 | 最高範圍 — 你的後端直接處理卡號資料，需完整 PCI DSS 合規 |

> **建議**：除非有明確需求，優先選擇 AIO 或 ECPG 以降低 PCI 合規負擔。

#### HashKey / HashIV 輪換指引

ECPay 目前**不支援同時啟用多組 HashKey/HashIV**，輪換時需要短暫停機切換。

**輪換步驟**：

1. **申請新金鑰** — 透過綠界特店後台或聯繫客服申請新的 HashKey/HashIV
2. **測試環境驗證** — 在測試環境使用新金鑰完成至少一筆完整交易流程
3. **安排維護窗口** — 選擇交易量最低的時段（通常凌晨 2:00-5:00）
4. **切換金鑰** — 更新環境變數或密鑰管理系統中的 HashKey/HashIV
5. **驗證交易** — 立即執行一筆小額測試交易確認新金鑰正常
6. **確認舊金鑰失效** — 用舊金鑰發送測試請求，確認回傳驗證錯誤

**環境變數管理**：使用密鑰管理服務（如 AWS Secrets Manager / GCP Secret Manager / Azure Key Vault）管理 HashKey/HashIV，**永遠不要**寫入程式碼或設定檔。保留前一組金鑰至少 24 小時以防需要回滾。

### 加密與安全

- [ ] 確認各服務加密方式（AIO=SHA256, 物流=MD5, ECPG/發票=AES）
- [ ] 回呼 URL 使用 FQDN 而非固定 IP
- [ ] 確認 API 呼叫頻率不超過限制（過頻觸發 403，需等 30 分鐘）
- [ ] 回呼端點已限制來源 IP（向綠界客服索取 IP 白名單）

> **取得綠界回呼 IP 範圍**：透過綠界客服 (02-2655-1775) 或特店後台工單索取。
> 取得後在你的防火牆或反向代理中設定白名單，僅允許這些 IP 存取 ReturnURL/ServerReplyURL 端點。

## 回呼 URL

- [ ] ReturnURL 可被外網存取
- [ ] ReturnURL 回應純字串 `1|OK`（無 HTML、無 BOM）
- [ ] ReturnURL 使用 HTTPS
- [ ] ReturnURL 僅使用 80 或 443 埠
- [ ] ReturnURL 未放在 CDN 後面
- [ ] PeriodReturnURL 已設定（如使用定期定額）
- [ ] PaymentInfoURL 已設定（如使用 ATM/CVS/BARCODE）
- [ ] ServerReplyURL 已設定（如使用物流）
- [ ] ATM 付款 ReturnURL 需處理 RtnCode=2（取號成功，非最終付款）
- [ ] CVS/BARCODE 付款 ReturnURL 需處理 RtnCode=10100073（取號成功）

## 驗證邏輯

- [ ] CheckMacValue 驗證已在所有回呼中實作
- [ ] RtnCode 檢查已實作
- [ ] SimulatePaid 檢查已實作（測試交易不出貨）
- [ ] 防重複處理已實作（同一筆通知可能重送多次）
- [ ] AES 解密已正確實作（如使用 ECPG/發票/全方位物流）

## 功能測試

- [ ] 已用正式帳號完成至少一筆小額信用卡交易
- [ ] 已驗證主要付款方式都能正常運作
- [ ] 發票功能已測試（如有使用）
- [ ] 物流功能已測試（如有使用）
- [ ] 退款 / 折讓 / 退貨流程已測試
- [ ] 定期定額已測試（如有使用）
- [ ] 綁卡功能已測試（如有使用）
- [ ] BNPL 先買後付最低金額 ≥ 3,000 元
- [ ] 定期定額：連續 6 次扣款失敗會自動取消合約
- [ ] iOS WebView 測試：LINE/Facebook 內建瀏覽器相容性

## 錯誤處理

- [ ] 錯誤處理和日誌記錄已到位
- [ ] 付款失敗的使用者體驗已處理（顯示錯誤訊息、提供重試）
- [ ] 回呼處理的例外已捕獲（不可因程式錯誤導致未回應 1|OK）
- [ ] API 超時處理已實作

## 3D Secure

- [ ] 已確認 3D Secure 2.0 相容（2025/8/1 起強制）
- [ ] 已了解 3D 驗證可能導致的付款流程變化

## 監控

- [ ] 交易成功率監控已建立
- [ ] 回呼失敗告警已建立
- [ ] 異常交易金額告警已建立

### 上線後第一天觀察重點

- 建立訂單 → callback 接收的比例是否接近 1:1
- callback 處理時間是否在 10 秒內（超時會觸發重送）
- 有無 CheckMacValue 驗證失敗（可能代表 HashKey 設定錯誤）
- ATM/CVS 訂單的 RtnCode=2/10100073 是否被正確處理（非錯誤）

## 緊急回滾計畫

### Feature Flag 策略

建議使用 Feature Flag（如環境變數 `ECPAY_FEATURE_FLAG`）控制 ECPay 整合的啟用狀態，允許不重新部署即可切換收款功能。

### 環境快速切換步驟

1. 在環境變數管理系統中準備測試環境設定（保留 `-stage` URL）
2. 出現問題時，將 `ECPAY_ENV` 從 `production` 切回 `staging`
3. 重啟服務（或使用 Feature Flag 免重啟）
4. 通知客服團隊暫停收款相關客訴處理

### 故障場景降級策略

| 故障場景 | 降級策略 | 恢復條件 |
|---------|---------|---------|
| ECPay API 全面不可用 | 啟用 Feature Flag 暫停收款，顯示維護頁面 | ECPay 狀態頁恢復正常 |
| 回呼 URL 收不到通知 | 啟動輪詢查詢訂單狀態（QueryTradeInfo） | 回呼恢復正常接收 |
| CheckMacValue 驗證失敗 | 檢查是否金鑰被輪換，暫停並聯繫綠界客服 | 確認金鑰正確 |
| 發票 API 故障 | 金流不受影響，發票改為人工補開 | 發票 API 恢復 |

### 事件回應程序

發生 ECPay 相關故障時，依「發現→評估影響→執行降級→通知團隊→逐步恢復→覆盤」流程處理。

### 🚨 金鑰洩漏緊急處置 SOP

若發現 HashKey/HashIV 或 MerchantID 洩漏（例如提交至公開 Git、日誌洩漏）：

1. **立即通知綠界客服**（techsupport@ecpay.com.tw / (02) 2655-1775）要求重發金鑰
2. **停用洩漏金鑰**：暫停相關服務收款（Feature Flag 或維護模式）
3. **檢查異常交易**：透過特店後台（vendor.ecpay.com.tw）查閱洩漏期間的交易紀錄
4. **更新金鑰**：取得新金鑰後更新環境變數並重啟服務
5. **回溯清理**：從 Git 歷史清除敏感值（`git filter-branch` 或 BFG Repo-Cleaner）
6. **覆盤記錄**：記錄洩漏原因、影響範圍、處理時間，更新團隊安全規範

## 環境切換最佳實踐

使用環境變數管理測試/正式環境切換（各語言讀取方式見 [guides/24 環境變數表](./24-multi-language-integration.md)）：

| 環境變數 | 測試值 | 正式值 | 說明 |
|---------|--------|--------|------|
| `ECPAY_MERCHANT_ID` | `3002607`（AIO）/ `2000132`（發票） | 正式特店編號 | 特店編號 |
| `ECPAY_HASH_KEY` | 測試 HashKey | 正式 HashKey | 加密金鑰 |
| `ECPAY_HASH_IV` | 測試 HashIV | 正式 HashIV | 加密向量 |
| `ECPAY_ENV` | `staging` | `production` | 控制 base URL 切換 |

> **原則**：`ECPAY_ENV=production` 時使用 `payment.ecpay.com.tw`，否則使用 `payment-stage.ecpay.com.tw`。所有 domain 的對應關係見 [SKILL.md 環境 URL 表](../SKILL.md)。

## 上線後觀察

### 第一天觀察清單

| 指標 | 目標 | 異常處理 |
|------|------|---------|
| 第一筆真實交易 | 成功完成 | 立即檢查參數和帳號設定 |
| 交易成功率 | > 95% | < 90% 停機排查 |
| ReturnURL 回呼延遲 | < 5 秒 | 檢查伺服器效能 |
| 對帳檔核對 | 金額一致 | 逐筆比對找出差異 |
| 異常金額 | 設定告警閾值 | 單筆 > 50,000 通知 |

### 上線後持續事項

- [ ] 確認對帳報表可正常下載
- [ ] 保留測試環境帳號供日後除錯使用

## 漸進式上線策略

1. **先小額交易測試** — 用真實帳號做 10 元測試交易
2. **先只開信用卡** — 確認穩定後再逐步開啟 ATM、CVS 等
3. **先不串發票** — 確認金流穩定後再加電子發票
4. **灰度發布** — 部分用戶先走新流程，觀察無異常後全量

## 法規與安全合規

### 法規合規

- **電子支付機構管理條例**：依營業規模可能需要申請電子支付執照
- **個人資料保護法**：消費者交易資料需依法保存並提供刪除機制
- **電子發票 48 小時規則**：開立後 48 小時內必須上傳至財政部
- **PCI DSS**：若經手信用卡卡號需符合 PCI DSS 規範（使用 ECPay 則由 ECPay 承擔）

### PCI-DSS 合規

> 完整說明另見 [guides/23-performance-scaling.md](./23-performance-scaling.md)，此處為上線檢查快速參照。

| 整合方式 | SAQ 等級 | 說明 |
|---------|---------|------|
| AIO（重導模式） | SAQ A | 最低合規負擔，卡號在 ECPay 頁面輸入 |
| ECPG（嵌入模式） | SAQ A-EP | 付款 UI 嵌入你的頁面，卡號由 ECPay SDK 處理 |
| 幕後授權 | SAQ D | 最嚴格，你的 server 直接處理卡號 |

### CSRF 防護

- [ ] OrderResultURL 回調頁面需有 CSRF Token 保護
- [ ] ReturnURL（server-to-server）不需 CSRF，但需驗 CheckMacValue

### XSS 防護

- [ ] 從 ECPay 回傳的參數值（TradeDesc, ItemName 等）顯示在頁面時需 HTML escape
- [ ] 不要直接將 callback 參數 innerHTML 到頁面中

### 消費爭議（Chargeback）

- [ ] 了解 ECPay 消費爭議通知流程
- [ ] 準備交易證據保留機制（出貨紀錄、消費者同意紀錄）
- [ ] 注意回覆期限（通常 10-30 個工作天）

### 個人資料保護法

- [ ] 交易資料保留期限符合商業會計法（至少 5 年）
- [ ] 提供消費者刪除個資的機制
- [ ] 信用卡相關資料（若有暫存）需加密儲存

## 自動化冒煙測試

上線前執行以下冒煙測試，確保加密和連線正常。

### Node.js 冒煙測試

```javascript
// smoke-test.js — 執行: node smoke-test.js
const crypto = require('crypto');
const https = require('https');

// ⚠️ 正式環境務必使用環境變數，此處為測試帳號
const HASH_KEY = process.env.ECPAY_HASH_KEY || 'pwFHCqoQZGmho4w6';
const HASH_IV = process.env.ECPAY_HASH_IV || 'EkRm7iFT261dpevs';

function ecpayUrlEncode(s) {
  let encoded = encodeURIComponent(s).replace(/%20/g, '+').replace(/~/g, '%7e').toLowerCase();
  for (const [from, to] of Object.entries({
    '%2d': '-', '%5f': '_', '%2e': '.', '%21': '!', '%2a': '*', '%28': '(', '%29': ')',
  })) encoded = encoded.split(from).join(to);
  return encoded;
}

function generateCMV(params) {
  const sorted = Object.entries(params)
    .filter(([k]) => k !== 'CheckMacValue')
    .sort(([a], [b]) => a.toLowerCase().localeCompare(b.toLowerCase()));
  const raw = `HashKey=${HASH_KEY}&${sorted.map(([k,v]) => `${k}=${v}`).join('&')}&HashIV=${HASH_IV}`;
  return crypto.createHash('sha256').update(ecpayUrlEncode(raw), 'utf8').digest('hex').toUpperCase();
}

// 測試 1: CMV 測試向量
const params = {
  MerchantID: '3002607', MerchantTradeNo: 'Test1234567890',
  MerchantTradeDate: '2025/01/01 12:00:00', PaymentType: 'aio',
  TotalAmount: '100', TradeDesc: '測試', ItemName: '測試商品',
  ReturnURL: 'https://example.com/notify', ChoosePayment: 'ALL', EncryptType: '1',
};
const expected = '291CBA324D31FB5A4BBBFDF2CFE5D32598524753AFD4959C3BF590C5B2F57FB2';
const result = generateCMV(params);
console.log(`[CMV SHA256] ${result === expected ? 'PASS ✓' : 'FAIL ✗'} — ${result}`);

// 測試 2: 端點可達性
const endpoints = [
  { name: 'AIO 金流', host: 'payment-stage.ecpay.com.tw' },
  { name: 'ECPG Token', host: 'ecpg-stage.ecpay.com.tw' },
  { name: '電子發票', host: 'einvoice-stage.ecpay.com.tw' },
  { name: '物流', host: 'logistics-stage.ecpay.com.tw' },
  { name: '電子票證', host: 'ecticket-stage.ecpay.com.tw' },
];

for (const ep of endpoints) {
  https.get(`https://${ep.host}`, { timeout: 10000 }, (res) => {
    console.log(`[${ep.name}] ${res.statusCode < 500 ? 'REACHABLE ✓' : 'ERROR ✗'} — HTTP ${res.statusCode}`);
  }).on('error', (err) => {
    console.log(`[${ep.name}] UNREACHABLE ✗ — ${err.message}`);
  });
}
```

### Python 冒煙測試

```python
# smoke_test.py — 執行: python smoke_test.py
import hashlib, urllib.parse, ssl, urllib.request

HASH_KEY = 'pwFHCqoQZGmho4w6'
HASH_IV = 'EkRm7iFT261dpevs'

def ecpay_url_encode(s):
    encoded = urllib.parse.quote_plus(s).lower()
    for old, new in {'%2d':'-','%5f':'_','%2e':'.','%21':'!','%2a':'*','%28':'(','%29':')'}.items():
        encoded = encoded.replace(old, new)
    return encoded.replace('~', '%7e')

def generate_cmv(params):
    filtered = sorted(((k,v) for k,v in params.items() if k != 'CheckMacValue'), key=lambda x: x[0].lower())
    raw = f"HashKey={HASH_KEY}&{'&'.join(f'{k}={v}' for k,v in filtered)}&HashIV={HASH_IV}"
    return hashlib.sha256(ecpay_url_encode(raw).encode('utf-8')).hexdigest().upper()

# 測試 1: CMV 測試向量
params = {
    'MerchantID': '3002607', 'MerchantTradeNo': 'Test1234567890',
    'MerchantTradeDate': '2025/01/01 12:00:00', 'PaymentType': 'aio',
    'TotalAmount': '100', 'TradeDesc': '測試', 'ItemName': '測試商品',
    'ReturnURL': 'https://example.com/notify', 'ChoosePayment': 'ALL', 'EncryptType': '1',
}
expected = '291CBA324D31FB5A4BBBFDF2CFE5D32598524753AFD4959C3BF590C5B2F57FB2'
result = generate_cmv(params)
print(f"[CMV SHA256] {'PASS ✓' if result == expected else 'FAIL ✗'} — {result}")

# 測試 2: 端點可達性
endpoints = [
    ('AIO 金流', 'payment-stage.ecpay.com.tw'),
    ('ECPG Token', 'ecpg-stage.ecpay.com.tw'),
    ('電子發票', 'einvoice-stage.ecpay.com.tw'),
    ('物流', 'logistics-stage.ecpay.com.tw'),
    ('電子票證', 'ecticket-stage.ecpay.com.tw'),
]
ctx = ssl.create_default_context()
for name, host in endpoints:
    try:
        resp = urllib.request.urlopen(f'https://{host}', timeout=10, context=ctx)
        print(f"[{name}] REACHABLE ✓ — HTTP {resp.status}")
    except urllib.error.HTTPError as e:
        print(f"[{name}] {'REACHABLE ✓' if e.code < 500 else 'ERROR ✗'} — HTTP {e.code}")
    except Exception as e:
        print(f"[{name}] UNREACHABLE ✗ — {e}")
```

> **注意**：冒煙測試僅驗證加密正確性和端點可達性，不會發送實際交易。
> 正式環境冒煙測試需替換為正式 domain（去掉 `-stage`）。

## 相關文件

- 除錯指南：[guides/15-troubleshooting.md](./15-troubleshooting.md)
- 金流 AIO：[guides/01-payment-aio.md](./01-payment-aio.md)
- 站內付 ECPG：[guides/02-payment-ecpg.md](./02-payment-ecpg.md)
- POS 刷卡機：[guides/17-pos-integration.md](./17-pos-integration.md)
- 直播收款：[guides/18-livestream-payment.md](./18-livestream-payment.md)
- 離線發票：[guides/19-invoice-offline.md](./19-invoice-offline.md)
- 錯誤碼排查：見 [guides/21-error-codes-reference.md](./21-error-codes-reference.md)
- Callback 處理：見 [guides/22-webhook-events-reference.md](./22-webhook-events-reference.md)
- 效能與擴展：見 [guides/23-performance-scaling.md](./23-performance-scaling.md)
