# Lesson 08 — Subqueries, `EXISTS`, Set Operations, CTEs

**Module 3 · Querying relational data**

> **By the end of this lesson you should be able to:** use a query *inside* another query — as a single value (scalar subquery), as a set (`IN`, `EXISTS`), or as a table (derived table in `FROM`); recognise and avoid the **`NOT IN` + `NULL` trap** and prefer `NOT EXISTS` for "find what's missing"; combine result sets with `UNION`/`INTERSECT`/`EXCEPT`; and name intermediate results with **CTEs (`WITH`)** so a complicated report reads top-to-bottom. This lesson pays off two promises from lesson 07 — the clean fix for the inflated `SUM`, and `NOT EXISTS` as the robust anti-join — and lands the sharpest `NULL` trap in the course.

---

## 1. A query is a value: three shapes of subquery

A subquery is a `SELECT` wrapped in parentheses and used inside another statement. It comes in three shapes, by what it *produces*:

| Shape | Produces | Used where |
|---|---|---|
| **Scalar** | exactly **one row, one column** | anywhere a single value fits: `SELECT`, `WHERE`, `HAVING` |
| **Set / column** | **one column, many rows** | `IN (…)`, `NOT IN (…)`, `= ANY (…)`, `EXISTS (…)` |
| **Derived table** | **a whole result table** | in `FROM`, with an alias — then joined like any table |

### Scalar subquery — compare against a computed value

"Games priced above the catalogue average":

```sql
SELECT title, price_eur
FROM games
WHERE price_eur > (SELECT avg(price_eur) FROM games)   -- one number: 26.49
ORDER BY price_eur DESC;
```

→ Cyberpunk 2077, The Witcher 3, Hades II, Minecraft. The inner query runs once, yields `26.49`, and the outer query compares each game to it. A scalar subquery that accidentally returns more than one row is a **runtime error** — that is the database protecting you from an ambiguous comparison.

> You could also put a scalar subquery in the `SELECT` list — e.g. show each game beside `(SELECT avg(price_eur) FROM games)`. Correlated versions of this (one that references the outer row) are powerful but can be slow; §5 and lesson 09 give better tools (window functions) for "value beside its group's summary".

---

## 2. Subquery as a set: `IN`, and the `NOT IN` + `NULL` trap

`IN` tests membership in a set the subquery returns:

```sql
-- users who have written at least one review
SELECT username FROM users
WHERE user_id IN (SELECT user_id FROM reviews);
```

`IN` is fine. Its mirror `NOT IN` hides **the single most infamous trap in SQL**, and it is pure lesson-02 three-valued logic.

Suppose someone builds the "games nobody reviewed" query, but writes the subquery with a `LEFT JOIN` (perhaps copied from a bigger report):

```sql
-- LOOKS right. Returns ZERO rows. Silently wrong.
SELECT title FROM games
WHERE game_id NOT IN (
    SELECT r.game_id
    FROM users u
    LEFT JOIN reviews r ON r.user_id = u.user_id   -- dimitar reviewed nothing -> NULL
);
```

`dimitar` wrote no review, so the `LEFT JOIN` produces one row with `r.game_id = NULL`. The subquery's set is therefore `{2,3,4,5,6, NULL}`. Now expand what `NOT IN` means:

```
game_id NOT IN (2,3,4,5,6, NULL)
  ≡  game_id <> 2 AND game_id <> 3 AND … AND game_id <> NULL
```

That last comparison, `game_id <> NULL`, is **`unknown`** for every row (lesson 02: nothing compares to `NULL`). `true AND true AND … AND unknown` = `unknown`, never `true`. So `WHERE` keeps **nothing** — even for Half-Life 2, which genuinely has no review. One stray `NULL` in the list silently empties the result.

### The fix: `NOT EXISTS`

```sql
SELECT title FROM games g
WHERE NOT EXISTS (
    SELECT 1 FROM reviews r WHERE r.game_id = g.game_id
)
ORDER BY title;
-- -> Half-Life 2, Hades II, Untitled Project   (correct)
```

`EXISTS` asks a yes/no question — *does the inner query return any row for this outer row?* — and yes/no has no "unknown" middle to leak. `NOT EXISTS` is the robust anti-join: immune to `NULL`, and usually the clearest way to say "has no related row". **Rule of thumb: for "find rows with no match", reach for `NOT EXISTS`, not `NOT IN`.**

> The `SELECT 1` is conventional — `EXISTS` only cares *whether* a row comes back, not what's in it. You could write `SELECT *`; it makes no difference.

---

## 3. Correlated subqueries and `EXISTS`

The `NOT EXISTS` above is **correlated**: the inner query mentions `g.game_id` from the outer query, so it is re-evaluated for each outer row. That is exactly what makes `EXISTS` test *this* game. The positive form is just as useful:

```sql
-- games that user 'ivan' (user_id 1) has reviewed
SELECT g.title FROM games g
WHERE EXISTS (
    SELECT 1 FROM reviews r
    WHERE r.game_id = g.game_id AND r.user_id = 1
);
```

Read `EXISTS (…)` as "there is at least one matching row". An uncorrelated subquery (no reference to the outer row) runs once; a correlated one runs per outer row — conceptually always, though the planner (Module 6) often rewrites it into a join.

---

## 4. Subquery as a table: the clean fix for lesson 07's inflated `SUM`

Lesson 07 left a promise: the robust way to combine a revenue total with another one-to-many relation (genres) is to **aggregate each side first, then join the summaries** — so neither can multiply the other. A subquery in `FROM` (a **derived table**) is how:

