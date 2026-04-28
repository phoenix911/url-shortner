<div align="center">

# cf-link

**Self-hosted URL shortener on Cloudflare's free tier**

Serves 100 million redirects/day for $0/month — no servers, no database, no bill.

[![Deploy to Cloudflare](https://deploy.workers.cloudflare.com/button)](https://deploy.workers.cloudflare.com/?url=https://github.com/phoenix911/url-shortner)

![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=flat&logo=typescript&logoColor=white)
![Cloudflare Workers](https://img.shields.io/badge/Cloudflare_Workers-F38020?style=flat&logo=cloudflare&logoColor=white)
![Hono](https://img.shields.io/badge/Hono-E36002?style=flat&logo=hono&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green?style=flat)

</div>

---

## Why cf-link?

Most URL shorteners cost money at scale or require you to manage infrastructure. cf-link uses **Cloudflare Workers + KV + CDN Cache Rules** to serve redirects entirely from the CDN edge — the Worker only runs on the first request per data center per hour, not on every hit.

```
100M hits/day → ~300,000 Worker invocations/month → $0
                  Free tier limit: 3,000,000/month
```

---

## Cost

> 12 active links, CDN Cache Rule enabled

| Hits / day | Worker invocations / month | Cost |
|:----------:|:--------------------------:|:----:|
| 100 | ~2,400 | **$0** |
| 10,000 | ~30,000 | **$0** |
| 1,000,000 | ~150,000 | **$0** |
| 10,000,000 | ~250,000 | **$0** |
| 100,000,000 | ~300,000 | **$0** |

Full breakdown → [docs/costs.md](docs/costs.md) · High-volume analysis (100 links/day) → [docs/cost_analysis.md](docs/cost_analysis.md)

---

## Features

| | |
|---|---|
| **Zero-cost at any scale** | CDN Cache Rule absorbs 99%+ of traffic before Worker runs |
| **Password-protected UI** | Clean web form to create and manage links |
| **Analytics dashboard** | `/dashboard` — links list with per-link click counts + country breakdown |
| **Real hit counts** | Zone Analytics API tracks all hits including CDN-cached redirects |
| **Dark / light mode** | Theme toggle persists across pages via localStorage |
| **REST API** | Programmatic access with Bearer token auth |
| **Custom slugs** | Pick your own code or auto-generate a 6-char slug |
| **TTL support** | Links auto-expire (default 365 days, or never) |
| **Setup wizard** | `make setup` handles auth, KV, domain, and deploy |
| **Git auto-deploy** | Push to main → Cloudflare deploys automatically |
| **32 E2E tests** | `make test` runs a full suite against your live worker |

---

## Quick start

**Option A — Deploy button** *(recommended for new deployments)*

Click the button above. After deploy:
1. Set `ADMIN_PASSWORD` secret — Workers → your worker → Settings → Variables & Secrets
2. Add your domain — Settings → Domains & Routes → Add Custom Domain

**Option B — Clone and deploy**

```bash
git clone https://github.com/phoenix911/url-shortner.git
cd url-shortner
make setup
```

The wizard handles Cloudflare auth, KV namespace creation, domain config, admin password, and deploy. Resume any time if interrupted.

Full guide → [docs/guide.md](docs/guide.md)

---

## How it works

```
  visitor clicks short link
          │
          ▼
  ┌───────────────────┐
  │  Cloudflare CDN   │◄── Cache Rule (platform-level)
  └───────────────────┘
    │              │
   HIT            MISS
  (99%+)     (1st req per PoP per hour)
    │              │
    │              ▼
    │     ┌─────────────────┐
    │     │ Cloudflare      │
    │     │ Worker          │
    │     └────────┬────────┘
    │              │
    │              ▼
    │     ┌─────────────────┐
    │     │ KV lookup →     │
    │     │ cache response  │
    │     └────────┬────────┘
    │              │
    └──────────────┘
          │
          ▼
     301 redirect
```

A **PoP** (Point of Presence) is a Cloudflare data center. There are ~300 globally. Each one caches independently — so Worker invocations are bounded by `active links × PoPs × 24`, not by traffic volume.

---

## REST API

```bash
# Create a short link
curl -X POST https://your-domain.com/api/links \
  -H "Authorization: Bearer YOUR_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/very/long/path", "code": "myslug", "ttlDays": 30}'
```

```json
{
  "code": "myslug",
  "shortUrl": "https://your-domain.com/myslug",
  "url": "https://example.com/very/long/path",
  "createdAt": "2026-04-26T12:00:00.000Z",
  "expiresAt": "2026-05-26T12:00:00.000Z"
}
```

Full reference → [docs/api.md](docs/api.md)

---

## Routes

| Method | Path | Auth | |
|--------|------|------|-|
| `GET` | `/:code` | — | 301 redirect to stored URL |
| `GET` | `/create` | session cookie | Web UI — create links |
| `GET` | `/dashboard` | session cookie | Links list + analytics |
| `POST` | `/api/login` | — | Exchange password for session |
| `POST` | `/api/shorten` | session cookie | Create link via web form |
| `POST` | `/api/links` | Bearer token | Create link via REST |
| `GET` | `/api/links` | session cookie | List all links |
| `GET` | `/api/links/:code` | session cookie | Fetch link metadata |
| `GET` | `/api/links/:code/stats` | session cookie | Click counts + country breakdown |

---

## Analytics setup

The `/dashboard` stats panel shows click counts and country breakdown. It uses Cloudflare's Zone Analytics API — which counts **all** hits including CDN-cached redirects, not just Worker invocations.

Set two secrets on your worker after deploy:

```bash
wrangler secret put CF_ZONE_ID    # right sidebar of dash.cloudflare.com → your domain
wrangler secret put CF_API_TOKEN  # needs Zone Analytics Read permission
```

Or add them in **Workers & Pages → your worker → Settings → Variables & Secrets**.

> Free plan returns last 24 hours of data. Paid plan extends to 90 days.

---

## Stack

| Layer | Tech | Why |
|-------|------|-----|
| Runtime | Cloudflare Workers | V8 isolates, 0ms cold start, global edge |
| Router | Hono.js | Lightest router built for Workers |
| Storage | Cloudflare KV | Native TTL, globally replicated |
| Language | TypeScript | Type safety, compiled by Wrangler |
| Cache | CDN Cache Rules | Platform-level, bypasses Worker entirely |
| Analytics | Cloudflare Zone Analytics | All hits including CDN cache, no extra infra |

Tech decisions → [docs/tech.md](docs/tech.md)

---

## Makefile

```bash
make setup              # interactive setup wizard (resumes automatically)
make deploy             # deploy to Cloudflare Workers
make dev                # local dev server at localhost:8787
make test               # 32 end-to-end tests against live worker
make create URL=...     # create a short link  (CODE=slug  TTL=days)
make create-interactive # prompt for URL / code / TTL
make commit MSG="..."   # stage all, commit, push  (NP=1 to skip push)
make help               # show all commands
```

---

## Documentation

| | |
|---|---|
| [docs/guide.md](docs/guide.md) | Full deployment guide — wizard, manual steps, CDN Cache Rule setup |
| [docs/costs.md](docs/costs.md) | Cost model — fixed links at 100 to 100M hits/day |
| [docs/cost_analysis.md](docs/cost_analysis.md) | Cost model — 100 new links/day, free tier limits, paid plan |
| [docs/tech.md](docs/tech.md) | Stack decisions and tradeoffs |
| [docs/api.md](docs/api.md) | REST API curl reference |
| [docs/architecture.md](docs/architecture.md) | Data flow, KV schema, route map |

---

<div align="center">

MIT license — use it, fork it, deploy it anywhere.

</div>
