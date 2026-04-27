import { Hono } from 'hono'
import { getCookie, setCookie } from 'hono/cookie'
import { generateSlug } from '../lib/generate'
import { getLink, linkExists, setLink, type Env } from '../lib/kv'
import { isValidSlug, isValidUrl, parseTtl } from '../lib/validate'
import {
  SESSION_COOKIE,
  SESSION_MAX_AGE,
  createSessionToken,
  verifySession,
} from '../middleware/auth'

const api = new Hono<{ Bindings: Env }>()

/** POST /api/login — exchange password for session cookie */
api.post('/api/login', async (c) => {
  const body = await c.req.parseBody()
  const password = String(body['password'] ?? '')

  if (password !== c.env.ADMIN_PASSWORD) {
    return c.json({ error: 'Invalid password.' }, 401)
  }

  const token = await createSessionToken(password)
  setCookie(c, SESSION_COOKIE, token, {
    httpOnly: true,
    secure: true,
    sameSite: 'Strict',
    maxAge: SESSION_MAX_AGE,
    path: '/',
  })
  return c.json({ ok: true })
})

/** POST /api/shorten — web form create (requires session cookie) */
api.post('/api/shorten', async (c) => {
  const sessionToken = getCookie(c, SESSION_COOKIE)
  const authed = sessionToken && (await verifySession(c.env.ADMIN_PASSWORD, sessionToken))
  if (!authed) return c.json({ error: 'Unauthorized' }, 401)

  const body = await c.req.parseBody()
  const longUrl = String(body['url'] ?? '').trim()
  const customCode = String(body['code'] ?? '').trim()
  const ttlRaw = String(body['ttlDays'] ?? '').trim()

  if (!isValidUrl(longUrl)) {
    return c.json({ error: 'Invalid URL. Must start with http:// or https://' }, 400)
  }

  let code = customCode
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

  const ttl = parseTtl(ttlRaw)
  const record = await setLink(c.env, code, longUrl, ttl)
  const domain = c.env.SITE_DOMAIN || 'your-domain.com'
  const shortUrl = `https://${domain}/${code}`

  return c.json({ code, shortUrl, url: record.url, expiresAt: record.expiresAt }, 201)
})

/** GET /api/links/:code — fetch stored link (requires session) */
api.get('/api/links/:code', async (c) => {
  const sessionToken = getCookie(c, SESSION_COOKIE)
  const authed = sessionToken && (await verifySession(c.env.ADMIN_PASSWORD, sessionToken))
  if (!authed) return c.json({ error: 'Unauthorized' }, 401)

  const code = c.req.param('code')
  const record = await getLink(c.env, code)
  if (!record) return c.json({ error: 'not found' }, 404)
  return c.json({ code, ...record })
})

export default api
