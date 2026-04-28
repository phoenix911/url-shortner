export interface LinkRecord {
  url: string
  createdAt: string
  expiresAt: string | null
}

export interface Env {
  LINKS: KVNamespace
  ANALYTICS?: AnalyticsEngineDataset
  ADMIN_PASSWORD: string
  SITE_DOMAIN: string
  CF_ACCOUNT_ID?: string
  CF_API_TOKEN?: string
  CF_ZONE_ID?: string
}

export async function getLink(env: Env, code: string): Promise<LinkRecord | null> {
  const raw = await env.LINKS.get(code)
  if (!raw) return null
  return JSON.parse(raw) as LinkRecord
}

export async function linkExists(env: Env, code: string): Promise<boolean> {
  const val = await env.LINKS.get(code)
  return val !== null
}

export async function setLink(
  env: Env,
  code: string,
  url: string,
  ttlSeconds: number | null,
): Promise<LinkRecord> {
  const now = new Date().toISOString()
  const expiresAt = ttlSeconds ? new Date(Date.now() + ttlSeconds * 1000).toISOString() : null
  const record: LinkRecord = { url, createdAt: now, expiresAt }
  const opts = ttlSeconds ? { expirationTtl: ttlSeconds } : {}
  await env.LINKS.put(code, JSON.stringify(record), opts)
  return record
}
