# C# — ECPay 整合程式規範

> 本檔為 AI 生成 ECPay 整合程式碼時的 C# 專屬規範。
> 加密函式：[guides/13 §C#](../13-checkmacvalue.md) + [guides/14 §C#](../14-aes-encryption.md)
> E2E 範例：[guides/24 §C#](../24-multi-language-integration.md)

## 版本與環境

- **最低版本**：.NET 6+（C# 10）
- **推薦版本**：.NET 8 LTS+（C# 12，global using）
- **加密**：`System.Security.Cryptography` 內建，無需 NuGet 套件
- **JSON**：`System.Text.Json`（內建）或 `Newtonsoft.Json`

## 命名慣例

```csharp
// 類別 / 方法 / 屬性：PascalCase
public class EcpayPaymentService { }
public string GenerateCheckMacValue(Dictionary<string, string> param, string hashKey, string hashIv) { }

// 區域變數 / 參數：camelCase
string merchantTradeNo = $"ORDER{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";

// 常數：PascalCase（C# 慣例）
public const string EcpayPaymentUrl = "https://payment.ecpay.com.tw/Cashier/AioCheckOut/V5";

// 私有欄位：_camelCase
private readonly string _hashKey;

// 介面：IPascalCase
public interface IEcpayService { }

// 命名空間：PascalCase（反向域名）
namespace MyApp.Ecpay;

// 檔案名：PascalCase.cs
// EcpayPaymentService.cs, EcpayAesHelper.cs
```

## 型別定義

```csharp
// ⚠️ ECPay API 參數名為 PascalCase，恰好與 C# 慣例一致

public record AioParams
{
    public string MerchantID { get; init; } = "";
    public string MerchantTradeNo { get; init; } = "";
    public string MerchantTradeDate { get; init; } = ""; // yyyy/MM/dd HH:mm:ss
    public string PaymentType { get; init; } = "aio";
    public string TotalAmount { get; init; } = "";       // ⚠️ 整數字串
    public string TradeDesc { get; init; } = "";
    public string ItemName { get; init; } = "";
    public string ReturnURL { get; init; } = "";
    public string ChoosePayment { get; init; } = "ALL";
    public string EncryptType { get; init; } = "1";
    public string? CheckMacValue { get; set; }
}

public record AesRequest(string MerchantID, RqHeader RqHeader, string Data);
public record RqHeader(long Timestamp, string? Revision = "3.0.0");

public record AesResponse(int TransCode, string TransMsg, string Data);

// ⚠️ RtnCode 為 string
public record CallbackParams
{
    public string RtnCode { get; init; } = "";   // "1" 非 int
    public string MerchantTradeNo { get; init; } = "";
    public string CheckMacValue { get; init; } = "";
}
```

## 錯誤處理

```csharp
public class EcpayApiException : Exception
{
    public int TransCode { get; }
    public string? RtnCode { get; }

    public EcpayApiException(int transCode, string? rtnCode, string message)
        : base($"TransCode={transCode}, RtnCode={rtnCode}: {message}")
    {
        TransCode = transCode;
        RtnCode = rtnCode;
    }
}

public async Task<JsonDocument> CallAesApiAsync(
    string url, AesRequest request, string hashKey, string hashIv)
{
    using var content = new StringContent(
        JsonSerializer.Serialize(request), Encoding.UTF8, "application/json");

    using var resp = await _httpClient.PostAsync(url, content);

    if (resp.StatusCode == System.Net.HttpStatusCode.Forbidden)
        throw new EcpayApiException(-1, null, "Rate Limited — 需等待約 30 分鐘");

    resp.EnsureSuccessStatusCode();
    var body = await resp.Content.ReadAsStringAsync();
    var result = JsonSerializer.Deserialize<AesResponse>(body)!;

    // 雙層錯誤檢查
    if (result.TransCode != 1)
        throw new EcpayApiException(result.TransCode, null, result.TransMsg);

    var data = AesDecrypt(result.Data, hashKey, hashIv);
    var rtnCode = data.RootElement.GetProperty("RtnCode").ToString();
    if (rtnCode != "1")
        throw new EcpayApiException(1, rtnCode,
            data.RootElement.GetProperty("RtnMsg").GetString() ?? "");

    return data;
}
```

## HTTP Client 配置

```csharp
// ⚠️ 使用 IHttpClientFactory（ASP.NET Core），勿手動 new HttpClient
// Program.cs:
builder.Services.AddHttpClient("ecpay", client =>
{
    client.Timeout = TimeSpan.FromSeconds(30);
    client.DefaultRequestHeaders.Add("User-Agent", "ECPay-Integration/1.0");
});
```

## Callback Handler 模板（ASP.NET Core Minimal API）

```csharp
app.MapPost("/ecpay/callback", async (HttpContext ctx) =>
{
    var form = await ctx.Request.ReadFormAsync();
    var param = form.ToDictionary(x => x.Key, x => x.Value.ToString());

    // 1. Timing-safe CMV 驗證
    var receivedCmv = param["CheckMacValue"];
    param.Remove("CheckMacValue");
    var expectedCmv = GenerateCheckMacValue(param, hashKey, hashIv);

    if (!CryptographicOperations.FixedTimeEquals(
        Encoding.UTF8.GetBytes(receivedCmv),
        Encoding.UTF8.GetBytes(expectedCmv)))
    {
        return Results.BadRequest("CheckMacValue Error");
    }

    // 2. RtnCode 是字串
    if (param["RtnCode"] == "1")
    {
        // 處理成功
    }

    // 3. HTTP 200 + "1|OK"
    return Results.Text("1|OK", "text/plain");
});
```

## 環境變數

```csharp
// appsettings.json + 環境變數覆蓋
// {
//   "Ecpay": {
//     "MerchantID": "",
//     "HashKey": "",
//     "HashIV": "",
//     "Env": "stage"
//   }
// }

var config = builder.Configuration.GetSection("Ecpay");
var baseUrl = config["Env"] == "stage"
    ? "https://payment-stage.ecpay.com.tw"
    : "https://payment.ecpay.com.tw";

// 環境變數覆蓋（優先）：
// export Ecpay__MerchantID=3002607
// export Ecpay__HashKey=pwFHCqoQZGmho4w6
```

## URL Encode 注意

```csharp
// ⚠️ C# 的 Uri.EscapeDataString 等同 RFC 3986（與 PHP urlencode 不同）
// 主要差異：空格編碼為 %20 而非 +
// guides/13 的 ecpayUrlEncode 已處理此轉換（%20 → +）
// 請直接使用 guides/13 提供的函式，勿自行實作
```

## 單元測試模式

```csharp
using Xunit;

public class EcpayTests
{
    [Fact]
    public void CmvSha256_MatchesTestVector()
    {
        var param = new Dictionary<string, string>
        {
            ["MerchantID"] = "3002607",
            // ... test vector params ...
        };
        var result = GenerateCheckMacValue(param, "pwFHCqoQZGmho4w6", "EkRm7iFT261dpevs");
        Assert.Equal("291CBA324D31FB5A4BBBFDF2CFE5D32598524753AFD4959C3BF590C5B2F57FB2", result);
    }

    [Fact]
    public void AesRoundtrip_Works()
    {
        var data = new { MerchantID = "2000132", BarCode = "/1234567" };
        var encrypted = AesEncrypt(JsonSerializer.Serialize(data), "ejCk326UnaZWKisg", "q9jcZX8Ib9LM8wYk");
        var decrypted = AesDecrypt(encrypted, "ejCk326UnaZWKisg", "q9jcZX8Ib9LM8wYk");
        Assert.Contains("2000132", decrypted);
    }
}
```

## Linter / Formatter

```bash
# .NET 內建格式化
dotnet format
# EditorConfig 設定推薦：.editorconfig
# dotnet_style_qualification_for_field = false
# dotnet_naming_rule.constant_fields_should_be_pascal_case
```
