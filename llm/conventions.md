---
title: Conventions
---

# Code Conventions

## TypeScript

- Strict mode enabled (`"strict": true` in tsconfig)
- All Cloudflare bindings typed via the `Env` interface in `src/lib/kv.ts` — import it in every route/middleware file
- No `any` — prefer `unknown` + type narrowing

## Hono patterns

- Each route group is its own `Hono<{ Bindings: Env }>` instance exported as `default`
- Mounted in `src/index.ts` via `app.route('/', routeModule)`
- Context type: `c: Context<{ Bindings: Env }>`

## Error responses

All JSON errors follow the shape `{ "error": "<message>" }`.

HTTP status conventions:
- `400` — validation failure (bad input)
- `401` — missing or invalid auth
- `404` — resource not found
- `409` — slug collision
- `500` — internal / unexpected failure

## KV keys

- Short link records: `<slug>` (e.g. `xk92mP`)
- No prefix namespacing needed — only one record type in this KV namespace

## Slug format

`[a-zA-Z0-9_-]`, min 4 chars, max 32 chars. Auto-generated slugs are 6 chars, alphanumeric only (`[a-zA-Z0-9]`).

## Session cookie

Name: `__session`  
Format: `<unix-ms-timestamp>.<hmac-hex>`  
Max-age: 8 hours  
Flags: `HttpOnly; Secure; SameSite=Strict; Path=/`

## HTML template

`src/pages/create.html` is imported as a raw string by Wrangler's module system. It contains all CSS and JS inline — no external requests from the page. The server-side `create.ts` route may do a string replacement to inject initial state before serving.
