import { Hono } from 'hono'
import { getCookie } from 'hono/cookie'
import { verifySession, SESSION_COOKIE } from '../middleware/auth'
import type { Env } from '../lib/kv'
import html from '../pages/dashboard.html'

const dashboard = new Hono<{ Bindings: Env }>()

dashboard.get('/dashboard', async (c) => {
  const token = getCookie(c, SESSION_COOKIE)
  const authed = token && (await verifySession(c.env.ADMIN_PASSWORD, token))
  if (!authed) return c.redirect('/create?login=1', 302)
  return c.html(html as string)
})

export default dashboard
