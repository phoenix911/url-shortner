# Cost Analysis

## Assumptions

| Parameter | Value |
|-----------|-------|
| Predefined links | 12 fixed, no new creation |
| KV writes | 0 |
| CDN Cache Rule | Active |
| Cache TTL | 1 hour |
| Cloudflare PoPs globally | ~300 |

---

## How Worker invocations are bounded by cache

With CDN Cache Rule active, the Worker is only hit on a cache **miss** — once per PoP per hour. This means Worker invocations do **not** scale with traffic. They are capped by:

```
Max Worker invocations = Active PoPs x 24h x links
Absolute ceiling       = 300 PoPs x 24 x 12 links = 86,400 / day = 2.6M / month
Free tier allows       = 3,000,000 / month
```

---

## Cost table — 12 fixed links, no creation

| Hits / day | Hits / month | Active PoPs | Miss rate | Worker invocations / month | KV reads / month | Free tier | Cost / month |
|-----------|-------------|-------------|-----------|---------------------------|-----------------|-----------|-------------|
| 100 | 3,000 | ~5 | ~80% | ~2,400 | ~2,400 | YES | **$0** |
| 1,000 | 30,000 | ~15 | ~40% | ~12,000 | ~12,000 | YES | **$0** |
| 10,000 | 300,000 | ~30 | ~10% | ~30,000 | ~30,000 | YES | **$0** |
| 100,000 | 3,000,000 | ~80 | ~2% | ~60,000 | ~60,000 | YES | **$0** |
| 1,000,000 | 30,000,000 | ~200 | ~0.5% | ~150,000 | ~150,000 | YES | **$0** |
| 10,000,000 | 300,000,000 | ~280 | ~0.08% | ~250,000 | ~250,000 | YES | **$0** |
| 100,000,000 | 3,000,000,000 | ~300 (max) | ~0.009% | ~300,000 | ~300,000 | YES | **$0** |

---

## Why 100M hits/day still costs $0

```
100M hits/day, 300 PoPs, 12 links

CDN serves  :  99,913,600 hits  (no Worker, no KV)
Worker sees :      86,400 hits  (cache miss, one per PoP per hour)

Monthly Worker invocations = 86,400 x 30 = 2,592,000
Free tier limit            =              3,000,000
                                          ---------
                             408,000 requests to spare
```

---

## Cache miss rate vs traffic volume

```
Hits / day      Miss rate     Reason
────────────────────────────────────────────────────────
100             ~80%          Caches rarely warm, low volume
1,000           ~40%          Some PoPs warming up
10,000          ~10%          Most active PoPs stay warm
100,000         ~2%           All active PoPs warm
1,000,000       ~0.5%         Near maximum cache efficiency
10,000,000      ~0.08%        Practically all CDN
100,000,000     ~0.009%       CDN handles everything
```

The higher the traffic, the more efficient the cache.

---

## What if Cache Rule is disabled?

| Hits / day | Cache Rule ON | Cache Rule OFF |
|-----------|--------------|----------------|
| 100 | $0 | $0 |
| 100,000 | $0 | $0 |
| 1,000,000 | $0 | $5 / month |
| 10,000,000 | $0 | $50 / month |
| 100,000,000 | $0 | **$1,495 / month** |

The Cache Rule is the single most important cost control in this stack.

---

## Storage (fixed, one-time)

```
12 links x 200 bytes = 2,400 bytes = 0.002 MB
Free tier            = 1 GB
Usage                = 0.0002%   →   effectively zero
```

---

## Summary

- **Every traffic level from 100 to 100M hits/day = $0/month**
- Worker invocations are physically capped at 2.6M/month regardless of traffic volume
- The CDN cache is the reason — not the Worker cache
- Disabling the Cache Rule at 100M hits/day = $1,495/month
- The only thing that would cost money is creating 1,000+ new links/day
