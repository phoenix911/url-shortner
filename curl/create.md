# API — curl reference

Base URL: `https://your-domain.com`  
Auth: `Authorization: Bearer <ADMIN_PASSWORD>`

---

## Create a short link

### Auto-generated slug, default TTL (365 days)
```bash
curl -X POST https://your-domain.com/api/links \
  -H "Authorization: Bearer YOUR_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/your/long/url"}'
```

### Custom slug
```bash
curl -X POST https://your-domain.com/api/links \
  -H "Authorization: Bearer YOUR_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/your/long/url", "code": "myslug"}'
```

### Custom slug + custom TTL (30 days)
```bash
curl -X POST https://your-domain.com/api/links \
  -H "Authorization: Bearer YOUR_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/your/long/url", "code": "myslug", "ttlDays": 30}'
```

### Never expire (ttlDays: 0)
```bash
curl -X POST https://your-domain.com/api/links \
  -H "Authorization: Bearer YOUR_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/your/long/url", "ttlDays": 0}'
```

**Response `201`**
```json
{
  "code": "myslug",
  "shortUrl": "https://your-domain.com/myslug",
  "url": "https://example.com/your/long/url",
  "createdAt": "2026-04-26T12:00:00.000Z",
  "expiresAt": "2026-05-26T12:00:00.000Z"
}
```

---

## Fetch link metadata

```bash
curl https://your-domain.com/api/links/myslug \
  -H "Authorization: Bearer YOUR_PASSWORD"
```

**Response `200`**
```json
{
  "code": "myslug",
  "url": "https://example.com/your/long/url",
  "createdAt": "2026-04-26T12:00:00.000Z",
  "expiresAt": "2026-05-26T12:00:00.000Z"
}
```

**Response `404`**
```json
{ "error": "not found" }
```

---

## Error responses

| Status | Meaning |
|--------|---------|
| `400` | Invalid URL or slug (check `error` field for details) |
| `401` | Missing or wrong Bearer token |
| `409` | Slug already taken — choose a different `code` |
| `500` | Could not generate a unique slug after 5 tries (rare) |

---

## Request body fields

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `url` | string | yes | — | Must start with `http://` or `https://` |
| `code` | string | no | auto (6 chars) | Min 4, max 32 chars · `[a-zA-Z0-9-_]` |
| `ttlDays` | number | no | 365 | Days until expiry · `0` = never expire · max 3650 |
