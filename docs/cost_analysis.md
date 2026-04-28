[← Back to readme](../readme.md)

# Cost Analysis — 100 links created per day

## Assumptions

| Parameter                | Value              |
| ------------------------ | ------------------ |
| New links created        | 100 / day          |
| Link TTL                 | 365 days (default) |
| CDN Cache Rule           | Active             |
| Cache TTL                | 1 hour             |
| Cloudflare PoPs globally | ~300               |
| KV value size per link   | ~200 bytes         |

---

## Two cost drivers

With 100 links/day, costs come from two places — creation (fixed) and redirects (scales with traffic).

### 1. Link creation — fixed regardless of traffic

```
100 links/day × 30 days = 3,000 KV writes/month
                          3,000 Worker invocations/month (POST /api/links)

Free tier: 1,000,000 KV writes/month    →  3,000 used  (0.3%)
Free tier: 3,000,000 Worker req/month   →  3,000 used  (0.1%)
```

Creation alone never costs anything at 100 links/day.

### 2. Redirects — bounded by CDN cache, not traffic volume

With CDN Cache Rule active, the Worker only runs on a cache **miss** — once per PoP per hour per active link. After 30 days there are ~3,000 active links.

```
Worst case (all PoPs serve all links):
  3,000 links × 300 PoPs × 24 = 21,600,000 Worker invocations/day  ← unrealistic

Realistic (regional traffic, links spread across 10–20 PoPs on average):
  3,000 links × 15 PoPs × 24 = 1,080,000/day = 32,400,000/month    ← exceeds free tier

Concentrated traffic (popular links hit many PoPs, long-tail links hit few):
  Popular 10%  = 300 links × 100 PoPs × 24 =    172,800/day
  Long-tail 90%= 2,700 links × 3 PoPs × 24 =    194,400/day
  Total                                     =    367,200/day = 11,016,000/month  ← over free tier
```

**The Workers free tier (3M/month = 100K/day) is tight once you have thousands of active links and real traffic spread across PoPs.**

---

## Active link accumulation

Links expire after 365 days, so the count grows linearly for the first year:

| Age of deployment       | Active links | Max Worker invoc/day (15 PoPs) |
| ----------------------- | ------------ | ------------------------------ |
| Day 1                   | 100          | 36,000                         |
| Day 7                   | 700          | 252,000                        |
| Day 30                  | 3,000        | 1,080,000                      |
| Day 90                  | 9,000        | 3,240,000                      |
| Day 180                 | 18,000       | 6,480,000                      |
| Day 365                 | 36,500       | 13,140,000                     |
| Day 365+ (steady state) | ~36,500      | 13,140,000                     |

After ~90 days you will likely exceed the free tier for Worker invocations if links get traffic across multiple PoPs.

---

## Cost table — 100 links/day at varying redirect traffic

Monthly totals. Assumes steady state (~36,500 active links after 1 year).

| Redirect hits/day | Active PoPs avg | Worker invoc/month | KV reads/month | KV writes/month | Free tier   | Cost/month |
| ----------------- | --------------- | ------------------ | -------------- | --------------- | ----------- | ---------- |
| 1,000             | ~3              | ~2,628,000         | ~2,628,000     | 3,000           | YES (tight) | **$0**     |
| 10,000            | ~8              | ~7,008,000         | ~7,008,000     | 3,000           | NO          | **~$2**    |
| 100,000           | ~20             | ~17,520,000        | ~17,520,000    | 3,000           | NO          | **~$7**    |
| 1,000,000         | ~60             | ~52,560,000        | ~52,560,000    | 3,000           | NO          | **~$25**   |
| 10,000,000        | ~150            | ~131,400,000       | ~131,400,000   | 3,000           | NO          | **~$65**   |
| 100,000,000       | ~300            | ~262,800,000       | ~262,800,000   | 3,000           | NO          | **~$130**  |

> Worker invocations = 36,500 active links × active PoPs × 24h × 30 days  
> KV reads ≈ Worker invocations (one KV read per cache miss)  
> Cost = (Worker invoc − 3M) × $0.50/million + (KV reads − 10M) × $0.50/million

---

## How this compares to the fixed-link scenario

| Scenario                  | Worker invoc/month (at 100M hits/day) | Cost/month |
| ------------------------- | ------------------------------------- | ---------- |
| 12 fixed links (costs.md) | ~2,600,000                            | **$0**     |
| 100 links/day, 1 year old | ~262,800,000                          | **~$130**  |

