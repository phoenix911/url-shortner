---
title: Project Context
---

# cf-link — Project Context

## What this is

A URL shortener for your own domain. Short links are served at `your-domain.com/<code>` and redirect (301) to the stored long URL.

## Owner

Repo owner

## Goals

1. Internal / personal link shortener — not a public SaaS
2. Clean, minimal UI at `/create` for quick link creation
3. REST API for programmatic use (automation, scripts)
4. Zero ops — fully managed via Cloudflare (no servers, no DB, no cron)

## Non-goals

- Multi-user accounts or roles
- Click analytics (can be added later — see prompt.md)
- Public link creation (password-protected)

## Key constraints

- Must run entirely on Cloudflare (Workers + KV)
- No external databases or third-party services
- Single admin password — not multi-tenant

## Entry points

- `code/src/index.ts` — Worker entry, Hono app
- `code/wrangler.toml` — Cloudflare config (update KV IDs + set secret before deploy)
