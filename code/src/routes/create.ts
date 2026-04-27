import { Hono } from 'hono'
import { getCookie } from 'hono/cookie'
import { verifySession, SESSION_COOKIE } from '../middleware/auth'
import type { Env } from '../lib/kv'
import html from '../pages/create.html'

const create = new Hono<{ Bindings: Env }>()

create.get('/create', async (c) => {
  const token = getCookie(c, SESSION_COOKIE)
  const authed = token && (await verifySession(c.env.ADMIN_PASSWORD, token))

  // If not authenticated, inject ?login=1 so the page JS shows the login form
  if (!authed) {
    const modifiedHtml = (html as string).replace(
      "const params = new URLSearchParams(location.search);",
      "const params = new URLSearchParams('login=1');",
    )
    return c.html(modifiedHtml)
  }

  return c.html(html as string)
})

export default create
