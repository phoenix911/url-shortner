#!/bin/bash
# cf-link setup script
# Run from repo root: bash scripts/setup.sh
# Resume anytime — completed steps are skipped automatically

# NOTE: intentionally no set -e so failures are handled gracefully per-step

# ── colours ────────────────────────────────────────────────────────────────────
BOLD="\033[1m"
DIM="\033[2m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

# ── state file (gitignored) ────────────────────────────────────────────────────
STATE_FILE=".setup-state"
touch "$STATE_FILE"

step_done()  { grep -qx "$1" "$STATE_FILE" 2>/dev/null; }
mark_done()  { grep -qx "$1" "$STATE_FILE" 2>/dev/null || echo "$1" >> "$STATE_FILE"; }
skip_step()  { echo -e "  ${GREEN}✓ already done — skipping${RESET}"; }

# ── helpers ────────────────────────────────────────────────────────────────────
header() {
  clear
  echo -e "${BOLD}${CYAN}"
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║         cf-link  —  setup wizard         ║"
  echo "  ╚══════════════════════════════════════════╝"
  echo -e "${RESET}"
  echo -e "  State file: ${DIM}$STATE_FILE${RESET}  (delete to restart from scratch)"
  echo ""
}

step() {
  local num="$1" title="$2"
  echo ""
  echo -e "${BOLD}  Step $num / 8 — $title${RESET}"
  echo -e "  ${DIM}──────────────────────────────────────────${RESET}"
}

info()    { echo -e "  ${CYAN}→${RESET}  $*"; }
success() { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}!${RESET}  $*"; }
fail()    { echo -e "  ${RED}✗${RESET}  $*"; echo ""; exit 1; }

ask() {
  local prompt="$1" var="$2" default="${3:-}"
  if [ -n "$default" ]; then
    read -rp "    $prompt [$default]: " "$var" </dev/tty
    [ -z "${!var}" ] && eval "$var=\"$default\""
  else
    read -rp "    $prompt: " "$var" </dev/tty
  fi
}

ask_yn() {
  local prompt="$1"
  local answer
  read -rp "    $prompt (y/n): " answer </dev/tty
  [[ "$answer" == "y" || "$answer" == "Y" ]]
}

# ── auto-detect already-configured project ────────────────────────────────────
is_configured() {
  [ -f "code/wrangler.toml" ] &&
  ! grep -q "REPLACE_WITH" "code/wrangler.toml" &&
  [ -f ".env" ] && grep -q "ADMIN_PASSWORD=" ".env"
}

auto_mark_configured() {
  mark_done "prereqs"
  mark_done "wrangler_toml"
  mark_done "kv_prod"
  mark_done "kv_preview"
  mark_done "domain"
  mark_done "password"
  mark_done "install"
}

