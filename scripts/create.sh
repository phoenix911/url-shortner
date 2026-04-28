#!/bin/bash

# Usage: ./create.sh <url> [code] [ttlDays]
# Defaults: code=auto, ttlDays=365

# Load .env from repo root if ADMIN_PASSWORD not already in environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"
if [ -z "$ADMIN_PASSWORD" ] && [ -f "$ENV_FILE" ]; then
  # shellcheck source=../.env
  set -a; source "$ENV_FILE"; set +a
fi

URL="${1}"
CODE="${2:-}"
TTL="${3:-365}"
PASSWORD="${ADMIN_PASSWORD}"
BASE="https://your-domain.com"

if [ -z "$URL" ]; then
  echo "Usage: ./create.sh <url> [code] [ttlDays]"
  echo "  url     — required, must start with http:// or https://"
  echo "  code    — optional custom slug (min 4 chars), default: auto"
  echo "  ttlDays — optional expiry in days, default: 365 (0 = never)"
  exit 1
fi

if [ -z "$PASSWORD" ]; then
  echo "Error: ADMIN_PASSWORD env var is not set."
  echo "  export ADMIN_PASSWORD=your_password"
  exit 1
fi

# Build JSON body
if [ -n "$CODE" ]; then
  BODY=$(printf '{"url":"%s","code":"%s","ttlDays":%s}' "$URL" "$CODE" "$TTL")
else
  BODY=$(printf '{"url":"%s","ttlDays":%s}' "$URL" "$TTL")
fi

RESPONSE=$(curl -s -X POST "$BASE/api/links" \
  -H "Authorization: Bearer $PASSWORD" \
  -H "Content-Type: application/json" \
  -d "$BODY")

# Pretty print if jq is available
if command -v jq &>/dev/null; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi
