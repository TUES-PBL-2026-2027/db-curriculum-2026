# Lesson 06 — Joins and Join Cardinality

**Module 3 · Querying relational data**

> **By the end of this lesson you should be able to:** combine rows from related tables with `INNER`, `LEFT`/`RIGHT`/`FULL OUTER`, and `CROSS` joins; read a join's **cardinality** and predict how many rows it produces; recognise and explain **join inflation** (row multiplication) when two independent one-to-many relationships are joined at once; and use an **anti-join** (`LEFT JOIN … IS NULL` or `NOT EXISTS`) to find rows with *no* match — "games with no reviews", "users who unlocked nothing".

---

## 1. Why we join

Module 2 split facts across tables so each lives in exactly one place: a `game` references its `developer_id`, a `review` references both `user_id` and `game_id`. That was the right design — but a question like *"show each game with its developer's country"* now spans two tables. A **join** recombines them on the fly, following the foreign keys we declared.

> Lesson 03 said: *"we write joins properly in Module 3; for now notice the FK is what makes the connection reliable."* This is that lesson. The FK guarantees the value you join on actually exists; the join is how you *use* it.

The general shape:

```sql
SELECT g.title, d.name AS developer, d.country
FROM games g
JOIN developers d ON d.developer_id = g.developer_id;
```

`FROM games g` picks a driving table (aliased `g`); `JOIN developers d ON …` pairs each game row with the developer row whose key matches. The `ON` clause is the **join predicate** — the rule for which rows pair up.

---

## 2. The join types

| Join | Keeps | Use it for |
|---|---|---|
| `INNER JOIN` | only rows that match on **both** sides | "games *and* their developer" — drop unmatched |
| `LEFT [OUTER] JOIN` | **all** left rows; right columns `NULL` where no match | "every game, with its reviews *if any*" |
| `RIGHT [OUTER] JOIN` | all right rows; left columns `NULL` where no match | mirror of LEFT (rarely needed — swap sides instead) |
| `FULL [OUTER] JOIN` | all rows from **both**; `NULL` on whichever side is missing | "everything on either side, matched where possible" |
| `CROSS JOIN` | every left row × every right row (no `ON`) | deliberate combinations; also what a *mistaken* missing predicate degenerates into |

`INNER` is the default: `JOIN` alone means `INNER JOIN`. `OUTER` is optional noise: `LEFT JOIN` ≡ `LEFT OUTER JOIN`.

### INNER vs. LEFT — the difference that bites

```sql
-- INNER: 11 rows. Games with no reviews simply DISAPPEAR.
SELECT g.title, r.rating
FROM games g
JOIN reviews r ON r.game_id = g.game_id;

-- LEFT: 14 rows. Every game appears; unreviewed games get a NULL rating.
SELECT g.title, r.rating
FROM games g
LEFT JOIN reviews r ON r.game_id = g.game_id;
```

There are 11 reviews, so the INNER join yields 11 rows. The LEFT join adds one row each for the three games with *no* review (`Half-Life 2`, `Hades II`, `Untitled Project`) — 14 rows — with `rating` showing `NULL`. **Choosing INNER when you meant LEFT silently drops the very rows a report often cares about** (the games nobody reviewed). This is the single most common join bug.

> The `NULL`s a LEFT JOIN invents are exactly lesson 02's three-valued logic in the wild: `r.rating` is *unknown* because there is no review, and every aggregate and comparison on it behaves accordingly (see lesson 07).

---

## 3. Cardinality: how many rows come out?

A join's output size depends on the **relationship** between the joined columns:

- **N : 1** (many games → one developer). Joining `games` to `developers` yields **one row per game** — the "one" side doesn't multiply anything. 8 games in, 8 rows out.
- **1 : N** (one game → many reviews). Joining `games` to `reviews` yields **one row per review** — a game with 2 reviews appears twice. The "many" side sets the count.
- **M : N** via a junction (games ↔ genres). One row per *matching pair*.

The rule of thumb: **each left row is repeated once per matching right row.** Zero matches → zero rows (INNER) or one NULL-filled row (LEFT). Three matches → three rows.

---

## 4. Join inflation (row multiplication) — the headline pitfall

Here is the trap lesson 03 promised to return to. Cyberpunk 2077 has **3 genres** and **2 achievements**. Join *both* at once:

