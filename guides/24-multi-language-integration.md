> 對應 ECPay API 版本 | 最後更新：2026-03

<!-- AI Section Index（供 AI 部分讀取大檔案用）
Go E2E: line 93-443 (CMV: 95, AES: 231)
Java E2E: line 444-708 (CMV: 446, AES: 579)
C# E2E: line 709-914 (CMV: 711, AES: 813)
TypeScript E2E: line 915-1173 (CMV: 920, AES: 1012)
Kotlin E2E: line 1174-1398 (CMV: 1176, AES: 1286)
Ruby E2E: line 1399-1552 (CMV: 1401, AES: 1479)
Swift/Rust: line 1553-1989 (Swift CMV: 1555, Swift AES: 1597, Rust CMV: 1744, Rust AES: 1854)
Mobile App: line 1990-2027 | 非 PHP Checklist: line 2028-2049
C/C++ 注意事項: line 2050-2096 | 跨語言測試: line 2097-2104
Production 環境切換: line 2105-end
-->

# 多語言整合完整指南

## 語言快速導航

| 語言 | CMV-SHA256 (AIO) | AES-JSON (發票) | 完整 E2E | 行號範圍 |
|------|:-:|:-:|:-:|---------|
| **Go** | ✅ Web Server | ✅ B2C 發票 | ✅ | line 93-443 |
| **Java** | ✅ Main class | ✅ B2C 發票 | ✅ | line 444-708 |
| **C#** | ✅ Program | ✅ B2C 發票 | ✅ | line 709-914 |
| **TypeScript** | ✅ Express | ✅ B2C 發票 | ✅ | line 915-1173 |
| **Kotlin** | ✅ Main | ✅ B2C 發票 | ✅ | line 1174-1398 |
| **Ruby** | ✅ Sinatra | ✅ B2C 發票 | ✅ | line 1399-1552 |
| **Swift** | ✅ CLI | ✅ AES-JSON | ✅ + iOS | line 1553-1743 |
| **Rust** | ✅ CLI + Axum | ✅ AES-JSON | ✅ | line 1744-1989 |
| **Mobile App** | — | — | iOS + Android 指引 | line 1990-2027 |
| **C/C++** | — | — | 整合注意事項 | line 2050-2096 |

> **只需看你的語言**：使用 AI Section Index 行號範圍只讀取對應區段，不需載入全文。
> **只需加密函式？** → [guides/13 CheckMacValue](./13-checkmacvalue.md) 或 [guides/14 AES](./14-aes-encryption.md)（12 語言全覆蓋）。

## 概述

本指南為非 PHP/Node.js/Python 開發者提供完整的 ECPay API 整合範例，涵蓋 Go、Java、C#、TypeScript、Kotlin 五大語言的端到端實作。

> **Python / Node.js 開發者**：你的 Quick Start 和 AES-JSON 端到端範例已在 guides/00-getting-started.md 提供。
> - CMV-SHA256 AIO Quick Start：guides/00 §Quick Start
> - AES-JSON 發票完整範例：guides/00 §AES-JSON 端到端範例
> - CheckMacValue 完整實作：guides/13 §Python / §Node.js
> - AES 加密/解密完整實作：guides/14 §Python / §Node.js

**前置條件**：
- 已讀 [guides/20-http-protocol-reference.md](./20-http-protocol-reference.md)（HTTP 協議規格）
- 已讀 [guides/13-checkmacvalue.md](./13-checkmacvalue.md)（CMV-SHA256/CMV-MD5 認證）或 [guides/14-aes-encryption.md](./14-aes-encryption.md)（AES-JSON 認證）

**涵蓋語言**：Go、Java、C#、TypeScript、Kotlin（完整 E2E）+ 全 12 語言通用參考

## HTTP Client 推薦表

| 語言 | 推薦 Client | 最低版本 | 安裝命令 | Timeout 設定 | 重試建議 |
|------|------------|---------|---------|-------------|---------|
| Go | net/http (stdlib) | Go 1.21+ | — | `client.Timeout = 30 * time.Second` | 自行實作或用 hashicorp/go-retryablehttp |
| Java | java.net.http.HttpClient | JDK 11+ | — | `connectTimeout(Duration.ofSeconds(30))` | 自行實作 exponential backoff |
| C# | HttpClient | .NET 6+ | — | `Timeout = TimeSpan.FromSeconds(30)` | 用 Polly NuGet 套件 |
| Node.js | built-in fetch / axios | Node 18+ / axios 1.7+ | `npm install axios` | `signal: AbortSignal.timeout(30000)` | axios-retry |
| Python | httpx (async) / requests (sync) | httpx 0.27+ / requests 2.32+ | `pip install httpx` | `timeout=30.0` | tenacity |
| Rust | reqwest | 0.12+ | `cargo add reqwest` | `timeout(Duration::from_secs(30))` | 自行實作或 reqwest-retry |
| Swift | URLSession | iOS 13+ / macOS 10.15+ | — | `timeoutIntervalForRequest = 30` | 自行實作 |
| Kotlin | OkHttp | 4.12+ | `implementation("com.squareup.okhttp3:okhttp:4.12.0")` | `callTimeout(30, TimeUnit.SECONDS)` | 自行實作 |
| Ruby | Net::HTTP (stdlib) | Ruby 3.0+ | — | `open_timeout = 30; read_timeout = 30` | 用 retryable gem |
| C | libcurl | 8.0+ | 系統套件管理器 | `CURLOPT_TIMEOUT 30L` | 自行實作 |
| C++ | cpr | 1.10+ | `vcpkg install cpr` 或 CMake FetchContent | `cpr::Timeout{30000}` | 自行實作 |

> **所有語言共通**：ECPay API 收到 403 表示觸發限流，需等待約 30 分鐘。建議 API 呼叫間隔至少 200ms。

## JSON 序列化全語言對照表

> ⚠️ **通用警告**：AES-JSON 的 AES 加密結果取決於 JSON 字串的精確位元內容。
> 不同的 key 順序、空格、HTML 轉義都會產生不同的密文，導致 ECPay API 解密失敗。
> 必須確保 JSON 輸出為 compact 格式（無多餘空格），且 key 順序與預期一致。

| 語言 | 函式 | Key 順序保證 | Compact 模式 | HTML 轉義 | 必要設定 |
|------|------|:----------:|:----------:|:---------:|---------|
| PHP | `json_encode()` | 依插入順序 | 預設 compact | 預設不轉義 | 無需特殊設定（基準實作） |
| Python | `json.dumps()` | dict 依插入順序 (3.7+) | 需設定 | 預設不轉義 | `separators=(',', ':'), ensure_ascii=False` |
| Node.js | `JSON.stringify()` | 依插入順序 | 預設 compact | 預設不轉義 | 無需特殊設定 |
| Go | `json.Marshal()` | struct: 欄位定義順序; map: 字母序 | 預設 compact | **預設轉義** `<>&` | `json.NewEncoder(buf)` + `SetEscapeHTML(false)` |
| Java | `Gson` | HashMap **不保證**順序 | 預設 compact | **預設轉義** | `GsonBuilder().disableHtmlEscaping()` + 用 `LinkedHashMap` 保序 |
| C# | `System.Text.Json` | class 屬性定義順序 | 預設 compact | 預設不轉義 | 使用 class 定義屬性順序，或用 `JsonSerializerOptions` |
| Kotlin | `Gson` | HashMap **不保證**順序 | 預設 compact | **預設轉義** | `GsonBuilder().disableHtmlEscaping()` + 用 `linkedMapOf()` 保序 |
| Swift | `JSONEncoder` | 預設不保證 | 預設 compact | 預設不轉義 | 設定 `.sortedKeys`；或用 `Codable` struct |
| Ruby | `JSON.generate()` | Hash 依插入順序 (1.9+) | 預設 compact | 預設不轉義 | 勿用 `pretty_generate`；用 `JSON.generate(data)` |
| Rust | `serde_json` | struct: 欄位定義順序; Map: 依實作 | 預設 compact | 預設不轉義 | 用 struct 確保欄位順序穩定 |
| C | `cJSON` | 依新增順序 | 預設 compact | 預設不轉義 | 用 `cJSON_PrintUnformatted()` |
| C++ | `nlohmann/json` | ordered_json 依插入順序 | 預設 compact | 預設不轉義 | 用 `nlohmann::ordered_json` + `dump()` |

---

## Go 完整整合範例

### CMV-SHA256 — AIO 信用卡付款（完整 Web Server）

> 對應 PHP 範例：`scripts/SDK_PHP/example/Payment/Aio/CreateCreditOrder.php`

```
go.mod:
  module ecpay-demo
  go 1.21
```

```go
package main

import (
	"crypto/sha256"
	"crypto/subtle"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"
)

const (
	merchantID = "3002607"
	hashKey    = "pwFHCqoQZGmho4w6"
	hashIV     = "EkRm7iFT261dpevs"
	aioURL     = "https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5"
)

// 完整實作見 guides/13-checkmacvalue.md §Go
// ecpayURLEncode 實作 ECPay 專用的 URL encode（參考 guides/13-checkmacvalue.md）
func ecpayURLEncode(s string) string {
	encoded := url.QueryEscape(s) // 空格→+
	encoded = strings.ReplaceAll(encoded, "~", "%7e")
	encoded = strings.ToLower(encoded)
	replacements := map[string]string{
		"%2d": "-", "%5f": "_", "%2e": ".", "%21": "!",
		"%2a": "*", "%28": "(", "%29": ")",
	}
	for old, char := range replacements {
		encoded = strings.ReplaceAll(encoded, old, char)
	}
	return encoded
}

// generateCheckMacValue 產生 SHA256 CheckMacValue
func generateCheckMacValue(params map[string]string) string {
	keys := make([]string, 0, len(params))
	for k := range params {
		if k == "CheckMacValue" {
			continue
		}
		keys = append(keys, k)
	}
	sort.Slice(keys, func(i, j int) bool {
		return strings.ToLower(keys[i]) < strings.ToLower(keys[j])
	})

	var pairs []string
	for _, k := range keys {
		pairs = append(pairs, fmt.Sprintf("%s=%s", k, params[k]))
	}
	raw := fmt.Sprintf("HashKey=%s&%s&HashIV=%s", hashKey, strings.Join(pairs, "&"), hashIV)
	encoded := ecpayURLEncode(raw)
	hash := sha256.Sum256([]byte(encoded))
	return fmt.Sprintf("%X", hash)
}

func checkoutHandler(w http.ResponseWriter, r *http.Request) {
	tradeNo := fmt.Sprintf("Go%d", time.Now().Unix())
	tradeDate := time.Now().Format("2006/01/02 15:04:05")

	params := map[string]string{
		"MerchantID":        merchantID,
		"MerchantTradeNo":   tradeNo,
		"MerchantTradeDate": tradeDate,
		"PaymentType":       "aio",
		"TotalAmount":       "100",
		"TradeDesc":         "測試交易",
		"ItemName":          "測試商品",
		"ReturnURL":         "https://your-domain.com/ecpay/notify", // ⚠️ 必須替換：填入你的公開回呼 URL
		"ChoosePayment":     "Credit",
		"EncryptType":       "1",
	}
	params["CheckMacValue"] = generateCheckMacValue(params)

	// 產生自動提交表單
	var fields strings.Builder
	for k, v := range params {
		fields.WriteString(fmt.Sprintf(`<input type="hidden" name="%s" value="%s">`, k, v))
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	fmt.Fprintf(w, `<form id="ecpay" method="POST" action="%s">%s</form>
<script>document.getElementById('ecpay').submit();</script>`, aioURL, fields.String())
}

func notifyHandler(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		fmt.Fprint(w, "0|ParseError")
		return
	}
	params := make(map[string]string)
	for k, v := range r.PostForm {
		params[k] = v[0]
	}

	// 驗證 CheckMacValue
	receivedCMV := params["CheckMacValue"]
	calculatedCMV := generateCheckMacValue(params)
	if subtle.ConstantTimeCompare([]byte(receivedCMV), []byte(calculatedCMV)) != 1 {
		fmt.Fprint(w, "0|CheckMacValue Error")
		return
	}

	if params["RtnCode"] == "1" && params["SimulatePaid"] == "0" {
		// 真實付款成功，處理訂單邏輯
		fmt.Printf("付款成功: %s\n", params["MerchantTradeNo"])
	}

	// 必須回應 1|OK
	fmt.Fprint(w, "1|OK")
}

func main() {
	http.HandleFunc("/checkout", checkoutHandler)
	http.HandleFunc("/ecpay/notify", notifyHandler)
	fmt.Println("Server: http://localhost:3000/checkout")
	http.ListenAndServe(":3000", nil)
}
```

