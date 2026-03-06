#!/bin/bash
# validate-ai-index.sh — 驗證 AI Section Index 行號是否準確
# 用法: bash scripts/validate-ai-index.sh

TMPFILE=$(mktemp)
: > "$TMPFILE"

check_line() {
  local file="$1" label="$2" expected_line="$3"
  actual=$(sed -n "${expected_line}p" "$file")
  if ! echo "$actual" | grep -q "^#"; then
    echo "FAIL: $file line $expected_line ($label)"
    echo "  Expected: heading (^#)"
    echo "  Actual:   $actual"
    echo "1" >> "$TMPFILE"
  fi
}

echo "Validating AI Section Index..."

for file in guides/13-checkmacvalue.md guides/14-aes-encryption.md guides/24-multi-language-integration.md; do
  if [ ! -f "$file" ]; then
    echo "SKIP: $file not found"
    continue
  fi

  echo "  Checking $file..."

  # 提取 AI Section Index 區塊（HTML 註解內的行）
  # 格式範例: "Go E2E: line 63 | Java E2E: line 412 | C# E2E: line 675"
  sed -n '/<!-- AI Section Index/,/-->/p' "$file" | \
    grep -oE '[A-Za-z0-9#/.+_ ]+: line [0-9]+' | \
    while IFS= read -r entry; do
      # 用最後一個 ": line" 來分隔 label 和行號
      label=$(echo "$entry" | sed 's/: line [0-9]*$//')
      linenum=$(echo "$entry" | grep -oE '[0-9]+$')
      if [ -n "$linenum" ]; then
        check_line "$file" "$label" "$linenum"
      fi
    done
done

ERRORS=$(wc -l < "$TMPFILE" 2>/dev/null || echo 0)
ERRORS=$(echo "$ERRORS" | tr -d ' ')
rm -f "$TMPFILE"

if [ "$ERRORS" = "0" ]; then
  echo "All AI Section Index entries are valid."
else
  echo "$ERRORS error(s) found. Please update AI Section Index."
  exit 1
fi
