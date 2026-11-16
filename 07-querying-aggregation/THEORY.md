# Lesson 07 — Aggregation, `GROUP BY`, `HAVING`

**Module 3 · Querying relational data**

> **By the end of this lesson you should be able to:** collapse many rows into one summary value with the aggregate functions `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`; form per-group summaries with `GROUP BY`; filter groups with `HAVING` and know why that is different from `WHERE`; predict how aggregates treat `NULL`; and — the headline — **diagnose an inflated `SUM` caused by a join** and fix it. This is where lesson 06's row multiplication comes back as a *wrong number*, not just extra rows.

---

## 1. From rows to summaries

Everything so far returned rows that already existed (`SELECT`, `WHERE`, joins). Reports ask a different kind of question: *how many*, *how much*, *on average*. An **aggregate function** reads a whole set of rows and returns **one** value.

```sql
SELECT count(*)            AS n_games,
       min(price_eur)      AS cheapest,
       max(price_eur)      AS dearest,
       round(avg(price_eur), 2) AS avg_price
FROM games;
```

One row comes back, no matter how many rows went in. The input rows are *collapsed*.

### The five workhorses

| Aggregate | Returns | Ignores `NULL`? |
|---|---|---|
| `count(*)` | number of rows | **no** — counts every row |
| `count(col)` | number of rows where `col IS NOT NULL` | **yes** |
| `count(DISTINCT col)` | number of distinct non-NULL values | yes |
| `sum(col)` | total of non-NULL values | yes |
| `avg(col)` | mean of non-NULL values | yes |
| `min(col)` / `max(col)` | smallest / largest non-NULL value | yes |

Remember from lesson 06: `count(*)` and `count(col)` differ exactly when `col` can be `NULL`. That distinction is about to do real work.

---

## 2. `GROUP BY`: one summary *per group*

A bare aggregate gives one answer for the whole table. Usually we want one answer *per* something — per game, per user, per developer. `GROUP BY` partitions the rows into groups sharing the same key, then applies the aggregate **once per group**.

```sql
-- reviews per game, and the average rating of each
SELECT g.title,
       count(r.review_id)        AS n_reviews,
       round(avg(r.rating), 2)   AS avg_rating
FROM games g
LEFT JOIN reviews r ON r.game_id = g.game_id
GROUP BY g.game_id, g.title
ORDER BY avg_rating DESC NULLS LAST, g.title;
```

| title | n_reviews | avg_rating |
|---|---|---|
| Hades | 3 | 4.67 |
| Portal 2 | 2 | 4.50 |
| The Witcher 3 | 2 | 4.50 |
| Cyberpunk 2077 | 3 | 3.00 |
| Minecraft | 1 | 3.00 |
| Hades II | 0 | *NULL* |
| Half-Life 2 | 0 | *NULL* |
| Untitled Project | 0 | *NULL* |

The `LEFT JOIN` keeps the three unreviewed games (lesson 06); each becomes its own group with `count(review_id) = 0` and `avg = NULL`. More on that `NULL` in §4.

### The iron rule of `GROUP BY`

> **Every column in `SELECT` must either appear in `GROUP BY` or be wrapped in an aggregate.**

PostgreSQL *enforces* this and rejects anything else:

```sql
-- ERROR: column "r.rating" must appear in the GROUP BY clause
--        or be used in an aggregate function
SELECT g.title, r.rating
FROM games g JOIN reviews r ON r.game_id = g.game_id
GROUP BY g.title;
```

Why is this an error and not a guess? Each group is **one** output row, but `r.rating` has *many* different values within the group — there is no single value to put in that one cell. The database refuses to pick one for you. You must tell it how to collapse those values (`avg`, `max`, …) or group by them.

> Grouping by `g.game_id` (the primary key) lets you list `g.title` too, because the PK **functionally determines** the title — a direct payoff of lesson 05's functional dependencies. PostgreSQL knows this and allows it. Grouping by a non-key column would still force you to aggregate everything else.

---

## 3. `WHERE` vs. `HAVING`: filter rows, then filter groups

Both filter, but at **different stages**:

```
          ┌─────────┐      ┌──────────┐      ┌──────────┐
  rows ──▶ │  WHERE  │ ──▶ │ GROUP BY │ ──▶ │  HAVING  │ ──▶ result
          │ per row │      │  groups  │      │per group │
          └─────────┘      └──────────┘      └──────────┘
          (pre-aggregate)                    (post-aggregate)
```

- **`WHERE`** runs *before* grouping. It filters individual rows and **cannot see aggregates** — the groups don't exist yet.
- **`HAVING`** runs *after* grouping. It filters whole groups and **can** reference aggregates.

"Games with at least two reviews":

```sql
SELECT g.title, count(*) AS n_reviews
FROM games g
JOIN reviews r ON r.game_id = g.game_id
GROUP BY g.game_id, g.title
HAVING count(*) >= 2          -- a group-level test; WHERE could not do this
ORDER BY n_reviews DESC, g.title;
```

| title | n_reviews |
|---|---|
| Cyberpunk 2077 | 3 |
| Hades | 3 |
| Portal 2 | 2 |
| The Witcher 3 | 2 |

The classic mistake is trying to put the aggregate in `WHERE`:

```sql
-- ERROR: aggregate functions are not allowed in WHERE
... WHERE count(*) >= 2 ...
```

It fails because `WHERE` is evaluated per row, before any counting has happened. Use `WHERE` to drop rows *before* they are grouped (e.g. `WHERE r.rating >= 4` to average only positive reviews), and `HAVING` to drop *groups* by their summary. They often appear together.

---

## 4. Aggregates and `NULL`

> **Every aggregate except `count(*)` skips `NULL` inputs.** This is lesson 02's three-valued logic as an arithmetic rule.

This is usually what you want, but it has sharp edges:

- `avg(rating)` over the unreviewed games is `NULL` — not `0`. There is no rating to average; the mean of *nothing* is unknown, not zero. (A store that showed unreviewed games as "average score 0" would be lying.)
- For `Half-Life 2` under the `LEFT JOIN` above, the join invented **one** all-`NULL` review row. So:
  - `count(*)` = **1** — it counts that phantom row;
  - `count(review_id)` = **0** — the key is `NULL`;
  - `avg(rating)` = `NULL`, `sum(rating)` = `NULL`.

This is why `count(r.review_id)` is the honest "number of reviews": it ignores the phantom row a `LEFT JOIN` manufactures. A naive `SUM(rating) / count(*)` would divide by that phantom and mislead. Reach for `count(*)` only when you truly mean "how many rows in this group", and for `count(col)` / `avg` when `NULL` should not count.

---

## 5. The headline: an inflated join makes an inflated `SUM`

Lesson 06 showed that joining two independent one-to-many relations **multiplies** rows. Back then it was "6 rows for one game". Now watch it corrupt a *total*.

The real revenue is the sum of what was actually paid — the `purchase_items` table alone:

```sql
SELECT sum(price_paid_eur) AS total_revenue   -- 285.90  (10 items)
FROM purchase_items;
```

Now a colleague wants "total revenue, broken down so we can see genres too", and joins `game_genres`:

```sql
-- WRONG: 681.78 — more than double the real revenue.
SELECT sum(pi.price_paid_eur) AS total_revenue
FROM purchase_items pi
JOIN game_genres gg ON gg.game_id = pi.game_id;
```

Every purchased game that has **two** genres had its price counted **twice**; a three-genre game (Cyberpunk) counted **three** times. The join turned 10 line items into 22 rows, and `SUM` dutifully added the duplicated prices. **The number is simply wrong** — and unlike lesson 06's visible extra rows, a single scalar total gives you nothing to eyeball. This is the module's named competence: *diagnose inflated totals after a join*.

### Why it happens, and how to fix it

The `game_genres` join has nothing to do with money; it exists only to attach genres, and in doing so it duplicates each priced row once per genre. Three robust fixes:

```sql
-- (a) Don't join what you don't need. Revenue lives in purchase_items alone.
SELECT sum(price_paid_eur) FROM purchase_items;                 -- 285.90

-- (b) If you must report per genre, aggregate so each item is counted once per
--     genre ON PURPOSE (revenue attributed to each of a game's genres):
SELECT ge.name AS genre, sum(pi.price_paid_eur) AS revenue
FROM purchase_items pi
JOIN game_genres gg ON gg.game_id = pi.game_id
JOIN genres ge      ON ge.genre_id = gg.genre_id
GROUP BY ge.name ORDER BY revenue DESC;
-- The per-genre numbers are meaningful; their SUM (681.78) is NOT "total
-- revenue" — a sale of a multi-genre game is attributed to each of its genres.

-- (c) Pre-aggregate the money on its own, then join the summary to anything else.
--     (This "aggregate first, join the summaries" pattern is lesson 08.)
```

The lesson: **before you `SUM` over a join, ask what each row represents.** If a priced row can appear more than once, the total is inflated. `DISTINCT` will *not* save a `SUM` the way it rescued a `COUNT` in lesson 06 — `sum(DISTINCT price_paid_eur)` would collapse two genuinely different €26.99 purchases into one. The fix is structural: aggregate the right grain.

---

## 6. Correct per-group revenue (the reports we actually want)

Aggregate the purchase side *by itself* and the numbers are trustworthy:

```sql
-- revenue per user
SELECT u.username, sum(pi.price_paid_eur) AS spent
FROM users u
JOIN purchases p       ON p.user_id = u.user_id
JOIN purchase_items pi ON pi.purchase_id = p.purchase_id
GROUP BY u.user_id, u.username
ORDER BY spent DESC;
```

| username | spent |
|---|---|
| ivan | 123.95 |
| maria | 74.98 |
| elena | 59.98 |
| petar | 26.99 |

`georgi` and `dimitar` are **absent** — they never purchased, so the inner join drops them. If the report must show them at `0`, that is a `LEFT JOIN` + `coalesce(sum(...), 0)` — the lesson-06 outer-join reflex meeting this lesson's aggregates. (`sum` of no rows is `NULL`, so `coalesce` turns it into `0`.)

> **A per-purchase total** — `sum(price_paid_eur) GROUP BY purchase_id` — is the *derived* "order total" lesson 05 promised: computed on demand, never stored, so it can't drift out of sync. Whether to *store* it (and keep it correct with a trigger) is a Module 6/7 question.

---

## Key terms

- **Aggregate function** — collapses many rows to one value (`count`, `sum`, `avg`, `min`, `max`).
- **`GROUP BY`** — partitions rows into groups; the aggregate runs once per group.
- **The `GROUP BY` rule** — every selected column is grouped or aggregated (functional-dependency payoff: grouping by a PK frees its dependent columns).
- **`HAVING`** — filters *groups* by an aggregate; runs after `GROUP BY` (vs. `WHERE`, which filters rows before).
- **Inflated `SUM`** — a total corrupted by join row-multiplication; fixed by aggregating the correct grain, not by `DISTINCT`.

## Common misconceptions this lesson targets

1. *"`avg` of no rows is 0."* — It is `NULL`. Zero is a measured value; `NULL` is "no measurement".
2. *"`count(*)` and `count(col)` are the same."* — Only when `col` is never `NULL`. On a `LEFT JOIN`, `count(*)` counts the phantom row; `count(col)` does not.
3. *"Filter groups with `WHERE count(*) > 1`."* — `WHERE` runs before grouping and can't see aggregates; use `HAVING`.
4. *"A `SUM` over a join is just a bigger, more complete total."* — Join inflation multiplies priced rows; the total is wrong. Aggregate the right grain first.
5. *"`DISTINCT` fixes an inflated `SUM` like it fixed a `COUNT`."* — No: it also collapses legitimately equal values. The fix is structural.

---

**Next:** Lesson 08 — *Subqueries, `EXISTS`, set operations, CTEs.* We give names to intermediate results and compute "aggregate first, then join" cleanly (the robust fix for the inflated `SUM`), re-derive "games with no reviews" as `NOT EXISTS`, and meet the sharpest `NULL` trap in the course — `NOT IN` with a `NULL` in the list.