**執行**：`go run main.go`，瀏覽 `http://localhost:3000/checkout`。
使用測試信用卡 `4311-9522-2222-2222`，CVV `222`，3D 驗證碼 `1234`。

### AES-JSON — B2C 發票開立

> 對應 PHP 範例：`scripts/SDK_PHP/example/Invoice/B2C/Issue.php`

```go
package main

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	invoiceMerchantID = "2000132"
	invoiceHashKey    = "ejCk326UnaZWKisg"
	invoiceHashIV     = "q9jcZX8Ib9LM8wYk"
	invoiceURL        = "https://einvoice-stage.ecpay.com.tw/B2CInvoice/Issue"
)

func pkcs7Pad(data []byte, blockSize int) []byte {
	padding := blockSize - len(data)%blockSize
	padText := bytes.Repeat([]byte{byte(padding)}, padding)
	return append(data, padText...)
}

func pkcs7Unpad(data []byte) ([]byte, error) {
	if len(data) == 0 {
		return nil, fmt.Errorf("empty data")
	}
	padding := int(data[len(data)-1])
	if padding < 1 || padding > aes.BlockSize || padding > len(data) {
		return nil, fmt.Errorf("invalid padding")
	}
	return data[:len(data)-padding], nil
}

// 完整實作見 guides/13-checkmacvalue.md §Go
// ecpayURLEncode 同上方 CMV-SHA256 範例
func ecpayURLEncode(s string) string {
	encoded := url.QueryEscape(s)
	encoded = strings.ReplaceAll(encoded, "~", "%7e")
	encoded = strings.ToLower(encoded)
	for old, char := range map[string]string{
		"%2d": "-", "%5f": "_", "%2e": ".", "%21": "!",
		"%2a": "*", "%28": "(", "%29": ")",
	} {
		encoded = strings.ReplaceAll(encoded, old, char)
	}
	return encoded
}

// 完整實作見 guides/14-aes-encryption.md §Go
// aesURLEncode 用於 AES 加密前的 URL 編碼
// 完整實作見 guides/14-aes-encryption.md §Go
// AES 專用 URL encode — 不做 toLowerCase 和 .NET 還原（與 CMV ecpayURLEncode 不同）
func aesURLEncode(s string) string {
	encoded := url.QueryEscape(s)
	r := strings.NewReplacer("~", "%7e", "!", "%21", "*", "%2a", "'", "%27", "(", "%28", ")", "%29")
	return r.Replace(encoded)
}

func aesEncrypt(data interface{}, hashKey, hashIV string) (string, error) {
	// 使用 json.NewEncoder + SetEscapeHTML(false) 避免 <, >, & 被轉義
	var buf bytes.Buffer
	encoder := json.NewEncoder(&buf)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(data); err != nil {
		return "", err
	}
	// Encode 會加 \n，需移除
	jsonStr := strings.TrimRight(buf.String(), "\n")

	urlEncoded := aesURLEncode(jsonStr)

	key := []byte(hashKey)[:16]
	iv := []byte(hashIV)[:16]
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	padded := pkcs7Pad([]byte(urlEncoded), aes.BlockSize)
	encrypted := make([]byte, len(padded))
	cipher.NewCBCEncrypter(block, iv).CryptBlocks(encrypted, padded)
	return base64.StdEncoding.EncodeToString(encrypted), nil
}

func aesDecrypt(cipherText, hashKey, hashIV string) (map[string]interface{}, error) {
	encrypted, err := base64.StdEncoding.DecodeString(cipherText)
	if err != nil {
		return nil, err
	}
	key := []byte(hashKey)[:16]
	iv := []byte(hashIV)[:16]
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	decrypted := make([]byte, len(encrypted))
	cipher.NewCBCDecrypter(block, iv).CryptBlocks(decrypted, encrypted)
	unpadded, err := pkcs7Unpad(decrypted)
	if err != nil {
		return nil, err
	}
	urlDecoded, err := url.QueryUnescape(string(unpadded))
	if err != nil {
		return nil, err
	}
	var result map[string]interface{}
	err = json.Unmarshal([]byte(urlDecoded), &result)
	return result, err
}

func issueInvoice() error {
	invoiceData := map[string]interface{}{
		"MerchantID":    invoiceMerchantID,
		"RelateNumber":  fmt.Sprintf("INV%d", time.Now().Unix()),
		"CustomerEmail": "test@example.com",
		"Print":         "0",
		"Donation":      "0",
		"TaxType":       "1",
		"SalesAmount":   100,
		"Items": []map[string]interface{}{
			{
				"ItemName":    "測試商品",
				"ItemCount":   1,
				"ItemWord":    "件",
				"ItemPrice":   100,
				"ItemTaxType": "1",
				"ItemAmount":  100,
			},
		},
		"InvType": "07",
	}

	encryptedData, err := aesEncrypt(invoiceData, invoiceHashKey, invoiceHashIV)
	if err != nil {
		return fmt.Errorf("加密失敗: %w", err)
	}

	requestBody := map[string]interface{}{
		"MerchantID": invoiceMerchantID,
		"RqHeader": map[string]interface{}{
			"Timestamp": time.Now().Unix(),
			"Revision":  "3.0.0",
		},
		"Data": encryptedData,
	}

	bodyBytes, err := json.Marshal(requestBody)
	if err != nil {
		return err
	}

	resp, err := http.Post(invoiceURL, "application/json", bytes.NewReader(bodyBytes))
	if err != nil {
		return fmt.Errorf("HTTP 請求失敗: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	var result map[string]interface{}
	if err := json.Unmarshal(respBody, &result); err != nil {
		return fmt.Errorf("回應解析失敗: %w", err)
	}

	// 雙層錯誤檢查
	transCode, _ := result["TransCode"].(float64)
	if transCode != 1 {
		return fmt.Errorf("外層錯誤 TransCode=%.0f: %v", transCode, result["TransMsg"])
	}

	data, err := aesDecrypt(result["Data"].(string), invoiceHashKey, invoiceHashIV)
	if err != nil {
		return fmt.Errorf("解密失敗: %w", err)
	}

	rtnCode, _ := data["RtnCode"].(float64)
	if rtnCode != 1 {
		return fmt.Errorf("業務錯誤 RtnCode=%.0f: %v", rtnCode, data["RtnMsg"])
	}

	fmt.Printf("發票號碼: %v\n", data["InvoiceNo"])
	return nil
}

func main() {
	if err := issueInvoice(); err != nil {
		fmt.Printf("發票開立失敗: %v\n", err)
	}
}
```

**執行**：`go run invoice.go`

> **⚠️ AES vs CMV URL Encode 差異**：`ecpayURLEncode`（CMV 用）會做 toLowerCase + .NET 字元替換；
> `aesURLEncode`（AES 加密用）只做標準 `urlencode` + `~→%7e`。混用是常見錯誤。
> 詳見 [guides/14-aes-encryption.md](./14-aes-encryption.md)。

---

## Java 完整整合範例

### CMV-SHA256 — AIO 信用卡付款

> 對應 PHP 範例：`scripts/SDK_PHP/example/Payment/Aio/CreateCreditOrder.php`
>
> 純 Java 版（java.net.http.HttpClient, JDK 11+），不需外部依賴。

```java
import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpExchange;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

public class EcpayAioDemo {

    static final String MERCHANT_ID = "3002607";
    static final String HASH_KEY = "pwFHCqoQZGmho4w6";
    static final String HASH_IV = "EkRm7iFT261dpevs";
    static final String AIO_URL = "https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5";

    // 完整實作見 guides/13-checkmacvalue.md §Java
    static String ecpayUrlEncode(String source) throws Exception {
        String encoded = URLEncoder.encode(source, "UTF-8").replace("~", "%7e");
        encoded = encoded.toLowerCase();
        Map<String, String> replacements = Map.of(
            "%2d", "-", "%5f", "_", "%2e", ".", "%21", "!",
            "%2a", "*", "%28", "(", "%29", ")"
        );
        for (Map.Entry<String, String> e : replacements.entrySet()) {
            encoded = encoded.replace(e.getKey(), e.getValue());
        }
        return encoded;
    }

    static String generateCheckMacValue(Map<String, String> params) throws Exception {
        Map<String, String> filtered = new TreeMap<>(String.CASE_INSENSITIVE_ORDER);
        params.entrySet().stream()
            .filter(e -> !"CheckMacValue".equals(e.getKey()))
            .forEach(e -> filtered.put(e.getKey(), e.getValue()));

        String paramStr = filtered.entrySet().stream()
            .map(e -> e.getKey() + "=" + e.getValue())
            .collect(Collectors.joining("&"));
        String raw = "HashKey=" + HASH_KEY + "&" + paramStr + "&HashIV=" + HASH_IV;
        String urlEncoded = ecpayUrlEncode(raw);

        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] hash = digest.digest(urlEncoded.getBytes(StandardCharsets.UTF_8));
        StringBuilder hex = new StringBuilder();
        for (byte b : hash) hex.append(String.format("%02X", b));
        return hex.toString();
    }

    static void handleCheckout(HttpExchange exchange) throws Exception {
        String tradeNo = "Java" + System.currentTimeMillis() / 1000;
        String tradeDate = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm:ss"));

        Map<String, String> params = new LinkedHashMap<>();
        params.put("MerchantID", MERCHANT_ID);
        params.put("MerchantTradeNo", tradeNo);
        params.put("MerchantTradeDate", tradeDate);
        params.put("PaymentType", "aio");
        params.put("TotalAmount", "100");
        params.put("TradeDesc", "測試交易");
        params.put("ItemName", "測試商品");
        params.put("ReturnURL", "https://your-domain.com/ecpay/notify"); // ⚠️ 必須替換
        params.put("ChoosePayment", "Credit");
        params.put("EncryptType", "1");
        params.put("CheckMacValue", generateCheckMacValue(params));

        StringBuilder fields = new StringBuilder();
        for (Map.Entry<String, String> e : params.entrySet()) {
            fields.append(String.format("<input type=\"hidden\" name=\"%s\" value=\"%s\">", e.getKey(), e.getValue()));
        }
        String html = String.format(
            "<form id=\"ecpay\" method=\"POST\" action=\"%s\">%s</form><script>document.getElementById('ecpay').submit();</script>",
            AIO_URL, fields
        );

        byte[] response = html.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("Content-Type", "text/html; charset=utf-8");
        exchange.sendResponseHeaders(200, response.length);
        exchange.getResponseBody().write(response);
        exchange.getResponseBody().close();
    }

    static void handleNotify(HttpExchange exchange) throws Exception {
        String body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
        Map<String, String> params = new LinkedHashMap<>();
        for (String pair : body.split("&")) {
            String[] kv = pair.split("=", 2);
            params.put(URLDecoder.decode(kv[0], "UTF-8"),
                      kv.length > 1 ? URLDecoder.decode(kv[1], "UTF-8") : "");
        }

        String received = params.get("CheckMacValue");
        String calculated = generateCheckMacValue(params);
        String response;
        if (!java.security.MessageDigest.isEqual(
                received.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                calculated.getBytes(java.nio.charset.StandardCharsets.UTF_8))) {
            response = "0|CheckMacValue Error";
        } else {
            if ("1".equals(params.get("RtnCode")) && "0".equals(params.get("SimulatePaid"))) {
                System.out.println("付款成功: " + params.get("MerchantTradeNo"));
            }
            response = "1|OK";
        }

        byte[] responseBytes = response.getBytes(StandardCharsets.UTF_8);
        exchange.sendResponseHeaders(200, responseBytes.length);
        exchange.getResponseBody().write(responseBytes);
        exchange.getResponseBody().close();
    }

    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(3000), 0);
        server.createContext("/checkout", EcpayAioDemo::handleCheckout);
        server.createContext("/ecpay/notify", EcpayAioDemo::handleNotify);
        server.start();
        System.out.println("Server: http://localhost:3000/checkout");
    }
}
```

