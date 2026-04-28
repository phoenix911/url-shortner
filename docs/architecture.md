[← Back to readme](../readme.md)

# Architecture

## Request flow

```
Browser / API client
        │
        ▼
Cloudflare Edge (Worker)
        │
   [Hono router]
        │
   ┌────┴──────────────────────────────────┐
   │  GET /                → 302 /create   │
   │  GET /link            → 302 /create   │
   │  GET /create          → HTML page     │
   │  POST /api/login      → set cookie    │
   │  POST /api/shorten    → JSON (web)    │
   │  POST /api/links      → JSON (REST)   │
   │  GET  /api/links/:c   → JSON (REST)   │
   │  GET  /:code          → 301 long URL  │
   └────┬──────────────────────────────────┘
        │
   [Cloudflare KV — LINKS namespace]
```

## KV schema

```
Key:   <slug>          e.g.  "xk92mP"
Value: JSON string
{
  "url":       "https://example.com/...",
  "createdAt": "2026-04-26T12:00:00Z",
  "expiresAt": "2027-04-26T12:00:00Z"  // null = no expiry
}
```

KV `expirationTtl` is set on write so Cloudflare auto-purges expired keys.

## Auth flow

### Web UI
1. `GET /create` → server checks `__session` cookie → if missing/invalid, returns HTML with login form active
2. `POST /api/login` → verifies password → signs HMAC-SHA256(password + timestamp) → sets `__session` cookie
3. `POST /api/shorten` → verifies cookie → creates link → returns JSON

### REST API
1. All `/api/links/*` requests require `Authorization: Bearer <ADMIN_PASSWORD>`
2. Middleware (`requireApiAuth`) checks header → 401 if missing/wrong

## Environment bindings

| Binding | Type | Purpose |
|---------|------|---------|
| `LINKS` | KVNamespace | Link storage |
| `ADMIN_PASSWORD` | Secret | Web password + API Bearer token |
| `SITE_DOMAIN` | Var | `your-domain.com` (used to build short URLs) |

## File responsibilities

| File | Responsibility |
|------|----------------|
| `src/lib/kv.ts` | `Env` type definition + KV CRUD wrappers |
| `src/lib/generate.ts` | Cryptographically random slug generation |
| `src/lib/validate.ts` | URL, slug, TTL validation (used by both web + API routes) |
| `src/middleware/auth.ts` | HMAC session signing/verification + middleware factories |
| `src/routes/create.ts` | Serves the HTML UI (checks auth server-side to pick initial state) |
| `src/routes/api.ts` | Web form endpoints: login + shorten |
| `src/routes/links.ts` | REST API endpoints for programmatic access |
| `src/routes/redirect.ts` | Slug → long URL redirect |
| `src/pages/create.html` | Full single-page UI (inline CSS + JS) |
