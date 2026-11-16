# Lesson 07 — Practice

**Module 3 · Aggregation, `GROUP BY`, `HAVING`**

> **Predict → Run → Explain.** For every task, write down the value (or row count) you expect **before** running it. Aggregation hides a lot of behaviour inside one number — the prediction is where you confront it. Write the prediction down first — the effort of predicting is what makes the answer stick.

## Setup

```bash
psql -d storefront -f 07-querying-aggregation/setup.sql     # loads Stage 7
storefront
```

Stage 7 is Stage 6 plus a fuller purchase history (7 purchases, 10 line items). No new tables.

---

## Part A — Aggregates and `GROUP BY`

**A1.** Predict each value, then run:
```sql
SELECT count(*)                  AS n_games,
       min(price_eur)            AS cheapest,
       max(price_eur)            AS dearest,
       round(avg(price_eur), 2)  AS avg_price
FROM games;
```
How many rows come back? Why does `avg` differ from `(min + max) / 2`?

**A2.** Reviews per game and average rating, keeping games with none:
```sql
SELECT g.title,
       count(r.review_id)       AS n_reviews,
       round(avg(r.rating), 2)  AS avg_rating
FROM games g
LEFT JOIN reviews r ON r.game_id = g.game_id
GROUP BY g.game_id, g.title
ORDER BY avg_rating DESC NULLS LAST, g.title;
```
Predict what appears in `n_reviews` and `avg_rating` for a game with no reviews. Is `avg_rating` `0` or something else? Explain.

**A3.** This query is rejected. Predict the error *before* running, then explain it in one sentence:
```sql
SELECT g.title, r.rating
FROM games g JOIN reviews r ON r.game_id = g.game_id
GROUP BY g.title;
```
Then fix it so it returns, per game, the *highest* rating any review gave it.

**A4.** In A2 we grouped by `g.game_id, g.title` but only `g.title` is in the output. Predict: does `GROUP BY g.game_id` alone (dropping `g.title`) still let you `SELECT g.title`? Try it. Why does PostgreSQL allow it? (Think lesson 05.)

---

## Part B — `WHERE` vs. `HAVING`

**B1.** "Games with at least two reviews." Predict the set, then run:
```sql
SELECT g.title, count(*) AS n_reviews
FROM games g JOIN reviews r ON r.game_id = g.game_id
GROUP BY g.game_id, g.title
HAVING count(*) >= 2
ORDER BY n_reviews DESC, g.title;
```

**B2.** Predict the error, then run it:
```sql
SELECT g.title, count(*)
FROM games g JOIN reviews r ON r.game_id = g.game_id
WHERE count(*) >= 2
GROUP BY g.title;
```
Why can't `WHERE` do what `HAVING` just did? State the stage each one runs at.

**B3.** Now combine them. Compute the average rating per game **using only positive reviews (rating ≥ 4)**, and keep only games that have **at least two such reviews**. Predict which games survive. (Hint: one clause filters rows *before* grouping, the other filters groups *after*.)

---

## Part C — Aggregates and `NULL`

**C1.** Compare on an unreviewed game. Predict all four values first:
```sql
SELECT g.title,
       count(*)           AS star_count,
       count(r.review_id) AS real_reviews,
       sum(r.rating)      AS sum_rating,
       avg(r.rating)      AS avg_rating
FROM games g
LEFT JOIN reviews r ON r.game_id = g.game_id
WHERE g.title = 'Half-Life 2'
GROUP BY g.title;
```
Why is `count(*) = 1` but `count(review_id) = 0`? Why are `sum` and `avg` `NULL` rather than `0`?

**C2.** A teammate computes "the catalogue-wide average rating" two ways over a `LEFT JOIN` of every game to its reviews. Predict both numbers *before* running:
```sql
SELECT round(sum(r.rating)::numeric / count(*), 2) AS naive_avg,   -- sum ÷ ALL rows
       round(avg(r.rating), 2)                     AS honest_avg   -- sum ÷ rated rows
FROM games g
LEFT JOIN reviews r ON r.game_id = g.game_id;
```
They disagree. Work out the denominator each one uses (count the rows the `LEFT JOIN` produces vs. the number of real reviews). Which figure is the true average rating of the reviewed games, and what polluted the other?

**C3.** Make the per-user revenue report show **every** user including non-buyers at `0`. Start from this (which omits them) and fix it:
```sql
SELECT u.username, sum(pi.price_paid_eur) AS spent
FROM users u
JOIN purchases p       ON p.user_id = u.user_id
JOIN purchase_items pi ON pi.purchase_id = p.purchase_id
GROUP BY u.user_id, u.username
ORDER BY spent DESC;
```
Which users are missing and why? Change two things (a join type and a wrapper function) so they appear as `0`.

---

## Part D — Inflated `SUM` (the headline)

**D1.** First, the truth. Predict then run:
```sql
SELECT sum(price_paid_eur) AS total_revenue, count(*) AS items
FROM purchase_items;
```

**D2.** Now a colleague joins genres "to allow a genre breakdown" and reads the total off the result:
```sql
SELECT sum(pi.price_paid_eur) AS total_revenue
FROM purchase_items pi
JOIN game_genres gg ON gg.game_id = pi.game_id;
```
**Predict the number before running.** It is far bigger than D1. Diagnose *precisely* what inflated it (count the rows: `SELECT count(*)` on the same join). Why did `SUM` go wrong even though every individual `price_paid_eur` is correct?

**D3.** Fix D2 two ways: (a) compute the true total without the genre join; (b) produce a *legitimate* per-genre revenue report (`GROUP BY` genre). For (b), add up the per-genre revenues — do you get D1's total or D2's? Explain why the per-genre numbers are each meaningful even though their sum is not "total revenue".

**D4.** Would `sum(DISTINCT pi.price_paid_eur)` rescue D2 the way `count(DISTINCT …)` rescued the inflated count in lesson 06? Predict, then reason about two different €26.99 purchases. State the general rule.

---

## Stretch (optional)

**S1.** For each developer, show the **average rating across all their games' reviews** and the **number of distinct games that have at least one review**, including developers whose games have none (show `0`). Beware both traps at once: outer-join coverage (lesson 06) *and* not letting a 3-review game count as 3 games. Which developer shows `0` reviewed games?

**S2.** Compute each user's **average spend per purchase** (total spent ÷ number of purchases) as a single grouped query. Predict ivan's value (he made 3 purchases). Why must you be careful computing this from the joined `purchases ⋈ purchase_items` rows rather than `sum / count(*)`?

**S3.** `GROUPING SETS` / `ROLLUP` preview (extension): run
```sql
SELECT ge.name AS genre, sum(pi.price_paid_eur) AS revenue
FROM purchase_items pi
JOIN game_genres gg ON gg.game_id = pi.game_id
JOIN genres ge      ON ge.genre_id = gg.genre_id
GROUP BY ROLLUP (ge.name);
```
What does the extra final row (with `genre = NULL`) represent, and why does it equal D2's inflated number rather than D1's true revenue?