**編譯與執行**：`javac EcpayAioDemo.java && java EcpayAioDemo`

### AES-JSON — B2C 發票開立

> 對應 PHP 範例：`scripts/SDK_PHP/example/Invoice/B2C/Issue.php`

```java
import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.*;

// 需要 Gson: Maven com.google.code.gson:gson:2.10+
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

public class EcpayInvoiceDemo {

    static final String MERCHANT_ID = "2000132";
    static final String HASH_KEY = "ejCk326UnaZWKisg";
    static final String HASH_IV = "q9jcZX8Ib9LM8wYk";
    static final String INVOICE_URL = "https://einvoice-stage.ecpay.com.tw/B2CInvoice/Issue";

    // Gson：必須 disableHtmlEscaping，否則 < > & 會被轉義
    // 必須使用 LinkedHashMap 保證 key 順序
    static final Gson gson = new GsonBuilder().disableHtmlEscaping().create();

    // 完整實作見 guides/14-aes-encryption.md §Java
    // AES 專用 URL encode — 不做 toLowerCase 和 .NET 還原（與 CMV 不同）
    static String aesUrlEncode(String source) throws Exception {
        return URLEncoder.encode(source, "UTF-8")
            .replace("~", "%7e").replace("*", "%2a")
            .replace("'", "%27").replace("(", "%28").replace(")", "%29");
    }

    static String aesEncrypt(Map<String, Object> data, String hashKey, String hashIv) throws Exception {
        String jsonStr = gson.toJson(data);
        String urlEncoded = aesUrlEncode(jsonStr);

        byte[] keyBytes = Arrays.copyOf(hashKey.getBytes(StandardCharsets.UTF_8), 16);
        byte[] ivBytes = Arrays.copyOf(hashIv.getBytes(StandardCharsets.UTF_8), 16);

        Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding"); // PKCS5 = PKCS7 for AES-128
        cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(keyBytes, "AES"), new IvParameterSpec(ivBytes));
        byte[] encrypted = cipher.doFinal(urlEncoded.getBytes(StandardCharsets.UTF_8));
        return Base64.getEncoder().encodeToString(encrypted);
    }

    static Map<String, Object> aesDecrypt(String cipherText, String hashKey, String hashIv) throws Exception {
        byte[] encrypted = Base64.getDecoder().decode(cipherText);
        byte[] keyBytes = Arrays.copyOf(hashKey.getBytes(StandardCharsets.UTF_8), 16);
        byte[] ivBytes = Arrays.copyOf(hashIv.getBytes(StandardCharsets.UTF_8), 16);

        Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
        cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(keyBytes, "AES"), new IvParameterSpec(ivBytes));
        byte[] decrypted = cipher.doFinal(encrypted);
        String urlDecoded = URLDecoder.decode(new String(decrypted, StandardCharsets.UTF_8), "UTF-8");
        return gson.fromJson(urlDecoded, Map.class);
    }

    public static void main(String[] args) throws Exception {
        // 使用 LinkedHashMap 確保 key 順序
        Map<String, Object> invoiceData = new LinkedHashMap<>();
        invoiceData.put("MerchantID", MERCHANT_ID);
        invoiceData.put("RelateNumber", "INV" + System.currentTimeMillis() / 1000);
        invoiceData.put("CustomerEmail", "test@example.com");
        invoiceData.put("Print", "0");
        invoiceData.put("Donation", "0");
        invoiceData.put("TaxType", "1");
        invoiceData.put("SalesAmount", 100);
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("ItemName", "測試商品");
        item.put("ItemCount", 1);
        item.put("ItemWord", "件");
        item.put("ItemPrice", 100);
        item.put("ItemTaxType", "1");
        item.put("ItemAmount", 100);
        invoiceData.put("Items", List.of(item));
        invoiceData.put("InvType", "07");

        String encryptedData = aesEncrypt(invoiceData, HASH_KEY, HASH_IV);

        Map<String, Object> requestBody = new LinkedHashMap<>();
        requestBody.put("MerchantID", MERCHANT_ID);
        requestBody.put("RqHeader", Map.of("Timestamp", System.currentTimeMillis() / 1000, "Revision", "3.0.0"));
        requestBody.put("Data", encryptedData);

        HttpClient client = HttpClient.newBuilder()
            .connectTimeout(java.time.Duration.ofSeconds(30))
            .build();
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(INVOICE_URL))
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(gson.toJson(requestBody)))
            .build();

        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
        Map<String, Object> result = gson.fromJson(response.body(), Map.class);

        // 雙層錯誤檢查
        double transCode = ((Number) result.get("TransCode")).doubleValue();
        if (transCode != 1) {
            throw new RuntimeException("外層錯誤 TransCode=" + (int) transCode + ": " + result.get("TransMsg"));
        }

        Map<String, Object> data = aesDecrypt((String) result.get("Data"), HASH_KEY, HASH_IV);
        double rtnCode = ((Number) data.get("RtnCode")).doubleValue();
        if (rtnCode != 1) {
            throw new RuntimeException("業務錯誤 RtnCode=" + (int) rtnCode + ": " + data.get("RtnMsg"));
        }

        System.out.println("發票號碼: " + data.get("InvoiceNo"));
    }
}
```

**編譯與執行**：
```bash
# 需先下載 gson-2.10.1.jar
javac -cp gson-2.10.1.jar EcpayInvoiceDemo.java
java -cp .:gson-2.10.1.jar EcpayInvoiceDemo
```

---

## C# 完整整合範例

### CMV-SHA256 — AIO 信用卡付款

> 對應 PHP 範例：`scripts/SDK_PHP/example/Payment/Aio/CreateCreditOrder.php`
>
> ASP.NET Core 8 Minimal API

```csharp
// 建立專案: dotnet new web -n EcpayDemo
// 執行: dotnet run
using System.Security.Cryptography;
using System.Text;
using System.Web;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

const string MerchantID = "3002607";
const string HashKey = "pwFHCqoQZGmho4w6";
const string HashIV = "EkRm7iFT261dpevs";
const string AioUrl = "https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5";

// 完整實作見 guides/13-checkmacvalue.md §C#
string EcpayUrlEncode(string source)
{
    var encoded = HttpUtility.UrlEncode(source)?.Replace("~", "%7e") ?? "";
    encoded = encoded.ToLower();
    var replacements = new Dictionary<string, string>
    {
        { "%2d", "-" }, { "%5f", "_" }, { "%2e", "." }, { "%21", "!" },
        { "%2a", "*" }, { "%28", "(" }, { "%29", ")" }
    };
    foreach (var (old, @new) in replacements)
        encoded = encoded.Replace(old, @new);
    return encoded;
}

string GenerateCheckMacValue(Dictionary<string, string> parameters)
{
    var filtered = parameters
        .Where(p => p.Key != "CheckMacValue")
        .OrderBy(p => p.Key, StringComparer.OrdinalIgnoreCase);
    var paramStr = string.Join("&", filtered.Select(p => $"{p.Key}={p.Value}"));
    var raw = $"HashKey={HashKey}&{paramStr}&HashIV={HashIV}";
    var urlEncoded = EcpayUrlEncode(raw);
    var hash = SHA256.HashData(Encoding.UTF8.GetBytes(urlEncoded));
    return Convert.ToHexString(hash);
}

app.MapGet("/checkout", () =>
{
    var tradeNo = $"CS{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";
    var tradeDate = DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss");

    var parameters = new Dictionary<string, string>
    {
        ["MerchantID"] = MerchantID,
        ["MerchantTradeNo"] = tradeNo,
        ["MerchantTradeDate"] = tradeDate,
        ["PaymentType"] = "aio",
        ["TotalAmount"] = "100",
        ["TradeDesc"] = "測試交易",
        ["ItemName"] = "測試商品",
        ["ReturnURL"] = "https://your-domain.com/ecpay/notify", // ⚠️ 必須替換
        ["ChoosePayment"] = "Credit",
        ["EncryptType"] = "1"
    };
    parameters["CheckMacValue"] = GenerateCheckMacValue(parameters);

    var fields = string.Join("", parameters.Select(p =>
        $"<input type=\"hidden\" name=\"{p.Key}\" value=\"{p.Value}\">"));
    var html = $"""
        <form id="ecpay" method="POST" action="{AioUrl}">{fields}</form>
        <script>document.getElementById('ecpay').submit();</script>
        """;
    return Results.Content(html, "text/html");
});

app.MapPost("/ecpay/notify", async (HttpContext context) =>
{
    var form = await context.Request.ReadFormAsync();
    var parameters = form.ToDictionary(f => f.Key, f => f.Value.ToString());

    var received = parameters.GetValueOrDefault("CheckMacValue", "");
    var calculated = GenerateCheckMacValue(parameters);
    if (!System.Security.Cryptography.CryptographicOperations.FixedTimeEquals(
            System.Text.Encoding.UTF8.GetBytes(received),
            System.Text.Encoding.UTF8.GetBytes(calculated)))
        return Results.Text("0|CheckMacValue Error");

    if (parameters.GetValueOrDefault("RtnCode") == "1" &&
        parameters.GetValueOrDefault("SimulatePaid") == "0")
    {
        Console.WriteLine($"付款成功: {parameters.GetValueOrDefault("MerchantTradeNo")}");
    }
    return Results.Text("1|OK");
});

app.Run("http://localhost:3000");
```

**執行**：`dotnet run`，瀏覽 `http://localhost:3000/checkout`。

### AES-JSON — B2C 發票開立

> 對應 PHP 範例：`scripts/SDK_PHP/example/Invoice/B2C/Issue.php`