```sql
SELECT g.title, ge.name AS genre, a.name AS achievement
FROM games g
JOIN game_genres gg ON gg.game_id = g.game_id
JOIN genres ge      ON ge.genre_id = gg.genre_id
JOIN achievements a ON a.game_id   = g.game_id
WHERE g.title = 'Cyberpunk 2077';
```

This returns **6 rows for one game** — every genre paired with every achievement (3 × 2). Neither relationship is wrong; the join simply formed the **Cartesian product** of two independent "many" sides that share only `game_id`.

Why it matters: now naively "count the genres" —

```sql
-- WRONG: 6, because the achievements join multiplied every genre row.
SELECT count(*) FROM games g
JOIN game_genres gg ON gg.game_id = g.game_id
JOIN achievements a ON a.game_id = g.game_id
WHERE g.title = 'Cyberpunk 2077';
```

Cyberpunk has 3 genres, but you get 6. The achievements had nothing to do with genres — yet they doubled the count. **This is join inflation: joining two independent one-to-many relationships multiplies their rows, and any `SUM`/`COUNT` over the result is silently wrong.** Diagnosing exactly this ("inflated totals after a join") is a named competence of this module.

Fixes (developed fully in lessons 07–08):
- Aggregate each relationship **separately** (one `COUNT(DISTINCT …)`, or two subqueries), then combine.
- Or join one relationship at a time.
- `COUNT(DISTINCT ge.genre_id)` recovers 3 here — but understand *why* you needed `DISTINCT`, don't just sprinkle it.

---

## 5. Anti-joins: finding what is *missing*

A frequent, high-value question is the **absence** of a match: games nobody reviewed, users who unlocked no achievement, developers with no games. Two idiomatic ways:

```sql
-- (a) LEFT JOIN ... WHERE right-side key IS NULL
SELECT g.title
FROM games g
LEFT JOIN reviews r ON r.game_id = g.game_id
WHERE r.review_id IS NULL
ORDER BY g.title;
-- -> Hades II, Half-Life 2, Untitled Project
```

```sql
-- (b) NOT EXISTS (often clearer, and handled fully in lesson 08)
SELECT g.title
FROM games g
WHERE NOT EXISTS (SELECT 1 FROM reviews r WHERE r.game_id = g.game_id)
ORDER BY g.title;
```

The LEFT JOIN keeps every game; the `WHERE r.review_id IS NULL` then **keeps only the rows the join failed to match** — i.e. the games with no review. Test the key on the *right* side of the join (`review_id`), never a left column, and never a nullable right column that could be NULL for a *real* match.

> This is why we filter on `IS NULL`, not `= NULL` — a direct payoff of lesson 02's three-valued logic: `= NULL` is never true.

---

## 6. Qualifying and aliasing

Once two tables are in play, **qualify every column** (`g.title`, `r.rating`) so it's unambiguous and the query survives a schema change. Short table aliases (`g`, `r`, `ge`) keep joins readable. `USING (game_id)` is a shorthand for `ON a.game_id = b.game_id` when both columns share a name — handy, but spell out `ON` while learning so the predicate is explicit.

---

## Key terms

- **Join predicate (`ON`)** — the rule deciding which left/right rows pair.
- **INNER / LEFT / RIGHT / FULL / CROSS** — matched-only / keep-left / keep-right / keep-both / all-combinations.
- **Cardinality** — how many output rows a join produces; set by the 1-vs-N side.
- **Join inflation (row multiplication)** — joining two independent one-to-many relations forms a Cartesian product, inflating counts/sums.
- **Anti-join** — `LEFT JOIN … IS NULL` or `NOT EXISTS`: rows with *no* match.

## Common misconceptions this lesson targets

1. *"A join just glues tables together."* — It pairs rows per the predicate and *multiplies* on the many side; the row count is a design decision.
2. *"INNER and LEFT give the same rows."* — Only when every left row has a match. Otherwise INNER silently drops rows (the no-review games).
3. *"More joins = more complete data."* — Joining two independent 1:N relations inflates rows; counts/sums over the result lie.
4. *"Use `DISTINCT` to fix a wrong count."* — `DISTINCT` masks the symptom; understand the inflation first (lesson 07).
5. *"Find missing rows with `= NULL`."* — `= NULL` is never true (lesson 02); use `IS NULL` or `NOT EXISTS`.

---

**Next:** Lesson 07 — *Aggregation, `GROUP BY`, `HAVING`.* We collapse these joined rows into per-group answers (reviews per game, revenue per user), see how aggregates treat `NULL`, and meet join inflation again — this time as a wrong `SUM` we must diagnose and fix.
