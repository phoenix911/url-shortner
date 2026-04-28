import { Hono } from 'hono'
import type { Env } from './lib/kv'
import createRoute from './routes/create'
import dashboardRoute from './routes/dashboard'
import apiRoute from './routes/api'
import linksRoute from './routes/links'
import redirectRoute from './routes/redirect'

const app = new Hono<{ Bindings: Env }>()

// Convenience redirects
app.get('/', (c) => c.redirect('/create', 302))
app.get('/link', (c) => c.redirect('/create', 302))

// Mounted routes
app.route('/', createRoute)
app.route('/', dashboardRoute)
app.route('/', apiRoute)
app.route('/', linksRoute)
app.route('/', redirectRoute)

export default app
