# Lesson 09 — Views and Window Functions

**Module 3 · Querying relational data**

> **By the end of this lesson you should be able to:** save a query as a reusable **view** and query it like a table; understand that a view is virtual (recomputed each time) while a **materialized view** is a stored snapshot you must `REFRESH`; and use **window functions** to compute a value *across a set of rows related to the current row* — ranking, running totals, per-group comparisons — **without collapsing the rows**, which is the one thing `GROUP BY` could never do. This closes Module 3: we have now read the storefront every way there is.

---

## 1. Views: name a query, reuse it

Lessons 07 and 08 kept rewriting the same careful reports — per-game ratings, per-game revenue — each time taking care not to inflate them. A **view** saves that query under a name:

```sql
CREATE VIEW game_ratings AS
SELECT g.game_id, g.title,
       count(r.review_id)      AS n_reviews,
       round(avg(r.rating), 2) AS avg_rating
FROM games g
LEFT JOIN reviews r ON r.game_id = g.game_id
GROUP BY g.game_id, g.title;
```

Now it is used exactly like a table:

```sql
SELECT * FROM game_ratings
WHERE n_reviews > 0
ORDER BY avg_rating DESC;
```

A view is **virtual**: it stores no data, only the query text. Every time you select from it, PostgreSQL runs the underlying query against the current tables — so a view is always up to date, and costs the same as running that query by hand. Views exist for **encapsulation and reuse**: give the inflation-safe report one correct definition, and everyone selects from it instead of re-deriving (and re-breaking) it. `setup.sql` for this stage ships `game_ratings` and `game_revenue` as first-class schema objects.

> **Updatable views (brief).** A simple view over one table with no aggregation can sometimes accept `INSERT`/`UPDATE`. But a view with `GROUP BY`, joins, or aggregates — like `game_ratings` — is **read-only**: there is no unambiguous way to turn "change this average" back into row changes. Treat views as reporting tools unless you deliberately design a simple updatable one.

### Materialized views: a stored snapshot

A **materialized view** runs its query *once* and stores the result on disk:

```sql
CREATE MATERIALIZED VIEW game_ratings_mv AS SELECT * FROM game_ratings;
```

Selecting from it just reads the stored rows — fast, no recomputation. The catch: it does **not** track changes to the base tables. Insert a new review and the plain view reflects it immediately, but the materialized view keeps its old numbers until you explicitly rebuild it:

```sql
REFRESH MATERIALIZED VIEW game_ratings_mv;
```

So a materialized view trades **freshness for speed** — exactly the *derived-vs-stored* trade-off flagged back in lesson 05 (the `order_total` question) and central to Module 6. Use a plain view by default; reach for a materialized one only when the query is expensive and slightly stale data is acceptable.

| | Plain view | Materialized view |
|---|---|---|
| Stores data? | No (query only) | Yes (on disk) |
| Always current? | Yes | No — stale until `REFRESH` |
| Cost to read | Re-runs the query | Reads stored rows (cheap) |
| Use when | Correctness/reuse; cheap query | Expensive query, staleness tolerable |

---

## 2. Window functions: summaries that keep the rows

`GROUP BY` answers "one number *per group*" by **collapsing** each group to a single row. But we keep wanting the summary *beside each original row* — each review next to its game's average, each game's rank within its developer. Lesson 08 could only approximate this with correlated subqueries. A **window function** does it directly: it computes over a set of rows (a "window") *related to the current row*, and **returns one value per row — the rows are not collapsed**.

The syntax is any aggregate (or a ranking function) followed by an `OVER (…)` clause:

```sql
SELECT g.title, r.rating,
       round(avg(r.rating) OVER (PARTITION BY r.game_id), 2) AS game_avg
FROM reviews r
JOIN games g ON g.game_id = r.game_id
ORDER BY g.title, r.reviewed_on;
```

