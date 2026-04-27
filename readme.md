# cf-link — Serverless URL Shortener on Cloudflare

> Deploy your own URL shortener in minutes. Runs entirely on Cloudflare's free tier — no servers, no database, no monthly bill.

---

## Why cf-link?

Most URL shorteners either cost money at scale or require you to manage infrastructure. cf-link uses Cloudflare Workers + KV + CDN cache to serve **100 million redirects per day for $0/month**.

The CDN Cache Rule is the secret — it serves repeat hits before the Worker even runs, making cost independent of traffic volume.

---

## Cost

12 fixed links, CDN Cache Rule active:

| Hits / day | Worker invocations / month | Monthly cost |
|-----------|---------------------------|-------------|
| 100 | ~2,400 | **$0** |
| 10,000 | ~30,000 | **$0** |
| 1,000,000 | ~150,000 | **$0** |
| 10,000,000 | ~250,000 | **$0** |
| 100,000,000 | ~300,000 | **$0** |

Free tier allows 3,000,000 Worker invocations/month. Even at 100M hits/day the CDN absorbs 99.99% — the Worker only runs on cache misses (once per PoP per hour).

Full breakdown → **[costs.md](costs.md)**

---

## Features

- **Zero cost at any scale** — CDN cache absorbs 99%+ of traffic
- **Password-protected web UI** — create links from any browser
- **REST API** — programmatic link creation with Bearer token auth
- **Custom slugs** — choose your own short code or auto-generate
- **Optional TTL** — links auto-expire (default 365 days, or never)
- **Interactive setup wizard** — one command deploys everything
- **Git auto-deploy** — push to main, Cloudflare deploys automatically
- **Zero runtime dependencies** — pure Cloudflare stack

---

## Quick start

```bash
git clone https://github.com/phoenix911/url-shortner.git
cd url-shortner
make setup
```

The setup wizard handles everything — Cloudflare auth, KV namespaces, domain config, admin password, and deploy. Run it again any time to resume from where it left off.

Full deployment guide → **[guide.md](guide.md)**

---

## How it works

```
User clicks short link
        │
        ▼
Cloudflare CDN  ←── Cache Rule
        │
   HIT (99%+) ──→ 301 redirect served instantly
        │             (Worker not invoked)
        │
   MISS (1st hit per PoP per hour)
        │
        ▼
   Cloudflare Worker
        │
   KV lookup → cache response → 301 redirect
```

---

## REST API

```bash
# Create a short link
curl -X POST https://your-domain.com/api/links \
  -H "Authorization: Bearer YOUR_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/long", "code": "myslug", "ttlDays": 30}'

# Response
{
  "code": "myslug",
  "shortUrl": "https://your-domain.com/myslug",
  "url": "https://example.com/long",
  "createdAt": "2026-04-26T12:00:00.000Z",
  "expiresAt": "2026-05-26T12:00:00.000Z"
}
```

Full API reference → **[curl/create.md](curl/create.md)**

---

## Routes

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/:code` | — | Redirect to stored URL (301) |
| GET | `/create` | session | Web UI |
| POST | `/api/login` | — | Exchange password for session cookie |
| POST | `/api/shorten` | session | Create link via web form |
| POST | `/api/links` | Bearer | Create link via REST API |
| GET | `/api/links/:code` | Bearer | Fetch link metadata |

---

## Stack

| Layer | Tech |
|-------|------|
| Runtime | Cloudflare Workers |
| Router | Hono.js |
| Storage | Cloudflare KV |
| Language | TypeScript |
| Deploy | Wrangler + GitHub Git integration |
| Cache | Cloudflare Cache Rules (CDN layer) |

Tech choices explained → **[tech.md](tech.md)**

---

## Makefile commands

```bash
make setup              # interactive setup wizard (resumes automatically)
make dev                # local dev server at localhost:8787
make deploy             # deploy to Cloudflare
make commit MSG="..."   # stage, commit, push
make create URL=...     # create a short link via API
make create-interactive # interactive prompt for URL / code / TTL
```

---

## Documentation

| Doc | Description |
|-----|-------------|
| [guide.md](guide.md) | Complete deployment guide — automated + manual steps, CDN Cache Rule |
| [costs.md](costs.md) | Cost analysis at every traffic scale |
| [tech.md](tech.md) | Stack decisions and why |
| [curl/create.md](curl/create.md) | REST API reference with curl examples |
| [prompt.md](prompt.md) | Ideas and prompts for future features |
| [llm/architecture.md](llm/architecture.md) | Data flow, KV schema, route map |
| [llm/conventions.md](llm/conventions.md) | Code conventions and patterns |

---

## License

MIT — use it, fork it, deploy it anywhere.
