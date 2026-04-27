# Deployment Guide

Everything you need to deploy cf-link to any domain.

---

## Prerequisites

- Cloudflare account (free tier works)
- Domain added to Cloudflare with DNS managed by Cloudflare
- Node.js >= 18
- Git

---

## Option A — Automated setup (recommended)

The setup wizard handles everything interactively and **resumes from where it left off** if interrupted.

```bash
git clone git@github.com:your-org/your-repo.git
cd your-repo
make setup
```

The wizard walks through 8 steps:

| Step | What it does |
|------|-------------|
| 1 | Checks Node ≥18, npm, Cloudflare auth — opens `wrangler login` if needed |
| 2 | Copies `wrangler.example.toml → wrangler.toml` |
| 3 | Creates KV namespace (prod) — auto-pastes ID into `wrangler.toml` |
| 4 | Creates KV namespace (preview) — auto-pastes ID into `wrangler.toml` |
| 5 | Prompts for your domain — updates all references in `wrangler.toml` |
| 6 | Generates a secure password, saves to `.env`, runs `wrangler secret put` |
| 7 | Runs `npm install` |
| 8 | Deploys with `wrangler deploy` |

**Resume:** progress is saved in `.setup-state`. Run `make setup` again at any time to pick up where you left off. Delete `.setup-state` to restart from scratch.

After the wizard completes, skip to **[Step: CDN Cache Rule](#cdn-cache-rule)** below — that's the one step that must be done manually in the dashboard.

---

## Option B — Manual setup

Follow these steps if you prefer full control or are deploying to a CI environment.

### 1 — Clone

```bash
git clone git@github.com:your-org/your-repo.git
cd your-repo
```

### 2 — Authenticate with Cloudflare

```bash
cd code && npx wrangler login
```

### 3 — Copy and configure wrangler.toml

`wrangler.toml` is gitignored so your KV IDs and domain stay private. Copy the example:

```bash
cp code/wrangler.example.toml code/wrangler.toml
```

Update your domain in `code/wrangler.toml`:

```toml
[[routes]]
pattern = "your-subdomain.yourdomain.com"
custom_domain = true

[vars]
SITE_DOMAIN = "your-subdomain.yourdomain.com"
```

### 4 — Create KV namespaces

```bash
cd code

npx wrangler kv namespace create LINKS
# → copy the returned id into wrangler.toml → id = "..."

npx wrangler kv namespace create LINKS --preview
# → copy the returned id into wrangler.toml → preview_id = "..."
```

### 5 — Set admin password

Generate a secure password and save it:

```bash
openssl rand -base64 32
echo "ADMIN_PASSWORD=<generated>" > .env
```

Push it to Cloudflare as a Worker secret:

```bash
cd code && npx wrangler secret put ADMIN_PASSWORD
# paste your password when prompted
```

### 6 — Install and deploy

```bash
cd code && npm install
make deploy
```

Wrangler registers the custom domain and provisions SSL automatically.

---

## CDN Cache Rule

> This is the only step that cannot be automated — it must be set in the Cloudflare dashboard once per domain.

Without this rule, every redirect invokes the Worker. With it, the CDN serves repeat hits before the Worker runs — dropping cost to $0 at any traffic level.

1. Go to: `https://dash.cloudflare.com/<account-id>/<your-domain>/caching/cache-rules`
2. Click **Create Cache Rule**
3. Name: `CacheLinkShort`
4. Select **Custom filter expression** and paste (replace domain):

```
(http.host eq "your-subdomain.yourdomain.com" and not starts_with(http.request.uri.path, "/api") and not starts_with(http.request.uri.path, "/create"))
```

5. Configure:

| Setting | Value |
|---------|-------|
| Cache eligibility | Eligible for cache |
| Edge TTL | Ignore cache-control header → `3600s` |
| Browser TTL | Override origin → `60s` |
| Ignore query string | On |
| Serve stale while revalidating | On |

6. Click **Deploy**

**Verify it's working:**

```bash
curl -Is https://your-subdomain.yourdomain.com/any-code | grep "cf-cache-status"
curl -Is https://your-subdomain.yourdomain.com/any-code | grep "cf-cache-status"
# second hit should return: cf-cache-status: HIT
```

---

## Git auto-deploy (optional)

Connect your repo so every push to `main` deploys automatically — no `make deploy` needed.

1. Cloudflare dashboard → Workers & Pages → your worker → **Settings → Git**
2. Authorize GitHub → select your repo
3. Build config:

| Field | Value |
|-------|-------|
| Root directory | `code` |
| Build command | `npm install` |
| Deploy command | `npx wrangler deploy` |

4. Save

---

## Local development

```bash
make dev
# → http://localhost:8787
```

Visit `http://localhost:8787/create`. Local dev doesn't enforce `ADMIN_PASSWORD` — any input works.

---

## Multiple domains / staging

To run separate instances (staging + production):

```bash
cp code/wrangler.toml code/wrangler.staging.toml
# update name, pattern, SITE_DOMAIN in the staging file
cd code && npx wrangler deploy --config wrangler.staging.toml
```

Each instance gets its own Worker, KV namespace, and secret.

---

## Checklist

**Automated (done by `make setup`):**
- [ ] Repo cloned
- [ ] `wrangler login` done
- [ ] `wrangler.toml` configured with domain + KV IDs
- [ ] `ADMIN_PASSWORD` in `.env` and set as Worker secret
- [ ] `npm install` done
- [ ] `make deploy` run successfully

**Manual (one-time in dashboard):**
- [ ] CDN Cache Rule created
- [ ] `cf-cache-status: HIT` confirmed on second hit

**Optional:**
- [ ] Git auto-deploy connected
