import type { Context, Next } from 'hono'
import { getCookie, setCookie } from 'hono/cookie'
import type { Env } from '../lib/kv'

const SESSION_COOKIE = '__session'
const SESSION_MAX_AGE = 8 * 60 * 60 // 8 hours in seconds

async function signSession(password: string, timestamp: number): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(password),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const data = new TextEncoder().encode(String(timestamp))
  const sig = await crypto.subtle.sign('HMAC', key, data)
  const hex = Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
  return `${timestamp}.${hex}`
}

async function verifySession(password: string, token: string): Promise<boolean> {
  const parts = token.split('.')
  if (parts.length !== 2) return false
  const timestamp = parseInt(parts[0], 10)
  if (isNaN(timestamp)) return false
  if (Date.now() - timestamp > SESSION_MAX_AGE * 1000) return false
  const expected = await signSession(password, timestamp)
  return expected === token
}

export async function createSessionToken(password: string): Promise<string> {
  return signSession(password, Date.now())
}

/** Middleware: require valid session cookie or redirect to /create?login=1 */
export async function requireWebAuth(c: Context<{ Bindings: Env }>, next: Next) {
  const token = getCookie(c, SESSION_COOKIE)
  if (token && (await verifySession(c.env.ADMIN_PASSWORD, token))) {
    return next()
  }
  return c.redirect('/create?login=1', 302)
}

/** Middleware: require Bearer token matching ADMIN_PASSWORD */
export async function requireApiAuth(c: Context<{ Bindings: Env }>, next: Next) {
  const auth = c.req.header('Authorization') ?? ''
  const bearer = auth.startsWith('Bearer ') ? auth.slice(7) : ''
  if (bearer && bearer === c.env.ADMIN_PASSWORD) {
    return next()
  }
  return c.json({ error: 'Unauthorized' }, 401)
}

export { SESSION_COOKIE, SESSION_MAX_AGE, verifySession }
export { setCookie }