| title | rating | game_avg |
|---|---|---|
| Cyberpunk 2077 | 2 | 3.00 |
| Cyberpunk 2077 | 4 | 3.00 |
| Cyberpunk 2077 | 3 | 3.00 |
| Hades | 5 | 4.67 |
| Hades | 4 | 4.67 |
| Hades | 5 | 4.67 |

All **11 reviews remain** — each shows its own `rating` *and* its game's average beside it. `GROUP BY game_id` would have collapsed Cyberpunk's three reviews into one row and lost the individual ratings; you'd have to join the grouped result back to the reviews to recover them. The window function does both in one pass. **`OVER` is the signal: "aggregate, but don't collapse."**

### The `OVER` clause: `PARTITION BY` and `ORDER BY`

```
func(...) OVER (PARTITION BY <cols>   ORDER BY <cols>)
                └ split rows into     └ order within each
                  independent windows   window (for ranking,
                  (like GROUP BY, but    running totals, LAG/LEAD)
                  rows survive)
```

- **`PARTITION BY`** divides rows into groups the function restarts on. Omit it and the whole result is one window.
- **`ORDER BY`** (inside `OVER`) orders rows within each partition — required by ranking functions and by running totals.

---

## 3. Ranking within groups

The headline competence of this module ("rank results within groups"). Three ranking functions differ only in how they treat **ties**:

| Function | Ties get | After a tie, the next rank |
|---|---|---|
| `row_number()` | distinct numbers (arbitrary among equals) | continues (1,2,3,4,5) |
| `rank()` | the **same** number | **skips** (1,2,2,4,5) |
| `dense_rank()` | the **same** number | **does not skip** (1,2,2,3,4) |

Ranking the rated games by average (Portal 2 and The Witcher 3 both average 4.50; Cyberpunk and Minecraft both 3.00):

```sql
SELECT title, avg_rating,
       row_number() OVER w AS rn,
       rank()       OVER w AS rnk,
       dense_rank() OVER w AS drnk
FROM game_ratings
WHERE n_reviews > 0
WINDOW w AS (ORDER BY avg_rating DESC);
```

| title | avg_rating | rn | rnk | drnk |
|---|---|---|---|---|
| Hades | 4.67 | 1 | 1 | 1 |
| Portal 2 | 4.50 | 2 | 2 | 2 |
| The Witcher 3 | 4.50 | 3 | **2** | 2 |
| Cyberpunk 2077 | 3.00 | 4 | **4** | **3** |
| Minecraft | 3.00 | 5 | 4 | 3 |

