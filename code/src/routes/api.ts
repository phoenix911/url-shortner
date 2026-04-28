import { Hono } from 'hono'
import { getCookie, setCookie } from 'hono/cookie'
import { generateSlug } from '../lib/generate'
import { getLink, linkExists, setLink, type Env, type LinkRecord } from '../lib/kv'
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

/** GET /api/links — list all links (session auth) */
api.get('/api/links', async (c) => {
  const sessionToken = getCookie(c, SESSION_COOKIE)
  const authed = sessionToken && (await verifySession(c.env.ADMIN_PASSWORD, sessionToken))
  if (!authed) return c.json({ error: 'Unauthorized' }, 401)

  const list = await c.env.LINKS.list()
  const records = await Promise.all(
    list.keys.map(async ({ name }) => {
      const record = await getLink(c.env, name)
      return record ? ({ code: name, ...record } as { code: string } & LinkRecord) : null
    }),
  )
  const links = records.filter((r): r is { code: string } & LinkRecord => r !== null)
  return c.json({ links, total: links.length })
})

// Maps Cloudflare country names → ISO 3166-1 alpha-2 codes for flag display
const COUNTRY_CODE: Record<string, string> = {
  'United States': 'US', 'India': 'IN', 'United Kingdom': 'GB', 'Germany': 'DE',
  'France': 'FR', 'Canada': 'CA', 'Australia': 'AU', 'Brazil': 'BR', 'Japan': 'JP',
  'China': 'CN', 'South Korea': 'KR', 'Netherlands': 'NL', 'Russia': 'RU',
  'Spain': 'ES', 'Italy': 'IT', 'Singapore': 'SG', 'Mexico': 'MX', 'Indonesia': 'ID',
  'Poland': 'PL', 'Turkey': 'TR', 'Sweden': 'SE', 'Switzerland': 'CH', 'Belgium': 'BE',
  'Argentina': 'AR', 'Thailand': 'TH', 'Vietnam': 'VN', 'Ukraine': 'UA', 'Norway': 'NO',
  'Denmark': 'DK', 'Finland': 'FI', 'Portugal': 'PT', 'Czech Republic': 'CZ',
  'Romania': 'RO', 'Hungary': 'HU', 'Austria': 'AT', 'Malaysia': 'MY',
  'Philippines': 'PH', 'Pakistan': 'PK', 'Bangladesh': 'BD', 'South Africa': 'ZA',
  'Nigeria': 'NG', 'Egypt': 'EG', 'Israel': 'IL', 'United Arab Emirates': 'AE',
  'Saudi Arabia': 'SA', 'Hong Kong': 'HK', 'Taiwan': 'TW', 'New Zealand': 'NZ',
  'Ireland': 'IE', 'Greece': 'GR', 'Colombia': 'CO', 'Chile': 'CL', 'Kenya': 'KE',
  'Morocco': 'MA', 'Croatia': 'HR', 'Slovakia': 'SK', 'Bulgaria': 'BG', 'Serbia': 'RS',
}

/** GET /api/links/:code/stats — real hit counts via Zone Analytics (or AE fallback) */
api.get('/api/links/:code/stats', async (c) => {
  const sessionToken = getCookie(c, SESSION_COOKIE)
  const authed = sessionToken && (await verifySession(c.env.ADMIN_PASSWORD, sessionToken))
  if (!authed) return c.json({ error: 'Unauthorized' }, 401)

  const code = c.req.param('code')
  const safeCode = code.replace(/[^a-zA-Z0-9_-]/g, '')

  if (!c.env.CF_API_TOKEN) {
    return c.json({ error: 'Analytics not configured. Set CF_ZONE_ID and CF_API_TOKEN secrets.' }, 503)
  }

  // ── Zone Analytics (real hits including CDN cache) ──
  if (c.env.CF_ZONE_ID) {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
    const until = new Date().toISOString()
    const query = `{
      viewer {
        zones(filter: {zoneTag: "${c.env.CF_ZONE_ID}"}) {
          httpRequestsAdaptiveGroups(
            limit: 100
            orderBy: [count_DESC]
            filter: { clientRequestPath: "/${safeCode}", datetime_geq: "${since}", datetime_leq: "${until}" }
          ) {
            count
            dimensions { clientCountryName }
          }
        }
      }
    }`

    const res = await fetch('https://api.cloudflare.com/client/v4/graphql', {
      method: 'POST',
      headers: { Authorization: `Bearer ${c.env.CF_API_TOKEN}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ query }),
    })

    if (!res.ok) return c.json({ error: 'Analytics query failed.' }, 502)

    const json = (await res.json()) as {
      data?: { viewer?: { zones?: Array<{ httpRequestsAdaptiveGroups: Array<{ count: number; dimensions: { clientCountryName: string } }> }> } }
      errors?: Array<{ message: string }>
    }

    if (json.errors?.length) return c.json({ error: json.errors[0].message }, 502)

    const rows = json.data?.viewer?.zones?.[0]?.httpRequestsAdaptiveGroups ?? []
    const total = rows.reduce((sum, r) => sum + r.count, 0)

    return c.json({
      code,
      total,
      source: 'zone',
      countries: rows.map((r) => {
        const name = r.dimensions.clientCountryName || 'Unknown'
        const country = COUNTRY_CODE[name] ?? name.slice(0, 2).toUpperCase()
        const clicks = r.count
        return { country, name, clicks, pct: total > 0 ? Math.round((clicks / total) * 1000) / 10 : 0 }
      }),
    })
  }

  // ── Analytics Engine fallback (Worker invocations only) ──
  if (!c.env.CF_ACCOUNT_ID) {
    return c.json({ error: 'Analytics not configured. Set CF_ZONE_ID and CF_API_TOKEN secrets.' }, 503)
  }

  const sql = `SELECT blob1 as country, count() as clicks FROM analytics_events WHERE index1 = '${safeCode}' GROUP BY country ORDER BY clicks DESC LIMIT 30`
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${c.env.CF_ACCOUNT_ID}/analytics_engine/sql`,
    { method: 'POST', headers: { Authorization: `Bearer ${c.env.CF_API_TOKEN}`, 'Content-Type': 'text/plain' }, body: sql },
  )

  if (!res.ok) return c.json({ error: 'Analytics query failed.' }, 502)

  const data = (await res.json()) as { data: Array<{ country: string; clicks: string }> }
  const rows = data.data ?? []
  const total = rows.reduce((sum, r) => sum + Number(r.clicks), 0)

  return c.json({
    code,
    total,
    source: 'worker',
    countries: rows.map((r) => ({
      country: r.country || 'XX',
      name: r.country || 'Unknown',
      clicks: Number(r.clicks),
      pct: total > 0 ? Math.round((Number(r.clicks) / total) * 1000) / 10 : 0,
    })),
  })
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