```sql
SELECT g.title, rev.revenue, gc.n_genres
FROM games g
JOIN (SELECT game_id, sum(price_paid_eur) AS revenue
      FROM purchase_items GROUP BY game_id) AS rev ON rev.game_id = g.game_id
JOIN (SELECT game_id, count(*) AS n_genres
      FROM game_genres GROUP BY game_id)   AS gc  ON gc.game_id  = g.game_id
ORDER BY rev.revenue DESC;
```

| title | revenue | n_genres |
|---|---|---|
| Cyberpunk 2077 | 109.98 | 3 |
| Minecraft | 53.98 | 2 |
| The Witcher 3 | 51.98 | 2 |
| Hades | 39.98 | 2 |
| Portal 2 | 29.98 | 2 |

Each derived table is already collapsed to **one row per game**, so joining them cannot inflate anything — Cyberpunk's revenue is `109.98`, not `329.94` (= 109.98 × 3) as the naive "join then sum" produced. A derived table must be aliased (`AS rev`) and may only reference the outer query through its join predicate, not inside itself.

---

## 5. Set operations: combine whole result sets

Where a join combines tables *sideways* (more columns), a set operation stacks result sets *vertically* (more rows). The inputs must have **the same number of columns with compatible types**.

| Operator | Returns | Duplicates |
|---|---|---|
| `UNION` | rows in **either** set | removed (distinct) |
| `UNION ALL` | rows in either set | **kept** (faster; use when you know there are none) |
| `INTERSECT` | rows in **both** sets | removed |
| `EXCEPT` | rows in the **first** but not the second | removed |

Compare two games' genres:

```sql
-- genres Cyberpunk and The Witcher 3 share
SELECT ge.name FROM game_genres gg JOIN genres ge ON ge.genre_id = gg.genre_id WHERE gg.game_id = 3
INTERSECT
SELECT ge.name FROM game_genres gg JOIN genres ge ON ge.genre_id = gg.genre_id WHERE gg.game_id = 4;
-- -> Adventure, RPG
```

Swap `INTERSECT` for `EXCEPT` and you get **Action** (in Cyberpunk, not in Witcher); `UNION` gives all three. And "games the store has sold or reviewed-upon — which ones has *neither* touched?":

```sql
SELECT game_id FROM games
EXCEPT
(SELECT game_id FROM reviews UNION SELECT game_id FROM purchase_items);
-- -> 1, 7, 8  (Half-Life 2, Untitled Project, Hades II)
```

The same three "orphan" games keep surfacing — a good sanity check that these operators agree with the anti-joins.

> `UNION` deduplicates, which costs a sort/hash. If the inputs are provably disjoint (e.g. rows tagged by different sources), `UNION ALL` is cheaper and keeps every row. Choosing between them is a correctness *and* performance decision (Module 6).

---

## 6. CTEs (`WITH`): name your intermediate results

Nested subqueries read inside-out and get unreadable fast. A **Common Table Expression** names a subquery up front so the query reads top-to-bottom:

```sql
WITH revenue AS (
    SELECT game_id, sum(price_paid_eur) AS revenue
    FROM purchase_items GROUP BY game_id
),
genre_count AS (
    SELECT game_id, count(*) AS n_genres
    FROM game_genres GROUP BY game_id
)
SELECT g.title, r.revenue, c.n_genres
FROM games g
JOIN revenue     r ON r.game_id = g.game_id
JOIN genre_count c ON c.game_id = g.game_id
ORDER BY r.revenue DESC;
```

This is the §4 query, rewritten. Identical result — but each step has a name and the logic is linear. A (non-recursive) CTE is **just a named subquery**: reach for it when a subquery is reused or when nesting hurts readability. You can chain as many as you like; later CTEs may reference earlier ones.

> **Recursive CTEs** (`WITH RECURSIVE`) handle hierarchies — a category tree, a chain of prerequisites — by referencing themselves. That is an **extension**, previewed in lesson 09. Note also: a CTE is a readability tool, not automatically a performance one; in modern PostgreSQL the planner may inline or materialise it (Module 6).

---

## Key terms

- **Scalar subquery** — returns one value; used where a single value fits.
- **Derived table** — a subquery in `FROM`, aliased and joined like a table; the clean pre-aggregation fix for join inflation.
- **Correlated subquery** — references the outer row; re-evaluated per row (`EXISTS`/`NOT EXISTS`).
- **`NOT IN` + `NULL` trap** — a `NULL` in the subquery makes `NOT IN` return nothing; use `NOT EXISTS`.
- **Set operations** — `UNION`(`ALL`)/`INTERSECT`/`EXCEPT`: combine result sets vertically; columns must be compatible.
- **CTE (`WITH`)** — a named subquery; makes complex queries read top-to-bottom. `WITH RECURSIVE` for hierarchies (lesson 09).

## Common misconceptions this lesson targets

1. *"`NOT IN` and `NOT EXISTS` are interchangeable."* — Only when the subquery has no `NULL`s. One stray `NULL` empties a `NOT IN` result; `NOT EXISTS` is immune.
2. *"A subquery can only go in `WHERE`."* — It can be a value, a set, or a whole table (`FROM`).
3. *"`UNION` just concatenates."* — `UNION` removes duplicates (and sorts to do so); `UNION ALL` concatenates.
4. *"`DISTINCT` fixes the inflated `SUM`."* — No (lesson 07); pre-aggregate in a derived table/CTE so nothing can multiply.
5. *"A CTE is faster than a subquery."* — It is a *readability* tool; performance is the planner's call (Module 6).

---

**Next:** Lesson 09 — *Views and window functions.* We save these reports as reusable **views**, then meet **window functions**, which compute a summary *beside each row* without collapsing it — ranking games within each developer, showing every review next to its game's average, running totals of a user's spend. That is the "value beside its group" problem §1 and §5 could only approximate.