Read the tie at 4.50: `row_number` picks 2 and 3 arbitrarily (a coin toss — don't rely on it for tied rows); `rank` gives both 2 then jumps to 4 (it "used up" rank 3); `dense_rank` gives both 2 then continues at 3. Choose by intent: *"the 2nd-best distinct score"* → `dense_rank`; *"an Olympic-style standing with gaps"* → `rank`; *"an arbitrary unique sequence number"* → `row_number`.

> The `WINDOW w AS (…)` clause names a window so several functions can share it — tidier than repeating `OVER (ORDER BY avg_rating DESC)` three times.

"Top-rated game **per developer**" adds `PARTITION BY`:

```sql
SELECT d.name AS developer, gr.title, gr.avg_rating,
       rank() OVER (PARTITION BY g.developer_id ORDER BY gr.avg_rating DESC) AS rnk
FROM game_ratings gr
JOIN games g      ON g.game_id = gr.game_id
JOIN developers d ON d.developer_id = g.developer_id
WHERE gr.n_reviews > 0
ORDER BY d.name, rnk;
```

The rank **restarts at 1 for each developer**. CD Projekt Red's Witcher (4.50) is rank 1, Cyberpunk (3.00) rank 2; every other developer's reviewed game is its own rank 1. To keep only each developer's best, wrap this in a subquery/CTE and filter `WHERE rnk = 1` — a window function cannot go in `WHERE` (it is computed *after* `WHERE`, like aggregates), so you filter it one level out.

---

## 4. Running totals and neighbour access (`LAG`/`LEAD`)

With `ORDER BY` inside `OVER`, an aggregate becomes a **running** (cumulative) one — it accumulates over the rows up to and including the current one:

```sql
-- ivan's cumulative spend over time
SELECT p.purchased_at::date AS d,
       order_total,
       sum(order_total) OVER (ORDER BY p.purchased_at) AS running_total
FROM ( /* per-purchase totals for user 1 */ ) ...
```

| d | order_total | running_total |
|---|---|---|
| 2021-01-05 | 74.98 | 74.98 |
| 2023-06-20 | 11.99 | 86.97 |
| 2024-07-04 | 36.98 | 123.95 |

The running total climbs to ivan's lifetime spend (€123.95 — matching lesson 07). The window here is "all rows from the start up to this one", which is what adding `ORDER BY` to a windowed aggregate means by default.

`lag()` and `lead()` reach to the **previous** / **next** row in the ordered window — ideal for "change since last time":

```sql
-- Cyberpunk's review ratings over time, and the change vs. the previous review
SELECT r.reviewed_on, r.rating,
       lag(r.rating)  OVER (ORDER BY r.reviewed_on) AS prev_rating,
       r.rating - lag(r.rating) OVER (ORDER BY r.reviewed_on) AS delta
FROM reviews r JOIN games g ON g.game_id = r.game_id
WHERE g.title = 'Cyberpunk 2077'
ORDER BY r.reviewed_on;
```

Cyberpunk went 2 → 4 (`delta +2`, the post-patch recovery) → 3 (`delta −1`). The first row's `prev_rating` is `NULL` — there is no previous row — our old friend from lesson 02, appearing naturally at a window's edge.

---

## 5. Window vs. `GROUP BY` — the distinction to keep

| | `GROUP BY` | Window function (`OVER`) |
|---|---|---|
| Row count | **Collapses** each group to one row | **Keeps** every input row |
| Output | One summary per group | Per-row value computed over a window |
| Use for | Totals, counts, "one number per group" | Ranks, running totals, per-row comparisons, `LAG`/`LEAD` |

They compose: window functions often run *over a view that already did the `GROUP BY`* (as the ranking queries above run over `game_ratings`). Collapse first for the per-group fact, then window to rank or compare — layered exactly as Module 3 has built up.

---

## Key terms

- **View** — a named, virtual query; always current; used like a table; read-only when it aggregates/joins.
- **Materialized view** — a stored snapshot; fast to read but stale until `REFRESH` (freshness-vs-speed).
- **Window function** — `func(...) OVER (...)`: a value per row computed over related rows, **without collapsing**.
- **`PARTITION BY` / `ORDER BY` (in `OVER`)** — split rows into windows / order them within each.
- **`row_number` / `rank` / `dense_rank`** — unique / gap-on-tie / no-gap-on-tie ranking.
- **`LAG` / `LEAD`** — read the previous / next row in the ordered window.

## Common misconceptions this lesson targets

1. *"A view stores its data."* — A plain view stores only the query; it recomputes every read. A *materialized* view stores rows and goes stale.
2. *"A window function is just `GROUP BY`."* — `GROUP BY` collapses; a window keeps every row and adds a computed column.
3. *"`rank` and `dense_rank` are the same."* — Only without ties. `rank` skips after a tie; `dense_rank` does not.
4. *"Filter the top-per-group with `WHERE rnk = 1`."* — Windows are computed after `WHERE`; filter them one level out (subquery/CTE).
5. *"A materialized view updates itself."* — No; you must `REFRESH` it.

---

**Next:** Lesson 10 — *Transactions and ACID boundaries* (Module 4). We have read the storefront exhaustively; now we **change** it safely. The "select-first" habit from Module 1 becomes real atomic transactions — all-or-nothing updates, rollback, and savepoints — before Module 4's second lesson puts two users in a race for the last copy.