```csharp
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Web;

const string MerchantID = "2000132";
const string HashKey = "ejCk326UnaZWKisg";
const string HashIV = "q9jcZX8Ib9LM8wYk";
const string InvoiceUrl = "https://einvoice-stage.ecpay.com.tw/B2CInvoice/Issue";

// 完整實作見 guides/14-aes-encryption.md §C#
// ⚠️ AES 加密專用 URL encode — 不做 ToLower() 和 .NET 替換！與 CMV 的 EcpayUrlEncode 不同
string AesUrlEncode(string source) =>
    HttpUtility.UrlEncode(source)
        ?.Replace("~", "%7e").Replace("!", "%21").Replace("*", "%2a")
        .Replace("(", "%28").Replace(")", "%29") ?? "";

string AesEncrypt(string jsonStr, string hashKey, string hashIv)
{
    var urlEncoded = AesUrlEncode(jsonStr);
    using var aes = Aes.Create();
    aes.Key = Encoding.UTF8.GetBytes(hashKey)[..16];
    aes.IV = Encoding.UTF8.GetBytes(hashIv)[..16];
    aes.Mode = CipherMode.CBC;
    aes.Padding = PaddingMode.PKCS7;
    using var encryptor = aes.CreateEncryptor();
    var plainBytes = Encoding.UTF8.GetBytes(urlEncoded);
    var encrypted = encryptor.TransformFinalBlock(plainBytes, 0, plainBytes.Length);
    return Convert.ToBase64String(encrypted);
}

JsonElement AesDecrypt(string cipherText, string hashKey, string hashIv)
{
    var encrypted = Convert.FromBase64String(cipherText);
    using var aes = Aes.Create();
    aes.Key = Encoding.UTF8.GetBytes(hashKey)[..16];
    aes.IV = Encoding.UTF8.GetBytes(hashIv)[..16];
    aes.Mode = CipherMode.CBC;
    aes.Padding = PaddingMode.PKCS7;
    using var decryptor = aes.CreateDecryptor();
    var decrypted = decryptor.TransformFinalBlock(encrypted, 0, encrypted.Length);
    var urlDecoded = HttpUtility.UrlDecode(Encoding.UTF8.GetString(decrypted));
    return JsonSerializer.Deserialize<JsonElement>(urlDecoded!);
}

// System.Text.Json 使用 class 屬性順序，預設即為 compact
var invoiceData = new
{
    MerchantID,
    RelateNumber = $"INV{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}",
    CustomerEmail = "test@example.com",
    Print = "0",
    Donation = "0",
    TaxType = "1",
    SalesAmount = 100,
    Items = new[] { new { ItemName = "測試商品", ItemCount = 1, ItemWord = "件", ItemPrice = 100, ItemTaxType = "1", ItemAmount = 100 } },
    InvType = "07"
};

var jsonStr = JsonSerializer.Serialize(invoiceData);
var encryptedData = AesEncrypt(jsonStr, HashKey, HashIV);

var requestBody = new
{
    MerchantID,
    RqHeader = new { Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds(), Revision = "3.0.0" },
    Data = encryptedData
};

using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
var response = await client.PostAsJsonAsync(InvoiceUrl, requestBody);
var resultJson = await response.Content.ReadAsStringAsync();
var result = JsonSerializer.Deserialize<JsonElement>(resultJson);

// 雙層錯誤檢查
var transCode = result.GetProperty("TransCode").GetInt32();
if (transCode != 1)
    throw new Exception($"外層錯誤 TransCode={transCode}: {result.GetProperty("TransMsg")}");

var data = AesDecrypt(result.GetProperty("Data").GetString()!, HashKey, HashIV);
var rtnCode = data.GetProperty("RtnCode").GetInt32();
if (rtnCode != 1)
    throw new Exception($"業務錯誤 RtnCode={rtnCode}: {data.GetProperty("RtnMsg")}");

Console.WriteLine($"發票號碼: {data.GetProperty("InvoiceNo")}");
```

**執行**：
```bash
dotnet new console -n EcpayInvoice
# 將上述程式碼放入 Program.cs
# 加入 System.Web 參考: <PackageReference Include="Microsoft.AspNetCore.SystemWebAdapters" />
dotnet run --project EcpayInvoice
```

---

## TypeScript 完整整合範例

> TypeScript 的 ECPay 整合程式碼與 Node.js 幾乎完全相同（使用相同的 `crypto`、`Buffer`、`encodeURIComponent` 模組）。
> 主要差異僅在型別標注。如果你已熟悉 Node.js 版本（見 guides/00），可直接加上型別使用。

### CMV-SHA256 — AIO 信用卡付款

> 對應 PHP 範例：`scripts/SDK_PHP/example/Payment/Aio/CreateCreditOrder.php`

```typescript
// Express + TypeScript 範例
// package.json: { "dependencies": { "express": "^4.18" }, "devDependencies": { "@types/express": "^4.17", "@types/node": "^20", "ts-node": "^10", "typescript": "^5" } }
// 執行: npx ts-node server.ts

import express from 'express';
import crypto from 'crypto';

const app = express();
app.use(express.urlencoded({ extended: true }));

const MERCHANT_ID = '3002607';
const HASH_KEY = 'pwFHCqoQZGmho4w6';
const HASH_IV = 'EkRm7iFT261dpevs';
const AIO_URL = 'https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5';

interface EcpayParams { [key: string]: string; }

// 完整實作見 guides/13-checkmacvalue.md §TypeScript
function ecpayUrlEncode(source: string): string {
  let encoded = encodeURIComponent(source).replace(/%20/g, '+').replace(/~/g, '%7e');
  encoded = encoded.toLowerCase();
  const replacements: Record<string, string> = {
    '%2d': '-', '%5f': '_', '%2e': '.', '%21': '!',
    '%2a': '*', '%28': '(', '%29': ')',
  };
  for (const [old, char] of Object.entries(replacements)) {
    encoded = encoded.split(old).join(char);
  }
  return encoded;
}

function generateCheckMacValue(params: EcpayParams): string {
  const filtered = Object.entries(params).filter(([k]) => k !== 'CheckMacValue');
  const sorted = filtered.sort(([a], [b]) => a.toLowerCase().localeCompare(b.toLowerCase()));
  const paramStr = sorted.map(([k, v]) => `${k}=${v}`).join('&');
  const raw = `HashKey=${HASH_KEY}&${paramStr}&HashIV=${HASH_IV}`;
  return crypto.createHash('sha256').update(ecpayUrlEncode(raw), 'utf8').digest('hex').toUpperCase();
}

app.get('/checkout', (req, res) => {
  const tradeNo = `TS${Math.floor(Date.now() / 1000)}`;
  const tradeDate = new Date().toLocaleString('zh-TW', {
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
  }).replace(/\//g, '/');

  const params: EcpayParams = {
    MerchantID: MERCHANT_ID,
    MerchantTradeNo: tradeNo,
    MerchantTradeDate: tradeDate,
    PaymentType: 'aio',
    TotalAmount: '100',
    TradeDesc: '測試交易',
    ItemName: '測試商品',
    ReturnURL: 'https://your-domain.com/ecpay/notify', // ⚠️ 必須替換
    ChoosePayment: 'Credit',
    EncryptType: '1',
  };
  params.CheckMacValue = generateCheckMacValue(params);

  const fields = Object.entries(params)
    .map(([k, v]) => `<input type="hidden" name="${k}" value="${v}">`)
    .join('');
  res.send(`<form id="ecpay" method="POST" action="${AIO_URL}">${fields}</form>
<script>document.getElementById('ecpay').submit();</script>`);
});

app.post('/ecpay/notify', (req, res) => {
  const params: EcpayParams = req.body;
  const received = params.CheckMacValue || '';
  const calculated = generateCheckMacValue(params);
  const rBuf = Buffer.from(received);
  const cBuf = Buffer.from(calculated);
  if (rBuf.length !== cBuf.length || !crypto.timingSafeEqual(rBuf, cBuf)) {
    return res.send('0|CheckMacValue Error');
  }
  if (params.RtnCode === '1' && params.SimulatePaid === '0') {
    console.log(`付款成功: ${params.MerchantTradeNo}`);
  }
  res.send('1|OK');
});

app.listen(3000, () => console.log('Server: http://localhost:3000/checkout'));
```

**執行**：`npx ts-node server.ts`，瀏覽 `http://localhost:3000/checkout`。

### AES-JSON — B2C 發票開立

> 對應 PHP 範例：`scripts/SDK_PHP/example/Invoice/B2C/Issue.php`

```typescript
// TypeScript AES-JSON E2E — B2C 發票開立
// package.json: { "dependencies": { "express": "^4.18" }, "devDependencies": { "@types/express": "^4.17", "@types/node": "^20", "ts-node": "^10", "typescript": "^5" } }

import crypto from 'crypto';

const CONFIG = {
  merchantId: '2000132',
  hashKey: 'ejCk326UnaZWKisg',
  hashIv: 'q9jcZX8Ib9LM8wYk',
  invoiceUrl: 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/Issue',
};

// 完整實作見 guides/14-aes-encryption.md §TypeScript
// AES 專用 URL encode — 不做 toLowerCase 和 .NET 還原（與 CMV ecpayUrlEncode 不同）
function aesUrlEncode(source: string): string {
  return encodeURIComponent(source)
    .replace(/%20/g, '+')
    .replace(/~/g, '%7e')
    .replace(/!/g, '%21')
    .replace(/'/g, '%27')
    .replace(/\(/g, '%28')
    .replace(/\)/g, '%29')
    .replace(/\*/g, '%2A');
}

function aesEncrypt(data: Record<string, unknown>, hashKey: string, hashIv: string): string {
  const jsonStr = JSON.stringify(data);
  const urlEncoded = aesUrlEncode(jsonStr);
  const key = Buffer.from(hashKey, 'utf8').subarray(0, 16);
  const iv = Buffer.from(hashIv, 'utf8').subarray(0, 16);
  const cipher = crypto.createCipheriv('aes-128-cbc', key, iv);
  let encrypted = cipher.update(urlEncoded, 'utf8');
  encrypted = Buffer.concat([encrypted, cipher.final()]);
  return encrypted.toString('base64');
}

function aesDecrypt(cipherText: string, hashKey: string, hashIv: string): Record<string, unknown> {
  const encrypted = Buffer.from(cipherText, 'base64');
  const key = Buffer.from(hashKey, 'utf8').subarray(0, 16);
  const iv = Buffer.from(hashIv, 'utf8').subarray(0, 16);
  const decipher = crypto.createDecipheriv('aes-128-cbc', key, iv);
  let decrypted = decipher.update(encrypted);
  decrypted = Buffer.concat([decrypted, decipher.final()]);
  const urlDecoded = decodeURIComponent(decrypted.toString('utf8').replace(/\+/g, '%20'));
  return JSON.parse(urlDecoded);
}

async function issueInvoice(): Promise<void> {
  const invoiceData = {
    MerchantID: CONFIG.merchantId,
    RelateNumber: `INV${Date.now()}`,
    CustomerEmail: 'test@example.com',
    Print: '0',
    Donation: '0',
    TaxType: '1',
    SalesAmount: 100,
    Items: [{ ItemName: '測試商品', ItemCount: 1, ItemWord: '件', ItemPrice: 100, ItemTaxType: '1', ItemAmount: 100 }],
    InvType: '07',
  };

  const requestBody = JSON.stringify({
    MerchantID: CONFIG.merchantId,
    RqHeader: { Timestamp: Math.floor(Date.now() / 1000), Revision: '3.0.0' },
    Data: aesEncrypt(invoiceData, CONFIG.hashKey, CONFIG.hashIv),
  });

  const response = await fetch(CONFIG.invoiceUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: requestBody,
  });
  const result = await response.json() as Record<string, unknown>;

  // 雙層錯誤檢查
  if (result.TransCode !== 1) {
    throw new Error(`外層錯誤 TransCode=${result.TransCode}: ${result.TransMsg}`);
  }
  const data = aesDecrypt(result.Data as string, CONFIG.hashKey, CONFIG.hashIv);
  if (data.RtnCode !== 1) {
    throw new Error(`業務錯誤 RtnCode=${data.RtnCode}: ${data.RtnMsg}`);
  }
  console.log('發票號碼:', data.InvoiceNo);
}

issueInvoice().catch(console.error);
```

