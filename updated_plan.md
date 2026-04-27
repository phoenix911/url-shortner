# URL Shortener — updated plan

## What was built

A Cloudflare Workers URL shortener at your-domain.com with:

- **Web UI** at `/create` — password-gated, cookie session (HMAC-SHA256), create form with custom slug + TTL fields
- **REST API** at `/api/links` — Bearer token auth, full JSON CRUD
- **Redirect** at `/:code` — 301 to stored URL, 404 page if missing
- **KV storage** with native TTL (defaults 365 days, 0 = never expire)

## Decisions made

| Question | Decision | Reason |
|----------|----------|--------|
| Auth | Simple password + HMAC cookie | No user accounts needed; personal tooling |
| Analytics | None | Keep it simple; can add later |
| TTL | Optional, default 365 days | Prevents stale links accumulating forever |
| API | REST JSON + Bearer token | Enables programmatic use / automation |

## File map

```
code/src/index.ts                  Worker entry, mounts all routes
code/src/lib/generate.ts           Random slug generator
code/src/lib/validate.ts           URL / slug / TTL validation
code/src/lib/kv.ts                 KV helpers + Env type
code/src/middleware/auth.ts        Cookie session + Bearer token middleware
code/src/routes/create.ts          GET /create
code/src/routes/api.ts             POST /api/login, POST /api/shorten
code/src/routes/links.ts           POST /api/links, GET /api/links/:code
code/src/routes/redirect.ts        GET /:code
code/src/pages/create.html         Full UI (inline CSS + JS)
code/wrangler.toml                 Cloudflare config
```

## Deploy checklist

1. `npm install` in `code/`
2. Create KV namespace → paste IDs into `wrangler.toml`
3. `wrangler secret put ADMIN_PASSWORD`
4. `npm run deploy`
5. Add Custom Domain `your-domain.com` in Cloudflare dashboard