# ── show progress summary ──────────────────────────────────────────────────────
show_progress() {
  local steps=("prereqs" "wrangler_toml" "kv_prod" "kv_preview" "domain" "password" "install" "deploy")
  local labels=("Prerequisites" "wrangler.toml" "KV namespace (prod)" "KV namespace (preview)" "Domain config" "Admin password" "npm install" "Deploy")
  echo -e "  ${BOLD}Progress:${RESET}"
  for i in "${!steps[@]}"; do
    if step_done "${steps[$i]}"; then
      echo -e "    ${GREEN}✓${RESET}  $((i+1)). ${labels[$i]}"
    else
      echo -e "    ${DIM}○${RESET}  $((i+1)). ${labels[$i]}"
    fi
  done
  echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

header

# ── auto-detect already-deployed project (no .setup-state yet) ────────────────
if is_configured && ! grep -q "prereqs" "$STATE_FILE" 2>/dev/null; then
  echo -e "  ${GREEN}${BOLD}Existing deployment detected${RESET}"
  echo ""
  echo -e "  ${DIM}wrangler.toml  — found with real IDs${RESET}"
  echo -e "  ${DIM}.env           — found with ADMIN_PASSWORD${RESET}"
  echo ""
  if ask_yn "Looks like this project is already configured. Mark setup steps as done and skip to deploy?"; then
    auto_mark_configured
    success "Steps 1–7 marked as done"
  fi
  echo ""
fi

show_progress

if ! ask_yn "Continue?"; then
  echo ""
  info "Run this script again any time to resume."
  exit 0
fi

# ── Step 1 — Prerequisites ─────────────────────────────────────────────────────
step 1 "Prerequisites"

if step_done "prereqs"; then skip_step; else

  # Node
  if ! command -v node &>/dev/null; then
    fail "Node.js not found. Install from https://nodejs.org (v18+)"
  fi
  NODE_VER=$(node -e "process.stdout.write(process.version.replace('v','').split('.')[0])")
  if [ "$NODE_VER" -lt 18 ]; then
    fail "Node.js v$NODE_VER found — v18+ required."
  fi
  success "Node.js $(node -v)"

  # npm
  if ! command -v npm &>/dev/null; then
    fail "npm not found. Install Node.js from https://nodejs.org"
  fi
  success "npm $(npm -v)"

  # wrangler login check
  info "Checking Cloudflare auth..."
  if ! (cd code && npx wrangler whoami >/dev/null 2>&1); then
    warn "Not logged in to Cloudflare. Opening browser..."
    (cd code && npx wrangler login) || fail "wrangler login failed."
  fi
  CF_USER=$(cd code && npx wrangler whoami 2>/dev/null | grep -i "logged in" | sed 's/.*as //' | tr -d '!' || true)
  success "Cloudflare auth OK${CF_USER:+ — $CF_USER}"

  mark_done "prereqs"
fi

# ── Step 2 — wrangler.toml ─────────────────────────────────────────────────────
step 2 "wrangler.toml"

if step_done "wrangler_toml"; then skip_step; else

  if [ ! -f "code/wrangler.toml" ]; then
    cp code/wrangler.example.toml code/wrangler.toml
    success "Copied wrangler.example.toml → wrangler.toml"
  else
    success "wrangler.toml already exists"
  fi

  mark_done "wrangler_toml"
fi

# ── Step 3 — KV namespace (prod) ───────────────────────────────────────────────
step 3 "KV namespace (production)"

if step_done "kv_prod"; then skip_step; else

  if grep -q "REPLACE_WITH_YOUR_KV_NAMESPACE_ID" code/wrangler.toml; then
    info "Creating KV namespace LINKS..."
    KV_OUT=$(cd code && npx wrangler kv namespace create LINKS 2>&1) || true
    KV_ID=$(echo "$KV_OUT" | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$KV_ID" ]; then
      if echo "$KV_OUT" | grep -qi "already exists"; then
        warn "A namespace named LINKS already exists in your Cloudflare account."
        info "Your existing KV namespaces:"
        (cd code && npx wrangler kv namespace list 2>/dev/null) || true
        echo ""
        ask "Paste the id of your existing LINKS namespace" KV_ID
      else
        warn "Unexpected output from wrangler:"
        echo "$KV_OUT"
        ask "Paste the KV namespace id manually" KV_ID
      fi
    fi

    [ -z "$KV_ID" ] && fail "No KV namespace id provided — cannot continue."
    sed -i.bak "s|REPLACE_WITH_YOUR_KV_NAMESPACE_ID|$KV_ID|" code/wrangler.toml && rm -f code/wrangler.toml.bak
    success "KV namespace id set: $KV_ID"
  else
    success "KV namespace ID already set"
  fi

  mark_done "kv_prod"
fi

# ── Step 4 — KV namespace (preview) ───────────────────────────────────────────
step 4 "KV namespace (preview / local dev)"

if step_done "kv_preview"; then skip_step; else

  if grep -q "REPLACE_WITH_YOUR_KV_NAMESPACE_PREVIEW_ID" code/wrangler.toml; then
    info "Creating preview KV namespace LINKS..."
    KV_PREV_OUT=$(cd code && npx wrangler kv namespace create LINKS --preview 2>&1) || true
    KV_PREV_ID=$(echo "$KV_PREV_OUT" | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$KV_PREV_ID" ]; then
      if echo "$KV_PREV_OUT" | grep -qi "already exists"; then
        warn "A preview namespace named LINKS already exists."
        info "Your existing KV namespaces:"
        (cd code && npx wrangler kv namespace list 2>/dev/null) || true
        echo ""
        ask "Paste the id of your existing LINKS preview namespace" KV_PREV_ID
      else
        warn "Unexpected output from wrangler:"
        echo "$KV_PREV_OUT"
        ask "Paste the preview KV namespace id manually" KV_PREV_ID
      fi
    fi

    [ -z "$KV_PREV_ID" ] && fail "No preview KV namespace id provided — cannot continue."
    sed -i.bak "s|REPLACE_WITH_YOUR_KV_NAMESPACE_PREVIEW_ID|$KV_PREV_ID|" code/wrangler.toml && rm -f code/wrangler.toml.bak
    success "Preview KV namespace id set: $KV_PREV_ID"
  else
    success "Preview KV namespace ID already set"
  fi

  mark_done "kv_preview"
fi

# ── Step 5 — Domain ────────────────────────────────────────────────────────────
step 5 "Domain configuration"

if step_done "domain"; then skip_step; else

  CURRENT_DOMAIN=$(grep 'SITE_DOMAIN' code/wrangler.toml | head -1 | cut -d'"' -f2)
  info "Current domain: ${BOLD}$CURRENT_DOMAIN${RESET}"

  if ask_yn "Change domain?"; then
    ask "Enter your short link domain (e.g. link.example.com)" NEW_DOMAIN
    sed -i.bak "s|$CURRENT_DOMAIN|$NEW_DOMAIN|g" code/wrangler.toml && rm -f code/wrangler.toml.bak
    success "Domain updated to: $NEW_DOMAIN"
  else
    success "Keeping domain: $CURRENT_DOMAIN"
  fi

  mark_done "domain"
fi

# ── Step 6 — Admin password ────────────────────────────────────────────────────
step 6 "Admin password"

if step_done "password"; then skip_step; else

  if [ -f ".env" ] && grep -q "ADMIN_PASSWORD=" .env; then
    EXISTING_PASS=$(grep "ADMIN_PASSWORD=" .env | cut -d'=' -f2-)
    info "Password found in .env"
    if ask_yn "Push existing .env password to Cloudflare as Worker secret?"; then
      info "Setting secret..."
      echo "$EXISTING_PASS" | (cd code && npx wrangler secret put ADMIN_PASSWORD) || \
        fail "wrangler secret put failed. Check your Cloudflare auth and try again."
      success "Secret set from .env"
    else
      warn "Skipped — existing .env password not pushed. Worker may use a stale secret."
    fi
  else
    GENERATED=$(openssl rand -base64 32)
    info "Generated password: ${BOLD}$GENERATED${RESET}"
    ask "Press enter to use generated, or type your own" ADMIN_PASS "$GENERATED"
    echo "ADMIN_PASSWORD=$ADMIN_PASS" > .env
    echo "$ADMIN_PASS" | (cd code && npx wrangler secret put ADMIN_PASSWORD) || \
      fail "wrangler secret put failed. Check your Cloudflare auth and try again."
    success "Password saved to .env and set in Cloudflare"
  fi

  mark_done "password"
fi

# ── Step 7 — npm install ───────────────────────────────────────────────────────
step 7 "Install dependencies"

if step_done "install"; then skip_step; else

  info "Running npm install..."
  (cd code && npm install --silent) || fail "npm install failed."
  success "Dependencies installed"
  mark_done "install"

fi

# ── Step 8 — Deploy ────────────────────────────────────────────────────────────
step 8 "Deploy to Cloudflare"

if step_done "deploy"; then

  skip_step
  warn "Already deployed. Run ${BOLD}make deploy${RESET} to redeploy."

else

  if ask_yn "Deploy now?"; then
    info "Deploying..."
    (cd code && npx wrangler deploy) || fail "Deploy failed. Check errors above."
    success "Deployed!"
    mark_done "deploy"
  else
    warn "Skipped. Run ${BOLD}make deploy${RESET} when ready."
  fi

fi

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║              Setup complete!             ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${RESET}"

DOMAIN=$(grep 'SITE_DOMAIN' code/wrangler.toml 2>/dev/null | head -1 | cut -d'"' -f2 || echo "your-domain")

echo -e "  ${BOLD}Your short link service:${RESET}"
echo -e "    Web UI  →  ${CYAN}https://$DOMAIN/create${RESET}"
echo -e "    API     →  ${CYAN}https://$DOMAIN/api/links${RESET}"
echo ""
echo -e "  ${BOLD}One remaining manual step:${RESET}"
echo -e "    CDN Cache Rule — see guide.md § CDN Cache Rule"
echo ""
echo -e "  ${BOLD}Useful commands:${RESET}"
echo -e "    ${DIM}make dev${RESET}                    — local dev server"
echo -e "    ${DIM}make deploy${RESET}                 — redeploy"
echo -e "    ${DIM}make create URL=https://...${RESET} — create a short link"
echo ""