**執行**：`npx ts-node invoice.ts`

### AES-JSON — ECPG 站內付（Token + CreatePayment）

ECPG 嵌入式金流的後端 API 呼叫範例。前端 JS SDK 整合見 [guides/02](./02-payment-ecpg.md)。

```typescript
// ecpg-backend.ts — ECPG Token 取得 + 建立交易
// 完整 AES 函式見 guides/14-aes-encryption.md §TypeScript
// npm install node-fetch（或使用 Node.js 18+ 內建 fetch）

const ECPG_CONFIG = {
  merchantId: '3002607',
  hashKey: 'pwFHCqoQZGmho4w6',
  hashIv: 'EkRm7iFT261dpevs',
  // ⚠️ ECPG 雙 domain：Token API 用 ecpg，交易/查詢用 ecpayment
  tokenUrl: 'https://ecpg-stage.ecpay.com.tw/Cashier/GetTokenbyTrade',
  createPaymentUrl: 'https://ecpayment-stage.ecpay.com.tw/1.0.0/Cashier/CreatePayment',
};

// Step 1: 取得 Token（前端 JS SDK 會呼叫此 API）
async function getToken(): Promise<string> {
  const tokenData = {
    MerchantID: ECPG_CONFIG.merchantId,
    MerchantTradeNo: 'ECPG' + Date.now(),
    MerchantTradeDate: new Date().toISOString().replace(/T/, ' ').substring(0, 19).replace(/-/g, '/'),
    TotalAmount: 100,
    TradeDesc: 'ECPG 測試',
    ItemName: '測試商品',
    ReturnURL: 'https://your-domain.com/ecpay/ecpg-notify',
  };

  const requestBody = JSON.stringify({
    MerchantID: ECPG_CONFIG.merchantId,
    RqHeader: { Timestamp: Math.floor(Date.now() / 1000) },
    Data: aesEncrypt(tokenData, ECPG_CONFIG.hashKey, ECPG_CONFIG.hashIv),
  });

  const resp = await fetch(ECPG_CONFIG.tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: requestBody,
  });
  const result = await resp.json() as Record<string, unknown>;
  if (result.TransCode !== 1) throw new Error(`TransCode=${result.TransCode}`);
  const data = aesDecrypt(result.Data as string, ECPG_CONFIG.hashKey, ECPG_CONFIG.hashIv);
  if (data.RtnCode !== 1) throw new Error(`RtnCode=${data.RtnCode}: ${data.RtnMsg}`);
  return data.Token as string; // 傳給前端 JS SDK 使用
}

// Step 2: ECPG Callback 處理（OrderResultURL）
// Express 範例：app.post('/ecpay/ecpg-notify', ecpgCallback)
function ecpgCallback(reqBody: Record<string, unknown>): string {
  if (reqBody.TransCode !== 1) {
    console.error('TransCode error:', reqBody.TransMsg);
  }
  const data = aesDecrypt(reqBody.Data as string, ECPG_CONFIG.hashKey, ECPG_CONFIG.hashIv);
  if (data.RtnCode === 1) {
    console.log('ECPG 付款成功:', data.MerchantTradeNo);
    // 更新訂單狀態
  }
  return JSON.stringify({ TransCode: 1 }); // ⚠️ ECPG 回應 JSON，非 1|OK
}
```

> **⚠️ ECPG 雙 domain 注意**：Token API（GetTokenbyTrade）使用 `ecpg-stage.ecpay.com.tw`，
> 交易/查詢 API（CreatePayment/QueryTrade）使用 `ecpayment-stage.ecpay.com.tw`。混用會得到 404。

---

## Kotlin 完整整合範例

### CMV-SHA256 — AIO 信用卡付款

> 對應 PHP 範例：`scripts/SDK_PHP/example/Payment/Aio/CreateCreditOrder.php`
>
> 純 JDK HttpServer 範例（不需外部依賴）

```kotlin
// 純 JDK HttpServer 範例（不需外部依賴）
// 執行: kotlinc -include-runtime -d ecpay.jar EcpayDemo.kt && java -jar ecpay.jar

import com.sun.net.httpserver.HttpServer
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.InetSocketAddress
import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

const val MERCHANT_ID = "3002607"
const val HASH_KEY = "pwFHCqoQZGmho4w6"
const val HASH_IV = "EkRm7iFT261dpevs"
const val AIO_URL = "https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5"

// 完整實作見 guides/13-checkmacvalue.md §Kotlin
fun ecpayUrlEncode(source: String): String {
    var encoded = URLEncoder.encode(source, StandardCharsets.UTF_8).replace("~", "%7e")
    encoded = encoded.lowercase()
    return encoded
        .replace("%2d", "-").replace("%5f", "_").replace("%2e", ".")
        .replace("%21", "!").replace("%2a", "*")
        .replace("%28", "(").replace("%29", ")")
}

fun generateCheckMacValue(params: Map<String, String>): String {
    val sorted = params.filterKeys { it != "CheckMacValue" }
        .toSortedMap(String.CASE_INSENSITIVE_ORDER)
    val paramStr = sorted.entries.joinToString("&") { "${it.key}=${it.value}" }
    val raw = "HashKey=$HASH_KEY&$paramStr&HashIV=$HASH_IV"
    val digest = MessageDigest.getInstance("SHA-256")
        .digest(ecpayUrlEncode(raw).toByteArray(StandardCharsets.UTF_8))
    return digest.joinToString("") { "%02X".format(it) }
}

fun main() {
    val server = HttpServer.create(InetSocketAddress(3000), 0)

    server.createContext("/checkout") { exchange ->
        val tradeNo = "KT${System.currentTimeMillis() / 1000}"
        val tradeDate = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm:ss"))
        val params = mutableMapOf(
            "MerchantID" to MERCHANT_ID,
            "MerchantTradeNo" to tradeNo,
            "MerchantTradeDate" to tradeDate,
            "PaymentType" to "aio",
            "TotalAmount" to "100",
            "TradeDesc" to "測試交易",
            "ItemName" to "測試商品",
            "ReturnURL" to "https://your-domain.com/ecpay/notify", // ⚠️ 必須替換
            "ChoosePayment" to "Credit",
            "EncryptType" to "1",
        )
        params["CheckMacValue"] = generateCheckMacValue(params)

        val fields = params.entries.joinToString("") {
            """<input type="hidden" name="${it.key}" value="${it.value}">"""
        }
        val html = """<form id="ecpay" method="POST" action="$AIO_URL">$fields</form>
<script>document.getElementById('ecpay').submit();</script>"""
        val bytes = html.toByteArray(StandardCharsets.UTF_8)
        exchange.responseHeaders.add("Content-Type", "text/html; charset=utf-8")
        exchange.sendResponseHeaders(200, bytes.size.toLong())
        exchange.responseBody.write(bytes)
        exchange.responseBody.close()
    }

    server.createContext("/ecpay/notify") { exchange ->
        val body = BufferedReader(InputStreamReader(exchange.requestBody, StandardCharsets.UTF_8)).readText()
        val params = body.split("&").associate {
            val (k, v) = it.split("=", limit = 2)
            URLDecoder.decode(k, "UTF-8") to URLDecoder.decode(v, "UTF-8")
        }
        val received = params["CheckMacValue"] ?: ""
        val calculated = generateCheckMacValue(params)
        val response = if (!MessageDigest.isEqual(
                received.toByteArray(StandardCharsets.UTF_8),
                calculated.toByteArray(StandardCharsets.UTF_8)
            )) {
            "0|CheckMacValue Error"
        } else {
            if (params["RtnCode"] == "1" && params["SimulatePaid"] == "0") {
                println("付款成功: ${params["MerchantTradeNo"]}")
            }
            "1|OK"
        }
        val bytes = response.toByteArray(StandardCharsets.UTF_8)
        exchange.sendResponseHeaders(200, bytes.size.toLong())
        exchange.responseBody.write(bytes)
        exchange.responseBody.close()
    }

    server.start()
    println("Server: http://localhost:3000/checkout")
}
```

**編譯與執行**：`kotlinc -include-runtime -d ecpay.jar EcpayDemo.kt && java -jar ecpay.jar`

### AES-JSON — B2C 發票開立

> 對應 PHP 範例：`scripts/SDK_PHP/example/Invoice/B2C/Issue.php`
>
> Kotlin + Gson（不需 Ktor）