The difference: 36,500 active links vs 12 fixed links. Each active link generates cache-miss Worker invocations across every PoP that serves it.

---

## Free tier survival guide

To stay on the free tier with 100 links/day:

| Strategy                                  | Effect                                                          |
| ----------------------------------------- | --------------------------------------------------------------- |
| Short TTL on link creation (e.g. 30 days) | Limits active link accumulation to ~3,000                       |
| Geo-restrict your domain to 1–2 regions   | Limits active PoPs to ~5–10                                     |
| Both combined                             | ~3,000 links × 8 PoPs × 24 × 30 = 17,280,000 invoc — still over |
| Reduce to 10 links/day                    | ~3,650 links/year (similar to 30-day TTL at 100/day)            |

**Honest answer:** 100 links/day with 365-day TTL and global traffic will exceed the free Worker tier within 30–90 days. The $5/month Workers Paid plan includes 10M requests/month and covers the majority of realistic workloads at this scale.

---

## Paid plan projection (Workers $5/month)

Paid tier: 10M requests/month included, then $0.50/million.

| Redirect hits/day | Extra Worker invoc/month | Extra cost | Total/month |
| ----------------- | ------------------------ | ---------- | ----------- |
| 1,000             | 0 (under 10M)            | $0         | **$5**      |
| 10,000            | 0 (under 10M)            | $0         | **$5**      |
| 100,000           | ~7.5M                    | ~$3.75     | **~$9**     |
| 1,000,000         | ~42.5M                   | ~$21       | **~$26**    |
| 10,000,000        | ~121M                    | ~$60       | **~$65**    |
| 100,000,000       | ~252M                    | ~$126      | **~$131**   |

KV reads ($0.50/million after first 10M) add roughly the same amount on top at high traffic volumes.

---

## Storage

```
100 links/day × 200 bytes × 365 days = ~7.3 MB at peak (all links alive)
Free tier                             = 1 GB
Usage                                 = 0.7%   →   effectively zero
```

Storage is never a cost concern at 100 links/day.

---

## Analytics Engine costs

Analytics Engine tracks click events (country + referrer) on every Worker invocation that results in a redirect. The cost model is separate from Workers and KV.

**Writes (data points ingested)**

Each redirect that reaches the Worker writes 1 data point. Worker invocations are already bounded by the CDN cache model above — so Analytics Engine writes ≤ Worker invocations.

| Traffic level | Worker invoc/month | Analytics writes/month | Free tier (100K/day = 3M/month) |
| ------------- | ------------------ | ---------------------- | ------------------------------- |
| 1,000 hits/day | ~2,628,000 | ~2,628,000 | YES (tight) |
| 10,000 hits/day | ~7,008,000 | ~7,008,000 | NO — ~$2.25 overage |
| 100,000 hits/day | ~17,520,000 | ~17,520,000 | NO — ~$7 overage |

> Analytics Engine overage: $0.25 per million data points written above 3M/month.  
> This adds roughly 50% on top of the Worker invocation cost at the same traffic level.

**Queries (dashboard stats)**

Each time you open link stats on the dashboard, 1 SQL query fires against Analytics Engine. These are admin-only, so at most a few hundred per month.

```
Free tier: 5,000,000 rows read/month
100 queries × 1,000 rows each = 100,000 rows/month   →   effectively zero
```

Query cost is always $0 for personal use.

**Summary for analytics:**

| Scenario               | Analytics write cost |
| ---------------------- | -------------------- |
| Personal (< 3M clicks) | **$0** |
| 10K hits/day           | **+~$2/month** |
| 100K hits/day          | **+~$7/month** |
| Note | Analytics writes always match Worker invocations — no extra traffic overhead |

---

## Summary

| Question                          | Answer                                             |
| --------------------------------- | -------------------------------------------------- |
| Creation cost at 100 links/day    | $0 always                                          |
| Storage cost                      | $0 always                                          |
| Analytics tracking                | $0 under 3M clicks/month; ~$2–7 above              |
| Free tier safe window             | ~30 days after first deploy                        |
| Break-even to paid plan           | $5/month covers most workloads                     |
| Cost at 100M redirects/day (paid) | ~$131/month                                        |
| Main cost driver                  | Active link count × PoPs × 24 — not traffic volume |
