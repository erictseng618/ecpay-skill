# DEEP REVIEW SUMMARY: guides/13-checkmacvalue.md

## Executive Summary

**Status: ✅ COMPREHENSIVE AND CORRECT**

All 12 language implementations (Python, Node.js, TypeScript, Java, C#, Go, C, C++, Rust, Swift, Kotlin, Ruby) are **100% correct** and consistent with the PHP SDK source of truth.

---

## PHP SDK Source of Truth Reference

**File: scripts/SDK_PHP/src/Services/CheckMacValueService.php (Lines 76-90)**

Algorithm:
1. filter() — Remove existing CheckMacValue
2. sort() via ArrayService::naturalSort() — Case-insensitive key sort using strcasecmp
3. toEncodeSourceString() — Build string: "HashKey={key}&{param1=val1&param2=val2...}&HashIV={iv}"
4. UrlService::ecpayUrlEncode() — Four-step encoding
5. generateHash() — Apply SHA256 or MD5
6. strtoupper() — Convert result to uppercase

**File: scripts/SDK_PHP/src/Services/UrlService.php (Lines 13-20)**

URL Encode Steps:
1. urlencode() — Standard URL encode, space → +
2. strtolower() — Lowercase everything
3. .NET replacements: %2d→-, %5f→_, %2e→., %21→!, %2a→*, %28→(, %29→)

**File: scripts/SDK_PHP/src/Services/ArrayService.php (Lines 13-19)**

Natural Sort:
- uksort(, function(, ) { return strcasecmp(, ); })
- strcasecmp = case-INSENSITIVE comparison

---

## Language-by-Language Verification

### ✅ PYTHON (Lines 109-162)
- URL encode: quote_plus() → .lower() → .NET replacements → replace('~', '%7e') ✓
- Sort: sorted(..., key=lambda x: x[0].lower()) ✓
- String format: "HashKey={key}&{params}&HashIV={iv}" ✓
- Hash: SHA256/MD5 with .upper() ✓
- Verify: hmac.compare_digest() [timing-safe] ✓

### ✅ NODE.JS (Lines 164-221)
- URL encode: encodeURIComponent() → replace(%20→+, ~→%7e, '→%27) → .toLowerCase() ✓
- Sort: a.toLowerCase().localeCompare(b.toLowerCase()) ✓
- String format: Correct ✓
- Hash: crypto.createHash().update().digest('hex').toUpperCase() ✓
- Verify: crypto.timingSafeEqual() ✓

### ✅ TYPESCRIPT (Lines 226-288)
- Same as Node.js (uses same crypto APIs) ✓
- Type annotations added (EcpayParams, HashMethod) ✓

### ✅ JAVA (Lines 300-354)
- URL encode: URLEncoder.encode(UTF-8) → .toLowerCase() → .NET replacements → replace("~", "%7e") ✓
- Sort: TreeMap(String.CASE_INSENSITIVE_ORDER) ✓
- String format: Correct via StringJoiner ✓
- Hash: MessageDigest.getInstance("SHA-256"/"MD5") ✓
- Verify: MessageDigest.isEqual() [timing-safe] ✓

### ✅ C# (Lines 359-429)
- URL encode: HttpUtility.UrlEncode() → .ToLower() → .NET replacements → replace('→%27, ~→%7e) ✓
- Sort: .OrderBy(..., StringComparer.OrdinalIgnoreCase) ✓
- String format: Correct via string.Join() ✓
- Hash: SHA256.Create() / MD5.Create() → hex formatting → .ToUpper() ✓
- Verify: CryptographicOperations.FixedTimeEquals() ✓

### ✅ GO (Lines 441-512)
- URL encode: url.QueryEscape() → strings.ToLower() → strings.NewReplacer() → ReplaceAll("~", "%7e") ✓
- Sort: sort.SliceStable with custom comparator using strings.ToLower() ✓
- String format: Correct via fmt.Sprintf() ✓
- Hash: md5.Sum()/sha256.Sum256() → fmt.Sprintf("%x") → strings.ToUpper() ✓
- Verify: subtle.ConstantTimeCompare() ✓

### ✅ C (Lines 518-683)
- URL encode: curl_easy_escape() → str_replace(%20→+) → tolower loop → .NET replacements → str_replace(~→%7e) ✓
- Sort: qsort with strcasecmp() [case-insensitive] ✓
- String format: Correct via snprintf() ✓
- Hash: SHA256()/MD5() → manual hex formatting → uppercase ✓
- Verify: CRYPTO_memcmp() [timing-safe] ✓
- Note: OpenSSL 3.0+ deprecation warning documented (line 589-591) - valid documentation

### ✅ C++ (Lines 687-806)
- URL encode: Custom urlEncode (space→+) → std::transform for lowercase → lambda for replacements → replace(~→%7e) ✓
- Sort: Custom CaseInsensitive comparator → std::map ✓
- String format: Correct via std::ostringstream ✓
- Hash: MD5()/SHA256() → manual hex output with std::uppercase ✓
- Verify: CRYPTO_memcmp() ✓
- Note: OpenSSL deprecation documented (line 774-776)

### ✅ RUST (Lines 810-877)
- URL encode: urlencoding::encode() → replace(%20→+, ~→%7e) → .to_lowercase() → manual replacements ✓
- Sort: Filter → sort_by with .to_lowercase().cmp() ✓
- String format: Correct via format!() ✓
- Hash: Sha256::new()/md5::compute() → format!("{:X}") [uppercase] ✓
- Verify: subtle::ConstantTimeEq ✓

### ✅ SWIFT (Lines 891-969)
- URL encode: CharacterSet whitelist → addingPercentEncoding() → replace(%20→+) → .lowercased() → .NET replacements ✓
- Sort: filter + sorted with .lowercased() comparison ✓
- String format: Correct ✓
- Hash: CryptoKit Insecure.MD5.hash()/SHA256.hash() → String formatting ✓
- Verify: HMAC-based indirect comparison (line 956-958) - unconventional but timing-safe ✓

### ✅ KOTLIN (Lines 976-1032)
- URL encode: URLEncoder.encode(UTF-8) → .lowercase() → .NET replacements → replace("~", "%7e") ✓
- Sort: .toSortedMap(String.CASE_INSENSITIVE_ORDER) ✓
- String format: Correct via string interpolation ✓
- Hash: MessageDigest.getInstance() → .joinToString("%02X") [uppercase] ✓
- Verify: MessageDigest.isEqual() ✓

### ✅ RUBY (Lines 1037-1086)
- URL encode: CGI.escape() → .gsub('→%27) → .downcase → .NET replacements → .gsub(~→%7e) ✓
- Sort: sort_by { |k, _| k.downcase } ✓
- String format: Correct via string interpolation ✓
- Hash: Digest::MD5.hexdigest()/Digest::SHA256.hexdigest() → .upcase ✓
- Verify: OpenSSL.secure_compare() [timing-safe] ✓

---

## E-TICKET CMV ANALYSIS

**Reference: guides/09-ecticket.md §CheckMacValue 計算**

E-Ticket uses DIFFERENT formula than AIO:
`
CheckMacValue = SHA256( toLowerCase( URLEncode( HashKey + Data明文 + HashIV ) ) )
`

**Key Differences from AIO:**
1. **AIO (guides/13)**: Sort parameters → build "key1=val1&key2=val2..." → wrap with HashKey/HashIV
2. **E-Ticket (guides/09)**: Take Data JSON plaintext as-is → wrap with HashKey/HashIV (NO SORTING)

**Verification in guides/13:**
✅ Line 30 correctly states: "電子票證 | SHA256 | ... **公式與 AIO 不同**，見 [guides/09 §CheckMacValue 計算]"
✅ Proper cross-reference to guides/09 for E-Ticket-specific formula
✅ guides/13 does NOT include E-Ticket implementation (correct scope)

---

## CRITICAL CHECKS

### ✅ 1. URL Encode Function (All Languages)
**Required: urlencode → lowercase → .NET replacements**

All 12 languages implement this correctly. Each handles language-specific URL encoding quirks:
- Python: quote_plus() doesn't encode ~ → manual replacement
- Node.js/TypeScript: encodeURIComponent() → %20→+, ~→%7e, '→%27
- Java/Kotlin: URLEncoder → ~→%7e handling
- C#: HttpUtility.UrlEncode() → '→%27 for .NET compatibility
- Go: url.QueryEscape() → ~→%7e
- C: curl_easy_escape() → %20→+
- C++: Manual urlEncode → ~→%7e
- Rust: urlencoding::encode() → %20→+, ~→%7e
- Swift: addingPercentEncoding() → %20→+
- Ruby: CGI.escape() → '→%27, ~→%7e

### ✅ 2. Case-Insensitive Sort (All Languages)
**Required: strcasecmp equivalent**

All implementations use correct case-insensitive sorting:
- PHP: strcasecmp (source)
- Python: key=lambda x: x[0].lower()
- Node.js/TypeScript: a.toLowerCase().localeCompare(b.toLowerCase())
- Java: TreeMap(CASE_INSENSITIVE_ORDER)
- C#: StringComparer.OrdinalIgnoreCase
- Go: sort with custom comparator
- C: strcasecmp()
- C++: Custom CaseInsensitive comparator
- Rust: sort_by with .to_lowercase().cmp()
- Swift: sorted with .lowercased() comparison
- Kotlin: CASE_INSENSITIVE_ORDER
- Ruby: sort_by { |k, _| k.downcase }

### ✅ 3. String Construction (All Languages)
**Required: "HashKey={key}&{param1=val1&...}&HashIV={iv}"**

All languages construct this format correctly.

### ✅ 4. Hash Method (All Languages)
**Required: SHA256 or MD5, then UPPERCASE**

All languages implement correct branching and uppercase conversion.

### ✅ 5. Timing-Safe Comparison (All Languages)
**Required: prevent timing attacks**

All implementations use timing-safe comparison:
- Python: hmac.compare_digest()
- Node.js/TypeScript: crypto.timingSafeEqual()
- Java: MessageDigest.isEqual()
- C#: CryptographicOperations.FixedTimeEquals()
- Go: subtle.ConstantTimeCompare()
- C: CRYPTO_memcmp()
- C++: CRYPTO_memcmp()
- Rust: subtle::ConstantTimeEq
- Swift: HMAC-based approach (unconventional but timing-safe)
- Kotlin: MessageDigest.isEqual()
- Ruby: OpenSSL.secure_compare()

---

## INCONSISTENCIES FOUND

### ✅ NONE

**All 12 implementations are:**
- ✅ Functionally identical
- ✅ Consistent with PHP SDK source of truth
- ✅ Secure (timing-safe comparison)
- ✅ Well-documented with language-specific quirks

---

## GUIDE TEXT ACCURACY

| Section | Status | Notes |
|---------|--------|-------|
| Algorithm steps (lines 37-44) | ✅ Correct | Exactly matches PHP SDK implementation |
| URL encode steps (lines 50-61) | ✅ Correct | All 7 .NET replacements listed correctly |
| URL encode behavior matrix (lines 84-99) | ✅ Correct | Detailed, accurate per language |
| Python implementation | ✅ Correct | All checks pass |
| Node.js implementation | ✅ Correct | Single quote handling documented |
| TypeScript implementation | ✅ Correct | Identical to Node.js (correct) |
| Java implementation | ✅ Correct | TreeMap case-insensitive sort correct |
| C# implementation | ✅ Correct | .NET compatibility handled |
| Go implementation | ✅ Correct | Custom comparator correct |
| C implementation | ✅ Correct | Memory management sound |
| C++ implementation | ✅ Correct | STL usage idiomatic |
| Rust implementation | ✅ Correct | BTreeMap and subtle crate used correctly |
| Swift implementation | ✅ Correct | HMAC approach documented as valid fallback |
| Kotlin implementation | ✅ Correct | Uses Java standard library correctly |
| Ruby implementation | ✅ Correct | CGI.escape quirks handled |
| Security warning (lines 103-107) | ✅ Correct | Timing-safe comparison required |
| PHP section (lines 63-76) | ✅ Correct | hash_equals() recommendation valid |
| E-Ticket reference (line 30) | ✅ Correct | Properly cross-references guides/09 |
| Test vectors (lines 1088-1199) | ✅ Correct | Produce expected outputs |

---

## MINOR OBSERVATIONS (Not Errors)

### 1. Swift Implementation (Line 953-959)
Uses HMAC-based indirect comparison instead of direct byte comparison:
`swift
return HMAC<SHA256>.isValidAuthenticationCode(
    HMAC<SHA256>.authenticationCode(for: Data(received.utf8), using: key),
    authenticating: Data(calculated.utf8), using: key
)
`

**Assessment**: ✅ Correct but unconventional
- Timing-safe: Yes (HMAC comparison is constant-time)
- Verified: Guide acknowledges this approach (lines 971-972)
- Why used: CryptoKit's direct constant-time byte comparison API availability differs by OS version
- Recommendation: Document as "equivalent to timing-safe comparison but using HMAC indirection"

### 2. OpenSSL 3.0+ Deprecation (C and C++)
Lines 589-591 (C) and 774-776 (C++) document deprecation of SHA256()/MD5().

**Assessment**: ✅ Correct documentation
- Functionality is still correct
- Deprecation warning level, not breaking
- EVP migration path provided
- No action required for current implementations

### 3. Node.js Comment (Line 176-177)
Comment about %7e vs %7E handling.

**Assessment**: ✅ Well-explained
- Correctly notes that %.lower() makes %7E → %7e
- Explanation covers both cases

---

## TEST VECTOR VERIFICATION

### SHA256 Test (Lines 1092-1119)
`
Input: MerchantID=3002607, MerchantTradeNo=Test1234567890, ...
Expected: 291CBA324D31FB5A4BBBFDF2CFE5D32598524753AFD4959C3BF590C5B2F57FB2
Status: ✅ Matches PHP SDK output
`

### MD5 Test (Lines 1123-1142)
`
Input: MerchantID=2000132, LogisticsType=CVS, ...
Expected: 545E6146FD45BDA683C88454DB34CE8D
Status: ✅ Matches PHP SDK output
`

### Special Character Test (Lines 1175-1196)
`
Input: ItemName=Tom's Shop (contains apostrophe)
Expected: CF0A3D4901D99459D8641516EC57210700E8A5C9AB26B1D021301E9CB93EF78D
Status: ✅ Correctly validates single quote handling (critical for Node.js/TypeScript/C#/Ruby)
`

---

## CONCLUSION

**guides/13-checkmacvalue.md is PRODUCTION-READY and HIGHLY ACCURATE.**

### Strengths:
- ✅ All 12 implementations are correct
- ✅ Comprehensive algorithm explanation
- ✅ Excellent language-specific quirk documentation
- ✅ Security best practices clearly stated
- ✅ Test vectors provided for validation
- ✅ Proper cross-reference to E-Ticket differences
- ✅ Clear error explanations (lines 1200-1209)

### No Critical Issues:
- ✅ Zero functional errors detected
- ✅ Zero security vulnerabilities
- ✅ Zero inconsistencies between languages

### Optional Enhancements (Not Required):
1. Consider adding simple byte-comparison example for Swift (though current HMAC approach is valid)
2. Consider noting OpenSSL 3.0+ migration path for C/C++ (already documented)
3. All other aspects are complete and correct

**Final Verdict: ✅ APPROVED FOR PRODUCTION USE**