```kotlin
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec
import java.net.URLEncoder
import java.net.URLDecoder
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.net.URI
import java.nio.charset.StandardCharsets
import java.util.Base64
import com.google.gson.GsonBuilder
import com.google.gson.JsonParser

val MERCHANT_ID = "2000132"
val HASH_KEY = "ejCk326UnaZWKisg"
val HASH_IV = "q9jcZX8Ib9LM8wYk"
val INVOICE_URL = "https://einvoice-stage.ecpay.com.tw/B2CInvoice/Issue"
val gson = GsonBuilder().disableHtmlEscaping().create()

// 完整實作見 guides/14-aes-encryption.md §Kotlin
// AES 專用 URL encode — 不做 toLowerCase 和 .NET 還原
fun aesUrlEncode(source: String): String =
    URLEncoder.encode(source, StandardCharsets.UTF_8)
        .replace("~", "%7e").replace("*", "%2a")
        .replace("'", "%27").replace("(", "%28").replace(")", "%29")

fun aesEncrypt(jsonStr: String, hashKey: String, hashIv: String): String {
    val urlEncoded = aesUrlEncode(jsonStr)
    val keyBytes = hashKey.toByteArray(StandardCharsets.UTF_8).copyOf(16)
    val ivBytes = hashIv.toByteArray(StandardCharsets.UTF_8).copyOf(16)
    val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
    cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(keyBytes, "AES"), IvParameterSpec(ivBytes))
    return Base64.getEncoder().encodeToString(cipher.doFinal(urlEncoded.toByteArray(StandardCharsets.UTF_8)))
}

fun aesDecrypt(cipherText: String, hashKey: String, hashIv: String): String {
    val keyBytes = hashKey.toByteArray(StandardCharsets.UTF_8).copyOf(16)
    val ivBytes = hashIv.toByteArray(StandardCharsets.UTF_8).copyOf(16)
    val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
    cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(keyBytes, "AES"), IvParameterSpec(ivBytes))
    val decrypted = cipher.doFinal(Base64.getDecoder().decode(cipherText))
    return URLDecoder.decode(String(decrypted, StandardCharsets.UTF_8), "UTF-8")
}

fun main() {
    val invoiceData = linkedMapOf<String, Any>(
        "MerchantID" to MERCHANT_ID,
        "RelateNumber" to "INV${System.currentTimeMillis()}",
        "CustomerEmail" to "test@example.com",
        "Print" to "0",
        "Donation" to "0",
        "TaxType" to "1",
        "SalesAmount" to 100,
        "Items" to listOf(linkedMapOf(
            "ItemName" to "測試商品", "ItemCount" to 1, "ItemWord" to "件",
            "ItemPrice" to 100, "ItemTaxType" to "1", "ItemAmount" to 100
        )),
        "InvType" to "07"
    )

    val dataJson = gson.toJson(invoiceData)
    val encryptedData = aesEncrypt(dataJson, HASH_KEY, HASH_IV)

    val requestBody = gson.toJson(linkedMapOf(
        "MerchantID" to MERCHANT_ID,
        "RqHeader" to linkedMapOf(
            "Timestamp" to (System.currentTimeMillis() / 1000),
            "Revision" to "3.0.0"
        ),
        "Data" to encryptedData
    ))

    val client = HttpClient.newHttpClient()
    val request = HttpRequest.newBuilder()
        .uri(URI.create(INVOICE_URL))
        .header("Content-Type", "application/json")
        .POST(HttpRequest.BodyPublishers.ofString(requestBody))
        .build()
    val response = client.send(request, HttpResponse.BodyHandlers.ofString())

    val result = JsonParser.parseString(response.body()).asJsonObject

    // 雙層錯誤檢查
    val transCode = result.get("TransCode").asInt
    if (transCode != 1) {
        throw Exception("外層錯誤 TransCode=$transCode: ${result.get("TransMsg")}")
    }
    val data = JsonParser.parseString(aesDecrypt(result.get("Data").asString, HASH_KEY, HASH_IV)).asJsonObject
    val rtnCode = data.get("RtnCode").asInt
    if (rtnCode != 1) {
        throw Exception("業務錯誤 RtnCode=$rtnCode: ${data.get("RtnMsg")}")
    }
    println("發票號碼: ${data.get("InvoiceNo").asString}")
}
```

**編譯與執行**：
```bash
# 需要 Gson: 下載 gson-2.10.1.jar 或使用 Gradle
kotlinc -include-runtime -cp gson-2.10.1.jar -d invoice.jar EcpayInvoice.kt
java -cp invoice.jar:gson-2.10.1.jar EcpayInvoiceKt
```

---

## Ruby 完整整合範例

### CMV-SHA256 — AIO 信用卡付款

> 對應 PHP 範例：`scripts/SDK_PHP/example/Payment/Aio/CreateCreditOrder.php`
>
> WEBrick 範例（Ruby 標準庫，不需額外 gem）

```ruby
# WEBrick 範例（Ruby 標準庫，不需額外 gem）
# 執行: ruby ecpay_demo.rb

require 'webrick'
require 'digest'
require 'cgi'
require 'openssl'
require 'uri'

MERCHANT_ID = '3002607'
HASH_KEY = 'pwFHCqoQZGmho4w6'
HASH_IV = 'EkRm7iFT261dpevs'
AIO_URL = 'https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5'

# 完整實作見 guides/13-checkmacvalue.md §Ruby
def ecpay_url_encode(source)
  encoded = CGI.escape(source)
  encoded = encoded.downcase
  { '%2d' => '-', '%5f' => '_', '%2e' => '.', '%21' => '!',
    '%2a' => '*', '%28' => '(', '%29' => ')' }.each { |from, to| encoded = encoded.gsub(from, to) }
  encoded.gsub('~', '%7e')
end

def generate_check_mac_value(params)
  filtered = params.reject { |k, _| k == 'CheckMacValue' }
  sorted = filtered.sort_by { |k, _| k.downcase }
  param_str = sorted.map { |k, v| "#{k}=#{v}" }.join('&')
  raw = "HashKey=#{HASH_KEY}&#{param_str}&HashIV=#{HASH_IV}"
  Digest::SHA256.hexdigest(ecpay_url_encode(raw)).upcase
end

server = WEBrick::HTTPServer.new(Port: 3000)

server.mount_proc '/checkout' do |_req, res|
  trade_no = "RB#{Time.now.to_i}"
  trade_date = Time.now.strftime('%Y/%m/%d %H:%M:%S')
  params = {
    'MerchantID' => MERCHANT_ID, 'MerchantTradeNo' => trade_no,
    'MerchantTradeDate' => trade_date, 'PaymentType' => 'aio',
    'TotalAmount' => '100', 'TradeDesc' => '測試交易', 'ItemName' => '測試商品',
    'ReturnURL' => 'https://your-domain.com/ecpay/notify', # ⚠️ 必須替換
    'ChoosePayment' => 'Credit', 'EncryptType' => '1',
  }
  params['CheckMacValue'] = generate_check_mac_value(params)
  fields = params.map { |k, v| %(<input type="hidden" name="#{k}" value="#{v}">) }.join
  res['Content-Type'] = 'text/html; charset=utf-8'
  res.body = %(<form id="ecpay" method="POST" action="#{AIO_URL}">#{fields}</form>
<script>document.getElementById('ecpay').submit();</script>)
end

server.mount_proc '/ecpay/notify' do |req, res|
  params = URI.decode_www_form(req.body).to_h
  received = params['CheckMacValue'] || ''
  calculated = generate_check_mac_value(params)
  unless OpenSSL.secure_compare(received, calculated)
    res.body = '0|CheckMacValue Error'
    next
  end
  if params['RtnCode'] == '1' && params['SimulatePaid'] == '0'
    puts "付款成功: #{params['MerchantTradeNo']}"
  end
  res.body = '1|OK'
end

trap('INT') { server.shutdown }
puts 'Server: http://localhost:3000/checkout'
server.start
```

**執行**：`ruby ecpay_demo.rb`，瀏覽 `http://localhost:3000/checkout`。

### Ruby — AES-JSON 端到端範例（B2C 發票）

```ruby
require 'openssl'
require 'base64'
require 'json'
require 'cgi'
require 'net/http'
require 'uri'

MERCHANT_ID = '2000132'
HASH_KEY = 'ejCk326UnaZWKisg'
HASH_IV  = 'q9jcZX8Ib9LM8wYk'
INVOICE_URL = 'https://einvoice-stage.ecpay.com.tw/B2CInvoice/Issue'

# 完整實作見 guides/14-aes-encryption.md §Ruby
def aes_url_encode(source)
  CGI.escape(source).gsub('~', '%7e')
      .gsub('!', '%21').gsub('*', '%2a')
      .gsub("'", '%27').gsub('(', '%28').gsub(')', '%29')
end

def aes_encrypt(data, hash_key, hash_iv)
  json_str = JSON.generate(data)
  url_encoded = aes_url_encode(json_str)
  cipher = OpenSSL::Cipher::AES128.new(:CBC)
  cipher.encrypt
  cipher.key = hash_key[0, 16]
  cipher.iv = hash_iv[0, 16]
  encrypted = cipher.update(url_encoded) + cipher.final
  Base64.strict_encode64(encrypted)
end

def aes_decrypt(cipher_text, hash_key, hash_iv)
  encrypted = Base64.strict_decode64(cipher_text)
  decipher = OpenSSL::Cipher::AES128.new(:CBC)
  decipher.decrypt
  decipher.key = hash_key[0, 16]
  decipher.iv = hash_iv[0, 16]
  decrypted = decipher.update(encrypted) + decipher.final
  JSON.parse(CGI.unescape(decrypted))
end

# B2C 發票開立
invoice_data = {
  'RelateNumber' => "Ruby#{Time.now.to_i}",
  'CustomerID' => '', 'CustomerIdentifier' => '',
  'CustomerName' => '', 'CustomerAddr' => '',
  'CustomerPhone' => '', 'CustomerEmail' => 'test@example.com',
  'Print' => '0', 'Donation' => '0', 'LoveCode' => '',
  'CarrierType' => '', 'CarrierNum' => '',
  'TaxType' => '1', 'SalesAmount' => 100,
  'InvType' => '07', 'vat' => '1',
  'Items' => [{ 'ItemName' => '測試商品', 'ItemCount' => 1,
                'ItemWord' => '個', 'ItemPrice' => 100, 'ItemAmount' => 100 }]
}

body = {
  'MerchantID' => MERCHANT_ID,
  'RqHeader' => { 'Timestamp' => Time.now.to_i, 'Revision' => '3.0.0' },
  'Data' => aes_encrypt(invoice_data, HASH_KEY, HASH_IV)
}

uri = URI(INVOICE_URL)
response = Net::HTTP.post(uri, JSON.generate(body),
                          'Content-Type' => 'application/json')
result = JSON.parse(response.body)
puts "TransCode: #{result['TransCode']}"
decrypted = aes_decrypt(result['Data'], HASH_KEY, HASH_IV)
puts "RtnCode: #{decrypted['RtnCode']}, RtnMsg: #{decrypted['RtnMsg']}"
```

---

## Swift / Rust 整合說明

### Swift — iOS/macOS 整合

Swift 主要用於 iOS/macOS App 開發。ECPay 不提供原生 iOS SDK，App 內付款需透過 WebView 載入 ECPay 付款頁面。

**建議方案（優先序）**：

| 方案 | 適用場景 | 安全性 |
|------|---------|--------|
| SFSafariViewController | iOS App 標準付款流程 | 最高（獨立 cookie 沙箱） |
| WKWebView | 需要自訂 UI 的場景 | 中等（需注意 JS injection） |
| 外部瀏覽器 (UIApplication.open) | 最簡單但體驗差 | 高 |

**ReturnURL 接收**：使用 Universal Links（iOS 9+）接收付款完成回調，在 `AppDelegate` 或 `SceneDelegate` 中處理。

**CLI 測試範例**（產生 checkout form HTML）：

```swift
// swift ecpay_checkout.swift
import Foundation
import CryptoKit

let merchantID = "3002607"
let hashKey = "pwFHCqoQZGmho4w6"
let hashIV = "EkRm7iFT261dpevs"

// 使用 guides/13-checkmacvalue.md 的 Swift 實作生成 CMV
// 產生 HTML form 輸出到 stdout，可用瀏覽器開啟
let params: [String: String] = [
    "MerchantID": merchantID,
    "MerchantTradeNo": "SW\(Int(Date().timeIntervalSince1970))",
    "MerchantTradeDate": {
        let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd HH:mm:ss"; return f.string(from: Date())
    }(),
    "PaymentType": "aio", "TotalAmount": "100", "TradeDesc": "測試",
    "ItemName": "測試商品", "ReturnURL": "https://your-domain.com/notify",
    "ChoosePayment": "Credit", "EncryptType": "1",
]
let cmv = generateCheckMacValue(params: params, hashKey: hashKey, hashIv: hashIV)
print("CheckMacValue: \(cmv)")
// 搭配 guides/13 的 generateCheckMacValue 函式使用
```

### AES-JSON — B2C 發票開立

> 對應 PHP 範例：`scripts/SDK_PHP/example/Invoice/B2C/Issue.php`

