[← Back to readme](../readme.md)

# Tech Stack

## Runtime — Cloudflare Workers

All server-side logic runs as a Cloudflare Worker: a V8 isolate that starts in < 5 ms with no cold-boot penalty. No Node.js, no container, no servers to manage.

## Storage — Cloudflare KV

Key–value store with global replication. Each short code is a KV key; the value is a JSON object with `url`, `createdAt`, `expiresAt`. KV's native `expirationTtl` is used so Cloudflare auto-purges expired entries — no cron jobs needed.

## Router — Hono

[Hono](https://hono.dev) is a tiny (< 14 kB) router built specifically for edge runtimes (Workers, Deno Deploy, Bun). It provides typed middleware, cookie helpers, and a clean routing API without the overhead of Express.

## Language — TypeScript

Fully typed. `@cloudflare/workers-types` provides accurate types for `KVNamespace`, `ExecutionContext`, and the Worker environment. Compiled by Wrangler's embedded esbuild — no separate build step.

## Auth

- **Web UI**: HMAC-SHA256 signed cookie (password + timestamp). No database session — the signature is the proof. Cookie is HttpOnly / Secure / SameSite=Strict, 8-hour max-age.
- **REST API**: Stateless Bearer token = the same `ADMIN_PASSWORD` secret. Simple, suitable for personal/internal tooling.

## Deployment — Wrangler

Wrangler bundles the Worker + inlines the HTML template at build time, then publishes to Cloudflare's edge. The same CLI is used for local dev with a local KV simulator.

## No Build Step for HTML

The HTML template (`src/pages/create.html`) is imported as a string via Wrangler's static asset inlining — no bundler plugin needed. All CSS and JS are inline, so the page loads with a single HTTP response.
