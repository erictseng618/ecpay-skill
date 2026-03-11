# Ruby — ECPay 整合程式規範

> 本檔為 AI 生成 ECPay 整合程式碼時的 Ruby 專屬規範。
> 加密函式：[guides/13 §Ruby](../13-checkmacvalue.md) + [guides/14 §Ruby](../14-aes-encryption.md)
> E2E 範例：[guides/24 §Ruby](../24-multi-language-integration.md)

## 版本與環境

- **最低版本**：Ruby 3.1+
- **推薦版本**：Ruby 3.2+
- **套件管理**：Bundler（Gemfile）
- **加密**：`openssl` 標準庫（內建，無需額外 gem）

## 推薦依賴

```ruby
# Gemfile
gem 'sinatra', '~> 3.0'   # 輕量 HTTP（或 rails）
gem 'dotenv', '~> 3.0'    # 環境變數載入
gem 'net-http'             # Ruby 3.1+ 獨立 gem

# 不需要額外加密 gem — openssl 已內建
```

## 命名慣例

```ruby
# 方法 / 變數：snake_case
def generate_check_mac_value(params, hash_key, hash_iv)
  # ...
end
merchant_trade_no = "ORDER#{Time.now.to_i}"

# 類別 / 模組：PascalCase
class EcpayPaymentClient
end

module Ecpay
end

# 常數：UPPER_SNAKE_CASE
ECPAY_PAYMENT_URL = 'https://payment.ecpay.com.tw/Cashier/AioCheckOut/V5'

# 檔案：snake_case.rb
# ecpay_payment.rb, ecpay_aes.rb, ecpay_callback.rb

# ⚠️ ECPay API 參數名為 PascalCase 字串 key（"MerchantID"），不可轉為 Symbol
```

## 型別定義（Struct / Data）

```ruby
# Ruby 3.2+ Data（immutable value object）
EcpayConfig = Data.define(:merchant_id, :hash_key, :hash_iv, :base_url)

# 或使用 Struct
AioParams = Struct.new(
  :merchant_id,
  :merchant_trade_no,
  :merchant_trade_date,
  :total_amount,        # ⚠️ 整數字串
  :trade_desc,
  :item_name,
  :return_url,
  :choose_payment,
  keyword_init: true,
) do
  def to_param_hash
    {
      'MerchantID'        => merchant_id,
      'MerchantTradeNo'   => merchant_trade_no,
      'MerchantTradeDate' => merchant_trade_date,
      'PaymentType'       => 'aio',
      'TotalAmount'       => total_amount,
      'TradeDesc'         => trade_desc,
      'ItemName'          => item_name,
      'ReturnURL'         => return_url,
      'ChoosePayment'     => choose_payment || 'ALL',
      'EncryptType'       => '1',
    }
  end
end

# ⚠️ RtnCode 為字串
# params['RtnCode'] == '1'  ← 正確
# params['RtnCode'] == 1    ← 錯誤
```

## 錯誤處理

```ruby
class EcpayApiError < StandardError
  attr_reader :trans_code, :rtn_code

  def initialize(trans_code, rtn_code, message)
    @trans_code = trans_code
    @rtn_code = rtn_code
    super("TransCode=#{trans_code}, RtnCode=#{rtn_code}: #{message}")
  end
end

def call_aes_api(url, request_body, hash_key, hash_iv)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 10
  http.read_timeout = 30

  req = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
  req.body = request_body.to_json

  resp = http.request(req)

  raise EcpayApiError.new(-1, nil, 'Rate Limited — 需等待約 30 分鐘') if resp.code == '403'
  raise EcpayApiError.new(-1, nil, "HTTP #{resp.code}") unless resp.is_a?(Net::HTTPSuccess)

  result = JSON.parse(resp.body)

  # 雙層錯誤檢查
  if result['TransCode'] != 1
    raise EcpayApiError.new(result['TransCode'], nil, result['TransMsg'])
  end

  data = aes_decrypt(result['Data'], hash_key, hash_iv)
  if data['RtnCode'].to_s != '1'
    raise EcpayApiError.new(1, data['RtnCode'], data['RtnMsg'])
  end

  data
end
```