```swift
// swift ecpay_invoice.swift
// 需要在 Xcode 專案中使用，或透過 swiftc 編譯（CommonCrypto 為系統框架）
import Foundation
import CommonCrypto

let merchantID = "2000132"
let hashKey = "ejCk326UnaZWKisg"
let hashIV = "q9jcZX8Ib9LM8wYk"
let invoiceURL = "https://einvoice-stage.ecpay.com.tw/B2CInvoice/Issue"

// 完整實作見 guides/14-aes-encryption.md §Swift
// AES 專用 URL encode — 白名單 alphanumerics，確保 ~!'()* 正確編碼
func aesUrlEncode(_ source: String) -> String? {
    let allowed = CharacterSet.alphanumerics
    guard let encoded = source.addingPercentEncoding(
        withAllowedCharacters: allowed
    ) else { return nil }
    return encoded
        .replacingOccurrences(of: "%20", with: "+")
        .replacingOccurrences(of: "~", with: "%7e")
}

func aesEncrypt(data: [String: Any], hashKey: String, hashIv: String) -> String? {
    guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []),
          let jsonStr = String(data: jsonData, encoding: .utf8) else { return nil }
    guard let urlEncoded = aesUrlEncode(jsonStr) else { return nil }
    let keyBytes = Array(hashKey.utf8.prefix(16))
    let ivBytes = Array(hashIv.utf8.prefix(16))
    let plainBytes = Array(urlEncoded.utf8)
    let bufferSize = plainBytes.count + kCCBlockSizeAES128
    var ciphertext = [UInt8](repeating: 0, count: bufferSize)
    var numBytesEncrypted: size_t = 0

    let status = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
        CCOptions(kCCOptionPKCS7Padding),
        keyBytes, kCCKeySizeAES128, ivBytes,
        plainBytes, plainBytes.count,
        &ciphertext, bufferSize, &numBytesEncrypted)

    guard status == kCCSuccess else { return nil }
    return Data(ciphertext.prefix(numBytesEncrypted)).base64EncodedString()
}

func aesDecrypt(cipherText: String, hashKey: String, hashIv: String) -> [String: Any]? {
    guard let encrypted = Data(base64Encoded: cipherText) else { return nil }
    let keyBytes = Array(hashKey.utf8.prefix(16))
    let ivBytes = Array(hashIv.utf8.prefix(16))
    let bufferSize = encrypted.count + kCCBlockSizeAES128
    var plaintext = [UInt8](repeating: 0, count: bufferSize)
    var numBytesDecrypted: size_t = 0

    let status = CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES),
        CCOptions(kCCOptionPKCS7Padding),
        keyBytes, kCCKeySizeAES128, ivBytes,
        Array(encrypted), encrypted.count,
        &plaintext, bufferSize, &numBytesDecrypted)

    guard status == kCCSuccess,
          let urlEncoded = String(bytes: plaintext.prefix(numBytesDecrypted), encoding: .utf8) else { return nil }
    let urlDecoded = urlEncoded.replacingOccurrences(of: "+", with: "%20")
        .removingPercentEncoding ?? urlEncoded
    guard let data = urlDecoded.data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
}

// B2C 發票開立
let invoiceData: [String: Any] = [
    "MerchantID": merchantID,
    "RelateNumber": "SW\(Int(Date().timeIntervalSince1970))",
    "CustomerID": "", "CustomerIdentifier": "",
    "CustomerName": "", "CustomerAddr": "",
    "CustomerPhone": "", "CustomerEmail": "test@example.com",
    "Print": "0", "Donation": "0", "LoveCode": "",
    "CarrierType": "", "CarrierNum": "",
    "TaxType": "1", "SalesAmount": 100,
    "InvType": "07", "vat": "1",
    "Items": [["ItemName": "測試商品", "ItemCount": 1,
               "ItemWord": "個", "ItemPrice": 100, "ItemAmount": 100]]
]

guard let encryptedData = aesEncrypt(data: invoiceData, hashKey: hashKey, hashIv: hashIV) else {
    print("加密失敗")
    exit(1)
}

let requestBody: [String: Any] = [
    "MerchantID": merchantID,
    "RqHeader": ["Timestamp": Int(Date().timeIntervalSince1970), "Revision": "3.0.0"],
    "Data": encryptedData
]

guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody, options: []) else {
    print("JSON 序列化失敗")
    exit(1)
}

var request = URLRequest(url: URL(string: invoiceURL)!)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = bodyData
request.timeoutInterval = 30

let semaphore = DispatchSemaphore(value: 0)

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    defer { semaphore.signal() }

    if let error = error {
        print("HTTP 請求失敗: \(error.localizedDescription)")
        return
    }
    guard let data = data,
          let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        print("回應解析失敗")
        return
    }

    // ⚠️ 雙層錯誤檢查：先檢查 TransCode（傳輸層），再檢查 RtnCode（業務層）
    guard let transCode = result["TransCode"] as? Int, transCode == 1 else {
        print("外層錯誤 TransCode=\(result["TransCode"] ?? "nil"): \(result["TransMsg"] ?? "")")
        return
    }

    guard let dataStr = result["Data"] as? String,
          let decrypted = aesDecrypt(cipherText: dataStr, hashKey: hashKey, hashIv: hashIV) else {
        print("解密失敗")
        return
    }

    guard let rtnCode = decrypted["RtnCode"] as? Int, rtnCode == 1 else {
        print("業務錯誤 RtnCode=\(decrypted["RtnCode"] ?? "nil"): \(decrypted["RtnMsg"] ?? "")")
        return
    }

    print("發票號碼: \(decrypted["InvoiceNo"] ?? "")")
}
task.resume()
semaphore.wait()
```

> 完整的 AES 加密函式見 [guides/14 §Swift](./14-aes-encryption.md)。

### Rust — CLI / 後端整合

Rust 在 ECPay 整合中較少見，但可用於高效能後端。

**AES 相關 crate 依賴**（Cargo.toml）：
```toml
aes = "0.8"
cbc = "0.1"
cipher = "0.4"
```

**CLI 範例**（產生 checkout form HTML）：

```rust
// cargo run
use std::collections::BTreeMap;
use std::time::{SystemTime, UNIX_EPOCH};

fn main() {
    let timestamp = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
    let mut params = BTreeMap::new();
    params.insert("MerchantID".into(), "3002607".into());
    params.insert("MerchantTradeNo".into(), format!("RS{}", timestamp));
    params.insert("MerchantTradeDate".into(), "2026/01/01 12:00:00".into()); // 需用 chrono 格式化
    params.insert("PaymentType".into(), "aio".into());
    params.insert("TotalAmount".into(), "100".into());
    params.insert("TradeDesc".into(), "測試".into());
    params.insert("ItemName".into(), "測試商品".into());
    params.insert("ReturnURL".into(), "https://your-domain.com/notify".into());
    params.insert("ChoosePayment".into(), "Credit".into());
    params.insert("EncryptType".into(), "1".into());

    // 使用 guides/13-checkmacvalue.md 的 Rust 實作
    let cmv = generate_check_mac_value(&params, "pwFHCqoQZGmho4w6", "EkRm7iFT261dpevs", "sha256");
    params.insert("CheckMacValue".into(), cmv);

    let url = "https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5";
    let fields: String = params.iter()
        .map(|(k, v)| format!(r#"<input type="hidden" name="{}" value="{}">"#, k, v))
        .collect();
    println!(r#"<form id="ecpay" method="POST" action="{}">{}</form>"#, url, fields);
    println!(r#"<script>document.getElementById('ecpay').submit();</script>"#);
    // 將輸出存為 .html 檔案並用瀏覽器開啟
}
```

**Axum Web Server 範例**（完整 checkout + callback handler）：

```toml
# Cargo.toml
[dependencies]
axum = "0.7"
tokio = { version = "1", features = ["full"] }
sha2 = "0.10"
urlencoding = "2"
```

```rust
// 完整實作見 guides/13-checkmacvalue.md §Rust（ecpay_url_encode, generate_check_mac_value）
use axum::{routing::{get, post}, Router, Form, response::Html};
use std::collections::BTreeMap;

const HASH_KEY: &str = "pwFHCqoQZGmho4w6";
const HASH_IV: &str = "EkRm7iFT261dpevs";
const AIO_URL: &str = "https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5";

async fn checkout() -> Html<String> {
    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH).unwrap().as_secs();
    let mut params = BTreeMap::new();
    params.insert("MerchantID", "3002607");
    params.insert("PaymentType", "aio");
    params.insert("TotalAmount", "100");
    params.insert("TradeDesc", "Rust%e6%b8%ac%e8%a9%a6"); // 已 URL encode
    params.insert("ItemName", "測試商品");
    params.insert("ReturnURL", "https://your-domain.com/ecpay/notify");
    params.insert("ChoosePayment", "Credit");
    params.insert("EncryptType", "1");
    // MerchantTradeNo, MerchantTradeDate 需動態產生（此處省略 chrono 格式化）
    let cmv = generate_check_mac_value(&params, HASH_KEY, HASH_IV, "sha256");
    // 產生自動提交表單 HTML（同 CLI 版本邏輯）
    Html(format!("<form id='f' method='POST' action='{AIO_URL}'>{}<input type='hidden' name='CheckMacValue' value='{cmv}'></form><script>document.getElementById('f').submit()</script>",
        params.iter().map(|(k,v)| format!("<input type='hidden' name='{k}' value='{v}'>")).collect::<String>()))
}

async fn notify(Form(params): Form<BTreeMap<String, String>>) -> &'static str {
    // 驗證 CheckMacValue — 使用 guides/13 §Rust 的 verify_check_mac_value
    if !verify_check_mac_value(&params, HASH_KEY, HASH_IV, "sha256") {
        eprintln!("CheckMacValue 驗證失敗");
        return "0|Error";
    }
    if params.get("RtnCode").map(|s| s.as_str()) == Some("1") {
        println!("付款成功: {:?}", params.get("MerchantTradeNo"));
        // 更新訂單狀態（使用 upsert 確保冪等性）
    }
    "1|OK"
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/checkout", get(checkout))
        .route("/ecpay/notify", post(notify));
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

> 完整的 `generate_check_mac_value` 和 `verify_check_mac_value` 函式見 [guides/13 §Rust](./13-checkmacvalue.md)。

### AES-JSON — B2C 發票開立

> 對應 PHP 範例：`scripts/SDK_PHP/example/Invoice/B2C/Issue.php`

```toml
# Cargo.toml
[dependencies]
aes = "0.8"
cbc = "0.1"
cipher = "0.4"
base64 = "0.22"
serde_json = "1"
urlencoding = "2"
reqwest = { version = "0.12", features = ["blocking"] }
```

```rust
use aes::Aes128;
use cbc::{Encryptor, Decryptor};
use cbc::cipher::{BlockEncryptMut, BlockDecryptMut, KeyIvInit};
use cipher::block_padding::Pkcs7;
use base64::{Engine as _, engine::general_purpose};
use std::time::{SystemTime, UNIX_EPOCH};

const MERCHANT_ID: &str = "2000132";
const HASH_KEY: &str = "ejCk326UnaZWKisg";
const HASH_IV: &str = "q9jcZX8Ib9LM8wYk";
const INVOICE_URL: &str = "https://einvoice-stage.ecpay.com.tw/B2CInvoice/Issue";

type Aes128CbcEnc = Encryptor<Aes128>;
type Aes128CbcDec = Decryptor<Aes128>;

