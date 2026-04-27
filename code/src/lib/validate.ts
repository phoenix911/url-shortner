const SLUG_RE = /^[a-zA-Z0-9_-]+$/

export function isValidUrl(raw: string): boolean {
  try {
    const u = new URL(raw)
    return u.protocol === 'http:' || u.protocol === 'https:'
  } catch {
    return false
  }
}

export function isValidSlug(slug: string): { ok: boolean; error?: string } {
  if (slug.length < 4) return { ok: false, error: 'Short code must be at least 4 characters.' }
  if (slug.length > 32) return { ok: false, error: 'Short code must be at most 32 characters.' }
  if (!SLUG_RE.test(slug)) return { ok: false, error: 'Short code may only contain letters, numbers, hyphens, and underscores.' }
  return { ok: true }
}

/** Returns seconds until expiry, or null for no expiry. Defaults to 365 days. */
export function parseTtl(raw: string | null | undefined): number | null {
  if (raw === null || raw === undefined || raw === '') return 365 * 86400
  const n = parseInt(raw, 10)
  if (isNaN(n) || n < 0) return 365 * 86400
  if (n === 0) return null
  const days = Math.min(n, 3650)
  return days * 86400
}