## Callback Handler 模板（Sinatra）

```ruby
require 'sinatra'
require 'rack/utils'

post '/ecpay/callback' do
  params_hash = params.to_h

  # 1. Timing-safe CMV 驗證
  received_cmv = params_hash.delete('CheckMacValue')
  expected_cmv = generate_check_mac_value(params_hash, HASH_KEY, HASH_IV)
  unless Rack::Utils.secure_compare(received_cmv, expected_cmv)
    halt 400, 'CheckMacValue Error'
  end

  # 2. RtnCode 是字串
  if params_hash['RtnCode'] == '1'
    # 處理成功
  end

  # 3. HTTP 200 + "1|OK"
  content_type 'text/plain'
  '1|OK'
end
```

## Callback Handler 模板（Rails）

```ruby
class EcpayCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    p = params.to_unsafe_h.except('controller', 'action')

    received_cmv = p.delete('CheckMacValue')
    expected_cmv = generate_check_mac_value(p, ENV['ECPAY_HASH_KEY'], ENV['ECPAY_HASH_IV'])
    unless Rack::Utils.secure_compare(received_cmv.to_s, expected_cmv)
      return head :bad_request
    end

    if p['RtnCode'] == '1'
      # 處理成功
    end

    render plain: '1|OK'
  end
end
```

## 環境變數

```ruby
# .env（搭配 dotenv gem）
# ECPAY_MERCHANT_ID=3002607
# ECPAY_HASH_KEY=pwFHCqoQZGmho4w6
# ECPAY_HASH_IV=EkRm7iFT261dpevs
# ECPAY_ENV=stage

require 'dotenv/load'

config = EcpayConfig.new(
  merchant_id: ENV.fetch('ECPAY_MERCHANT_ID'),
  hash_key:    ENV.fetch('ECPAY_HASH_KEY'),
  hash_iv:     ENV.fetch('ECPAY_HASH_IV'),
  base_url:    ENV['ECPAY_ENV'] == 'stage'
    ? 'https://payment-stage.ecpay.com.tw'
    : 'https://payment.ecpay.com.tw',
)
```

## JSON 序列化注意

```ruby
require 'json'

# Ruby 預設：JSON.generate 不轉義 Unicode（等同 Python ensure_ascii=False）
# ⚠️ 正確：使用 String key（非 Symbol）
hash = { 'MerchantID' => '2000132', 'ItemName' => '測試商品' }
json_str = JSON.generate(hash)  # → {"MerchantID":"2000132","ItemName":"測試商品"}

# ⚠️ 錯誤：Symbol key 會導致 key 多一個冒號
hash = { MerchantID: '2000132' }
JSON.generate(hash)  # → {"MerchantID":"2000132"} — 新版 Ruby OK，但建議用 String key
```

## 單元測試模式

```ruby
# test/ecpay_test.rb — Minitest
require 'minitest/autorun'

class EcpayTest < Minitest::Test
  def test_cmv_sha256
    params = {
      'MerchantID' => '3002607',
      # ... test vector params ...
    }
    result = generate_check_mac_value(params, 'pwFHCqoQZGmho4w6', 'EkRm7iFT261dpevs')
    assert_equal '291CBA324D31FB5A4BBBFDF2CFE5D32598524753AFD4959C3BF590C5B2F57FB2', result
  end

  def test_aes_roundtrip
    data = { 'MerchantID' => '2000132', 'BarCode' => '/1234567' }
    encrypted = aes_encrypt(data, 'ejCk326UnaZWKisg', 'q9jcZX8Ib9LM8wYk')
    decrypted = aes_decrypt(encrypted, 'ejCk326UnaZWKisg', 'q9jcZX8Ib9LM8wYk')
    assert_equal '2000132', decrypted['MerchantID']
  end
end
```

## Linter / Formatter

```bash
gem install rubocop
# .rubocop.yml
# AllCops:
#   NewCops: enable
#   TargetRubyVersion: 3.2
#
# Metrics/MethodLength:
#   Max: 30
rubocop --autocorrect
```
