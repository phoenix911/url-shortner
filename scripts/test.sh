#!/usr/bin/env bash
# Run from repo root: bash test.sh
# Requires: .env with ADMIN_PASSWORD and SITE_DOMAIN

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load .env from repo root
if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a; source "$REPO_ROOT/.env"; set +a
else
  echo "ERROR: .env not found at $REPO_ROOT/.env" >&2
  exit 1
fi

: "${ADMIN_PASSWORD:?ADMIN_PASSWORD not set in .env}"
: "${SITE_DOMAIN:?SITE_DOMAIN not set in .env}"

BASE="https://${SITE_DOMAIN}"
COOKIE_JAR="$(mktemp)"
trap 'rm -f "$COOKIE_JAR"' EXIT

PASS=0
FAIL=0

# ── Helpers ────────────────────────────────────────────────────────────────────

green()  { printf '\033[32m%s\033[0m\n' "$*"; }
red()    { printf '\033[31m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

ok() {
  PASS=$((PASS + 1))
  green "  ✓ $1"
}

fail() {
  FAIL=$((FAIL + 1))
  red "  ✗ $1"
}

# assert_eq <label> <expected> <actual>
assert_eq() {
  if [[ "$2" == "$3" ]]; then
    ok "$1 [got: $3]"
  else
    fail "$1 [expected: $2, got: $3]"
  fi
}

# assert_contains <label> <needle> <haystack>
assert_contains() {
  if echo "$3" | grep -q "$2"; then
    ok "$1"
  else
    fail "$1 [expected to contain: $2, got: $3]"
  fi
}

# http <extra curl args...>
# Returns: body\nSTATUS:<code>
http() {
  local args=("$@")
  local status body
  body=$(curl -s -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -w '\nSTATUS:%{http_code}' "${args[@]}")
  echo "$body"
}

status_of()  { echo "$1" | grep -o 'STATUS:[0-9]*' | cut -d: -f2; }
body_of()    { echo "$1" | sed '/^STATUS:/d'; }
json_field() { echo "$2" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$1',''))" 2>/dev/null; }

# ── Tests ──────────────────────────────────────────────────────────────────────

bold ""
bold "cf-link test suite → $BASE"
bold "─────────────────────────────────────────────────"

# ── Routing ────────────────────────────────────────────────────────────────────
bold ""
bold "Routing"

resp=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' "$BASE/")
assert_eq "GET /  →  302 to /create" "302 $BASE/create" "$resp"

resp=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' "$BASE/link")
assert_eq "GET /link  →  302 to /create" "302 $BASE/create" "$resp"

resp=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/create")
assert_eq "GET /create  →  200" "200" "$resp"

# ── Auth ───────────────────────────────────────────────────────────────────────
bold ""
bold "Auth"

resp=$(http -X POST "$BASE/api/login" -F "password=wrongpassword")
assert_eq "POST /api/login bad password  →  401" "401" "$(status_of "$resp")"
assert_contains "POST /api/login bad password body" '"error"' "$(body_of "$resp")"

resp=$(http -X POST "$BASE/api/login" -F "password=$ADMIN_PASSWORD")
assert_eq "POST /api/login correct password  →  200" "200" "$(status_of "$resp")"
assert_contains "POST /api/login sets ok:true" '"ok":true' "$(body_of "$resp")"

# ── Web form create ─────────────────────────────────────────────────────────
bold ""
bold "Web form  (POST /api/shorten)"

TEST_CODE="test$(( RANDOM % 9000 + 1000 ))"

resp=$(http -X POST "$BASE/api/shorten" \
  -F "url=https://example.com/web-form-test" \
  -F "code=$TEST_CODE" \
  -F "ttlDays=7")
assert_eq "create with custom code  →  201" "201" "$(status_of "$resp")"
body=$(body_of "$resp")
assert_contains "response has shortUrl" '"shortUrl"' "$body"
assert_contains "response has expiresAt" '"expiresAt"' "$body"

# duplicate slug
resp=$(http -X POST "$BASE/api/shorten" \
  -F "url=https://example.com/dup" \
  -F "code=$TEST_CODE" \
  -F "ttlDays=7")
assert_eq "duplicate code  →  409" "409" "$(status_of "$resp")"

# slug too short
resp=$(http -X POST "$BASE/api/shorten" \
  -F "url=https://example.com/short" \
  -F "code=ab" \
  -F "ttlDays=7")
assert_eq "slug < 4 chars  →  400" "400" "$(status_of "$resp")"

# auto-generate slug
resp=$(http -X POST "$BASE/api/shorten" \
  -F "url=https://example.com/auto-slug" \
  -F "ttlDays=1")
assert_eq "auto slug  →  201" "201" "$(status_of "$resp")"
AUTO_CODE=$(json_field "code" "$(body_of "$resp")")
[[ -n "$AUTO_CODE" ]] && ok "auto slug generated: $AUTO_CODE" || fail "auto slug: code field missing"

# invalid URL
resp=$(http -X POST "$BASE/api/shorten" -F "url=not-a-url" -F "ttlDays=1")
assert_eq "invalid URL  →  400" "400" "$(status_of "$resp")"

# no session (fresh cookie jar) → 401
resp=$(curl -s -w '\nSTATUS:%{http_code}' -X POST "$BASE/api/shorten" \
  -F "url=https://example.com" -F "ttlDays=1")
assert_eq "no session cookie  →  401" "401" "$(status_of "$resp")"

# ── REST API ────────────────────────────────────────────────────────────────
bold ""
bold "REST API  (POST /api/links)"

API_CODE="api$(( RANDOM % 9000 + 1000 ))"

resp=$(curl -s -w '\nSTATUS:%{http_code}' \
  -X POST "$BASE/api/links" \
  -H "Authorization: Bearer $ADMIN_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"url\":\"https://example.com/rest-test\",\"code\":\"$API_CODE\",\"ttlDays\":30}")
assert_eq "POST /api/links  →  201" "201" "$(status_of "$resp")"
body=$(body_of "$resp")
assert_contains "response has shortUrl" '"shortUrl"' "$body"
assert_contains "response has createdAt" '"createdAt"' "$body"
assert_contains "response has expiresAt" '"expiresAt"' "$body"

# wrong Bearer token
resp=$(curl -s -w '\nSTATUS:%{http_code}' \
  -X POST "$BASE/api/links" \
  -H "Authorization: Bearer wrongtoken" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}')
assert_eq "wrong Bearer token  →  401" "401" "$(status_of "$resp")"

# no auth header
resp=$(curl -s -w '\nSTATUS:%{http_code}' \
  -X POST "$BASE/api/links" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}')
assert_eq "no auth header  →  401" "401" "$(status_of "$resp")"

# invalid URL via REST
resp=$(curl -s -w '\nSTATUS:%{http_code}' \
  -X POST "$BASE/api/links" \
  -H "Authorization: Bearer $ADMIN_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"url":"ftp://bad-scheme.com"}')
assert_eq "invalid URL via REST  →  400" "400" "$(status_of "$resp")"

# invalid JSON body
resp=$(curl -s -w '\nSTATUS:%{http_code}' \
  -X POST "$BASE/api/links" \
  -H "Authorization: Bearer $ADMIN_PASSWORD" \
  -H "Content-Type: application/json" \
  --data-raw 'not json')
assert_eq "malformed JSON  →  400" "400" "$(status_of "$resp")"

# ── Redirect ────────────────────────────────────────────────────────────────
bold ""
bold "Redirect  (GET /:code)"

resp=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' "$BASE/$TEST_CODE")
STATUS=$(echo "$resp" | awk '{print $1}')
LOC=$(echo "$resp" | awk '{print $2}')
assert_eq "GET /$TEST_CODE  →  301" "301" "$STATUS"
assert_eq "Location header correct" "https://example.com/web-form-test" "$LOC"

# second request — cache HIT
CACHE_STATUS=$(curl -s -D - "$BASE/$TEST_CODE" | grep -i "cf-cache-status" | awk '{print $2}' | tr -d '\r')
if [[ "$CACHE_STATUS" == "HIT" ]]; then
  ok "second request  →  cf-cache-status: HIT"
else
  yellow "  ~ second request  →  cf-cache-status: ${CACHE_STATUS:-not present} (CDN Cache Rule may not be active)"
fi

# 404
resp=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/does-not-exist-xyz999")
assert_eq "unknown code  →  404" "404" "$resp"

# ── Metadata lookup ─────────────────────────────────────────────────────────
bold ""
bold "Metadata  (GET /api/links/:code)"

resp=$(http "$BASE/api/links/$TEST_CODE")
assert_eq "GET /api/links/:code (session)  →  200" "200" "$(status_of "$resp")"
body=$(body_of "$resp")
assert_contains "response has url field" '"url"' "$body"
assert_contains "response has createdAt" '"createdAt"' "$body"

resp=$(http "$BASE/api/links/does-not-exist-xyz999")
assert_eq "GET /api/links/missing  →  404" "404" "$(status_of "$resp")"

# ── Summary ─────────────────────────────────────────────────────────────────
bold ""
bold "─────────────────────────────────────────────────"
TOTAL=$((PASS + FAIL))
if [[ $FAIL -eq 0 ]]; then
  green "All $TOTAL tests passed"
else
  red "$FAIL/$TOTAL tests failed"
  exit 1
fi
