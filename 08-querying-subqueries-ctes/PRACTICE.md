# Lesson 08 — Practice

**Module 3 · Subqueries, `EXISTS`, Set Operations, CTEs**

> **Predict → Run → Explain.** For every task, write down the result (rows or count) you expect **before** running it. Part B is the one place in the course where a query that *looks* obviously correct returns the wrong answer — predict it, then watch it fail. Write the prediction down first — the effort of predicting is what makes the answer stick.

## Setup

```bash
psql -d storefront -f 08-querying-subqueries-ctes/setup.sql     # loads Stage 8 (= Stage 7 data)
storefront
```

Stage 8 has the **same** schema and data as Stage 7. This lesson is about expressing queries, not growing the database.

---

## Part A — Subqueries as values and sets

**A1.** Scalar subquery. Predict the set, then run:
```sql
SELECT title, price_eur
FROM games
WHERE price_eur > (SELECT avg(price_eur) FROM games)
ORDER BY price_eur DESC;
```
What single value does the inner query produce? How many times does it run?

**A2.** Predict what happens — a result, or an error — then run:
```sql
SELECT title, (SELECT avg(price_eur) FROM games) AS catalogue_avg
FROM games
WHERE title = 'Hades';
```
Now change the inner query to `SELECT price_eur FROM games` (no aggregate) and predict again before running. Why does one work and the other fail?

**A3.** Rewrite "users who have written at least one review" as a set-membership subquery with `IN`, then predict the result. (You'll rebuild this as `EXISTS` in B3.)

---

## Part B — The `NOT IN` + `NULL` trap (the headline)

**B1.** Build the "games nobody reviewed" query the tempting way. **Predict the result first** (you know from lesson 06 it should be three games), then run it:
```sql
SELECT title FROM games
WHERE game_id NOT IN (
    SELECT r.game_id
    FROM users u
    LEFT JOIN reviews r ON r.user_id = u.user_id
);
```
It does **not** return three games. What does it return? Now run the subquery on its own and look at its rows — what value is in there that shouldn't be?

**B2.** Diagnose. Expand `game_id NOT IN (2,3,4,5,6, NULL)` into its `AND` chain of `<>` comparisons. Using lesson 02's rules, what is the truth value of `game_id <> NULL`, and why does that make the whole `WHERE` keep no rows? Which user is responsible for the stray `NULL`?

**B3.** Fix it with `NOT EXISTS`, and separately write the positive `EXISTS` form for "games that user `ivan` (id 1) *has* reviewed". Predict both sets. Why is `EXISTS` immune to the `NULL` that broke `NOT IN`?

**B4.** Find every **user who has unlocked no achievement** using `NOT EXISTS`. Predict the set (callback to lesson 06). Confirm it matches.

---

## Part C — Derived tables & the inflated-`SUM` fix

**C1.** First reproduce the lesson-07 bug. Predict Cyberpunk's figure, then run:
```sql
SELECT g.title, sum(pi.price_paid_eur) AS revenue
FROM games g
JOIN purchase_items pi ON pi.game_id = g.game_id
JOIN game_genres gg    ON gg.game_id = g.game_id
GROUP BY g.title
ORDER BY revenue DESC;
```
Cyberpunk's true revenue is `109.98` (lesson 07). What does this report show for it, and why?

**C2.** Now fix it with two **derived tables** (pre-aggregate revenue and genre count separately, then join the summaries). Predict that Cyberpunk returns to `109.98` with `n_genres = 3`:
```sql
SELECT g.title, rev.revenue, gc.n_genres
FROM games g
JOIN (SELECT game_id, sum(price_paid_eur) AS revenue
      FROM purchase_items GROUP BY game_id) AS rev ON rev.game_id = g.game_id
JOIN (SELECT game_id, count(*) AS n_genres
      FROM game_genres GROUP BY game_id)   AS gc  ON gc.game_id  = g.game_id
ORDER BY rev.revenue DESC;
```
Explain in one sentence *why* the two derived tables cannot inflate each other.

**C3.** Rewrite C2 as a `WITH` chain (two CTEs + a final `SELECT`). Confirm the result is identical. Which form do you find easier to read, and why?

---

## Part D — Set operations

**D1.** Predict each result for Cyberpunk (game 3) vs The Witcher 3 (game 4), then run all three:
```sql
-- genres they share
SELECT ge.name FROM game_genres gg JOIN genres ge ON ge.genre_id=gg.genre_id WHERE gg.game_id=3
INTERSECT
SELECT ge.name FROM game_genres gg JOIN genres ge ON ge.genre_id=gg.genre_id WHERE gg.game_id=4;
```
Then swap `INTERSECT` for `EXCEPT`, and for `UNION`. Predict all three result sets.

**D2.** "Games the store has neither sold nor been reviewed on." Predict the set, then run:
```sql
SELECT game_id FROM games
EXCEPT
(SELECT game_id FROM reviews UNION SELECT game_id FROM purchase_items)
ORDER BY game_id;
```
Which three games? Why does this agree with B4-style anti-joins?

**D3.** Predict the difference between `UNION` and `UNION ALL` here, then test both:
```sql
SELECT game_id FROM reviews
UNION      -- then try UNION ALL
SELECT game_id FROM purchase_items;
```
Why are the row counts different? When would you deliberately choose `UNION ALL`?

---

## Stretch (optional)

**S1.** Using a `WITH` chain, list each user with their **total spend** and their **number of reviews written**, including users who have done neither (show `0`/`0`). Predict which users show all-zero. (Hint: pre-aggregate spend and review counts in separate CTEs, then `LEFT JOIN` both onto `users` and `coalesce`.)

**S2.** Find games that are **priced above average** (A1) **and** have **no reviews** — combine a scalar subquery with `NOT EXISTS`. Predict the set before running. (Which above-average game is unreviewed?)

**S3.** Correlated scalar subquery in `SELECT`: show each game with its review count computed by a subquery, *not* a join:
```sql
SELECT g.title,
       (SELECT count(*) FROM reviews r WHERE r.game_id = g.game_id) AS n_reviews
FROM games g ORDER BY n_reviews DESC, g.title;
```
Predict the result, then compare it to the lesson-07 `LEFT JOIN … GROUP BY` version. Do they agree? Which avoids the phantom-row issue entirely, and why? When might the subquery form be slower (think: it runs once per game)?

**S4.** `WITH RECURSIVE` preview (extension). Generate the numbers 1 through 5 with a recursive CTE:
```sql
WITH RECURSIVE counter(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM counter WHERE n < 5
)
SELECT n FROM counter;
```
Explain the two parts (anchor + recursive step) and what `UNION ALL` contributes. Why would this loop forever without the `WHERE n < 5`? (Lesson 09 uses this shape for a real hierarchy.)
