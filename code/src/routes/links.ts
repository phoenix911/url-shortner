import { Hono } from 'hono'
import { requireApiAuth } from '../middleware/auth'
import { generateSlug } from '../lib/generate'
import { getLink, linkExists, setLink, type Env } from '../lib/kv'
import { isValidSlug, isValidUrl, parseTtl } from '../lib/validate'

const links = new Hono<{ Bindings: Env }>()

links.use('/api/links/*', requireApiAuth)

/** POST /api/links — create a short link */
links.post('/api/links', async (c) => {
  let body: { url?: string; code?: string; ttlDays?: number }
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'Invalid JSON body.' }, 400)
  }

  const longUrl = String(body.url ?? '').trim()
  if (!isValidUrl(longUrl)) {
    return c.json({ error: 'Invalid URL. Must start with http:// or https://' }, 400)
  }

  let code = String(body.code ?? '').trim()
  if (code) {
    const slugCheck = isValidSlug(code)
    if (!slugCheck.ok) return c.json({ error: slugCheck.error }, 400)
    if (await linkExists(c.env, code)) {
      return c.json({ error: `Short code "${code}" is already taken.` }, 409)
    }
  } else {
    for (let i = 0; i < 5; i++) {
      const candidate = generateSlug()
      if (!(await linkExists(c.env, candidate))) {
        code = candidate
        break
      }
    }
    if (!code) return c.json({ error: 'Could not generate a unique code. Try again.' }, 500)
  }

  const ttlSeconds = parseTtl(body.ttlDays != null ? String(body.ttlDays) : null)
  const record = await setLink(c.env, code, longUrl, ttlSeconds)
  const domain = c.env.SITE_DOMAIN || 'your-domain.com'
  const shortUrl = `https://${domain}/${code}`

  return c.json({ code, shortUrl, url: record.url, createdAt: record.createdAt, expiresAt: record.expiresAt }, 201)
})

/** GET /api/links/:code — fetch link metadata */
links.get('/api/links/:code', async (c) => {
  const code = c.req.param('code')
  const record = await getLink(c.env, code)
  if (!record) return c.json({ error: 'not found' }, 404)
  return c.json({ code, ...record })
})

export default links
