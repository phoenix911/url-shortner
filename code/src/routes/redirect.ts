import { Hono } from 'hono'
import type { Context } from 'hono'
import { getLink, type Env } from '../lib/kv'

const redirect = new Hono<{ Bindings: Env }>()

const CACHE_TTL = 3600 // 1 hour — safe default since links don't change

function trackClick(c: Context<{ Bindings: Env }>, code: string) {
  if (!c.env.ANALYTICS) return
  const cf = (c.req.raw as { cf?: { country?: string } }).cf
  const country = cf?.country ?? 'XX'
  const referer = c.req.header('referer') ?? ''
  let refHost = ''
  try { refHost = referer ? new URL(referer).hostname : '' } catch { /* empty */ }
  c.executionCtx.waitUntil(
    Promise.resolve(c.env.ANALYTICS.writeDataPoint({ blobs: [country, refHost], doubles: [], indexes: [code] }))
  )
}

redirect.get('/:code', async (c) => {
  const code = c.req.param('code')
  const cache = caches.default
  const cacheKey = new Request(c.req.url)

  const cached = await cache.match(cacheKey)
  if (cached) {
    trackClick(c, code)
    const hit = new Response(cached.body, cached)
    hit.headers.set('cf-cache-status', 'HIT')
    return hit
  }

  const record = await getLink(c.env, code)

  if (!record) {
    const body = `<!doctype html><html><head><title>Not Found</title></head><body style="font-family:sans-serif;text-align:center;padding:4rem"><h1>404</h1><p>Short link <code>${code}</code> not found.</p><a href="/create">Create one</a></body></html>`
    // Cache 404s briefly so a hammered bad code doesn't spam KV
    const res = new Response(body, {
      status: 404,
      headers: {
        'Content-Type': 'text/html;charset=UTF-8',
        'Cache-Control': 'public, max-age=60',
      },
    })
    c.executionCtx.waitUntil(cache.put(cacheKey, res.clone()))
    return res
  }

  // Cap cache TTL at remaining link lifetime so we never serve an expired link from cache
  let ttl = CACHE_TTL
  if (record.expiresAt) {
    const remaining = Math.floor((new Date(record.expiresAt).getTime() - Date.now()) / 1000)
    ttl = Math.min(CACHE_TTL, Math.max(remaining, 0))
  }

  trackClick(c, code)
  const res = new Response(`Redirecting to ${record.url}`, {
    status: 301,
    headers: {
      Location: record.url,
      'Content-Type': 'text/plain',
      'Cache-Control': `public, max-age=${ttl}`,
    },
  })
  c.executionCtx.waitUntil(cache.put(cacheKey, res.clone()))
  return res
})

export default redirect