// 完整實作見 guides/14-aes-encryption.md §Rust
// AES 專用 URL encode — urlencoding 空格為 %20，需替換為 +
fn aes_url_encode(source: &str) -> String {
    let encoded = urlencoding::encode(source).into_owned();
    encoded
        .replace("%20", "+")
        .replace("~", "%7e")
        .replace("!", "%21")
        .replace("*", "%2a")
        .replace("'", "%27")
        .replace("(", "%28")
        .replace(")", "%29")
}

fn aes_encrypt(json_str: &str, hash_key: &str, hash_iv: &str) -> String {
    let url_encoded = aes_url_encode(json_str);
    let key = &hash_key.as_bytes()[..16];
    let iv = &hash_iv.as_bytes()[..16];
    let encryptor = Aes128CbcEnc::new_from_slices(key, iv).unwrap();
    let plaintext = url_encoded.as_bytes();
    let mut buf = vec![0u8; plaintext.len() + 16];
    buf[..plaintext.len()].copy_from_slice(plaintext);
    let encrypted = encryptor.encrypt_padded_mut::<Pkcs7>(&mut buf, plaintext.len()).unwrap();
    general_purpose::STANDARD.encode(encrypted)
}

fn aes_decrypt(cipher_text: &str, hash_key: &str, hash_iv: &str) -> String {
    let encrypted = general_purpose::STANDARD.decode(cipher_text).unwrap();
    let key = &hash_key.as_bytes()[..16];
    let iv = &hash_iv.as_bytes()[..16];
    let decryptor = Aes128CbcDec::new_from_slices(key, iv).unwrap();
    let mut buf = encrypted.clone();
    let decrypted = decryptor.decrypt_padded_mut::<Pkcs7>(&mut buf).unwrap();
    let url_encoded = String::from_utf8_lossy(decrypted).replace("+", "%20");
    urlencoding::decode(&url_encoded).unwrap().into_owned()
}

fn main() {
    let timestamp = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();

    // B2C 發票開立資料
    let invoice_data = serde_json::json!({
        "MerchantID": MERCHANT_ID,
        "RelateNumber": format!("RS{}", timestamp),
        "CustomerID": "", "CustomerIdentifier": "",
        "CustomerName": "", "CustomerAddr": "",
        "CustomerPhone": "", "CustomerEmail": "test@example.com",
        "Print": "0", "Donation": "0", "LoveCode": "",
        "CarrierType": "", "CarrierNum": "",
        "TaxType": "1", "SalesAmount": 100,
        "InvType": "07", "vat": "1",
        "Items": [{"ItemName": "測試商品", "ItemCount": 1,
                   "ItemWord": "個", "ItemPrice": 100, "ItemAmount": 100}]
    });

    let data_json = serde_json::to_string(&invoice_data).unwrap();
    let encrypted_data = aes_encrypt(&data_json, HASH_KEY, HASH_IV);

    let request_body = serde_json::json!({
        "MerchantID": MERCHANT_ID,
        "RqHeader": {
            "Timestamp": timestamp,
            "Revision": "3.0.0"
        },
        "Data": encrypted_data
    });

    let client = reqwest::blocking::Client::new();
    let response = client.post(INVOICE_URL)
        .header("Content-Type", "application/json")
        .body(serde_json::to_string(&request_body).unwrap())
        .timeout(std::time::Duration::from_secs(30))
        .send()
        .expect("HTTP 請求失敗");

    let result: serde_json::Value = response.json().expect("回應解析失敗");

    // ⚠️ 雙層錯誤檢查：先檢查 TransCode（傳輸層），再檢查 RtnCode（業務層）
    let trans_code = result["TransCode"].as_i64().unwrap_or(0);
    if trans_code != 1 {
        eprintln!("外層錯誤 TransCode={}: {}", trans_code, result["TransMsg"]);
        return;
    }

    let data_str = result["Data"].as_str().expect("Data 欄位缺失");
    let decrypted_json = aes_decrypt(data_str, HASH_KEY, HASH_IV);
    let data: serde_json::Value = serde_json::from_str(&decrypted_json).expect("解密結果解析失敗");

    let rtn_code = data["RtnCode"].as_i64().unwrap_or(0);
    if rtn_code != 1 {
        eprintln!("業務錯誤 RtnCode={}: {}", rtn_code, data["RtnMsg"]);
        return;
    }

    println!("發票號碼: {}", data["InvoiceNo"]);
}
```

**執行**：`cargo run`

> 完整的 AES 加密函式見 [guides/14 §Rust](./14-aes-encryption.md)。

---

## Mobile App 付款整合指引

ECPay 不提供原生 iOS/Android SDK（ECPG App SDK 除外），App 內付款需透過 WebView 載入 ECPay 付款頁面。

### iOS (Swift/Objective-C)

| 方案 | 推薦度 | 說明 |
|------|--------|------|
| **SFSafariViewController** | ⭐⭐⭐ 推薦 | 獨立 cookie 沙箱、系統級安全、支援自動填入 |
| WKWebView | ⭐⭐ | 可自訂 UI，但需處理 cookie 和 JS 安全問題 |
| 外部瀏覽器 | ⭐ | 最簡單但用戶體驗差（跳出 App） |

**ReturnURL 處理**：
1. 設定 Universal Links（Apple Developer Console + apple-app-site-association）
2. 在 `SceneDelegate.scene(_:continue:)` 中接收回調
3. 解析 URL 參數，更新 App 內訂單狀態

**注意**：ReturnURL 是前端頁面跳轉，**不可**作為付款成功判斷依據。必須搭配 server-side 的 callback（ReturnURL server-to-server）確認付款狀態。

### Android (Kotlin/Java)

| 方案 | 推薦度 | 說明 |
|------|--------|------|
| **Custom Tabs (Chrome)** | ⭐⭐⭐ 推薦 | 系統瀏覽器核心、最佳效能、支援自動填入 |
| WebView | ⭐⭐ | 可自訂 UI，但需處理 cookie 和安全性 |
| 外部瀏覽器 | ⭐ | 最簡單但用戶體驗差 |

**ReturnURL 處理**：
1. 在 AndroidManifest.xml 設定 Deep Link intent-filter
2. 在 Activity 的 `onNewIntent()` 中接收回調
3. 解析 Intent data，更新 App 內訂單狀態

### ECPG App SDK

如需更深度的 App 整合（例如 App 內信用卡表單），可考慮 ECPG App SDK。詳見 [guides/02-payment-ecpg.md](./02-payment-ecpg.md) 的 App 整合段落。

---

## 非 PHP 信用卡付款統一 Checklist

以下 9 步驟適用於任何語言的 AIO 信用卡付款整合，按順序完成即可：

1. **實作 `ecpayUrlEncode`** — 對照 [guides/13](./13-checkmacvalue.md) 的各語言 URL Encode 行為差異表
2. **實作 `generateCheckMacValue`** — SHA256 版本，對照 guides/13 的完整流程
3. **驗證測試向量** — 用 guides/13 的 SHA256 測試向量確認結果為 `291CBA...57FB2`
4. **建立 checkout 端點** — 組裝參數 + 生成 CMV + 輸出自動提交的 HTML form
5. **建立 notify 端點** — 接收 ECPay POST callback，解析 form 參數
6. **驗證 CMV** — 用 timing-safe 比較驗證回呼的 CheckMacValue
7. **回應 `1|OK`** — 驗證通過後**必須**回應純文字 `1|OK`（無 HTML、無 BOM）
8. **ngrok 測試** — 用 `ngrok http 3000` 產生公開 URL，設為 ReturnURL 進行端對端測試
9. **切正式環境** — 替換 MerchantID/HashKey/HashIV + URL 去掉 `-stage` → 完成

> **常見錯誤**：
> - 忘記 `EncryptType=1`（必須設為 1 表示 SHA256）
> - ReturnURL 回應了 HTML 而非純文字 `1|OK`
> - 未驗證 `SimulatePaid` 欄位（測試環境預設為模擬付款）
> - 回呼處理拋出異常導致未回應 `1|OK`（ECPay 會持續重送）

---

## C/C++ 整合注意事項

C/C++ 極少用於 Web 整合，因此不提供完整 E2E 範例。以下為必要的依賴和建置資訊。

### 編譯依賴

| 依賴 | 最低版本 | C 用途 | C++ 用途 |
|------|---------|--------|---------|
| OpenSSL | 3.0+ | AES-128-CBC, SHA256, MD5 | 同左 |
| libcurl | 8.0+ | HTTP POST | 或用 cpr 1.10+ |
| cJSON | 1.7+ | JSON 序列化 | 或用 nlohmann/json 3.11+ |

### CMake 範例

```cmake
cmake_minimum_required(VERSION 3.16)
project(ecpay_demo)

# C 版本
find_package(OpenSSL REQUIRED)
find_package(CURL REQUIRED)
find_package(cJSON REQUIRED)
add_executable(ecpay_c main.c)
target_link_libraries(ecpay_c OpenSSL::SSL OpenSSL::Crypto CURL::libcurl cjson)

# C++ 版本
include(FetchContent)
FetchContent_Declare(cpr GIT_REPOSITORY https://github.com/libcpr/cpr.git GIT_TAG 1.10.5)
FetchContent_Declare(json GIT_REPOSITORY https://github.com/nlohmann/json.git GIT_TAG v3.11.3)
FetchContent_MakeAvailable(cpr json)
add_executable(ecpay_cpp main.cpp)
target_link_libraries(ecpay_cpp cpr::cpr nlohmann_json::nlohmann_json OpenSSL::SSL OpenSSL::Crypto)
```

### 已有加密實作參考

- CheckMacValue（SHA256/MD5）：[guides/13-checkmacvalue.md](./13-checkmacvalue.md) C/C++ 區段
- AES-128-CBC：[guides/14-aes-encryption.md](./14-aes-encryption.md) C/C++ 區段

### 記憶體安全提醒

- **C**：所有 `malloc` 配對 `free`，加密後務必 `memset` 清除敏感資料緩衝區
- **C++**：優先使用 `std::unique_ptr` / `std::vector`，避免手動記憶體管理
- **密鑰保護**：HashKey/HashIV 不要以全域字串常數存放，使用環境變數或安全儲存

---

## 跨語言測試驗證

完整測試向量（SHA256 / MD5 / 含特殊字元）及 12 語言驗證範例見 [guides/13-checkmacvalue.md §測試向量](./13-checkmacvalue.md)。

建議以 guides/13 提供的測試向量驗證你的語言實作，確認 CheckMacValue 與預期值一致後再進入整合測試。

---

## Production 環境切換 Checklist

完整上線檢查清單見 [guides/16-go-live-checklist.md](./16-go-live-checklist.md)。

> **關鍵原則**：所有語言均應從環境變數讀取 MerchantID / HashKey / HashIV，禁止寫死在程式碼中。
> 環境 URL 對照表見 [SKILL.md §快速參考](../SKILL.md)。

## 相關文件

- [guides/00-getting-started.md](./00-getting-started.md) — 入門：PHP/Node.js/Python Quick Start
- [guides/13-checkmacvalue.md](./13-checkmacvalue.md) — CheckMacValue 12 語言實作
- [guides/14-aes-encryption.md](./14-aes-encryption.md) — AES 加解密 12 語言實作
- [guides/20-http-protocol-reference.md](./20-http-protocol-reference.md) — HTTP 協議參考
- [guides/16-go-live-checklist.md](./16-go-live-checklist.md) — 上線檢查清單
