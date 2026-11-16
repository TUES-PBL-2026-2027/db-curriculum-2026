# Lesson 09 — Practice

**Module 3 · Views and Window Functions**

> **Predict → Run → Explain.** For every task, write down the result you expect **before** running it. The recurring question this lesson: *does this collapse the rows or keep them?* Predict the row count every time. Write the prediction down first — the effort of predicting is what makes the answer stick.

## Setup

```bash
psql -d storefront -f 09-querying-views-window-functions/setup.sql     # loads Stage 9
storefront
```

Stage 9 is Stage 8 plus two views (`game_ratings`, `game_revenue`) and one materialized view (`game_ratings_mv`). No new base tables.

---

## Part A — Views

**A1.** The views ship with the database. Predict the rows, then run:
```sql
SELECT * FROM game_ratings ORDER BY avg_rating DESC NULLS LAST, title;
```
How many rows? Which games show `avg_rating = NULL`, and why does the view keep them at all? (What join is inside it?)

**A2.** Use the view like a table — no need to re-derive the report:
```sql
SELECT title, revenue FROM game_revenue WHERE revenue > 0 ORDER BY revenue DESC;
```
Predict the set. Then look at `game_revenue`'s definition (`\d+ game_revenue` in psql, or read `setup.sql`). Where does the data in a view actually live?

**A3.** Prove a view is always current. Run `SELECT avg_rating FROM game_ratings WHERE title = 'Half-Life 2';` (predict it: Half-Life 2 has no reviews). Then insert a review for it and re-select — **predict the new value before running**:
```sql
INSERT INTO reviews (review_id, user_id, game_id, rating, body, reviewed_on)
VALUES (99, 6, 1, 5, 'Finally played it.', CURRENT_DATE);
SELECT avg_rating FROM game_ratings WHERE title = 'Half-Life 2';
```
Did the view change without you editing it? Why? *(Keep this review in place for A4, then delete it: `DELETE FROM reviews WHERE review_id = 99;`.)*

**A4.** Now the materialized view. With review 99 still inserted, predict each of these **before** running:
```sql
SELECT avg_rating FROM game_ratings    WHERE title = 'Half-Life 2';   -- plain view
SELECT avg_rating FROM game_ratings_mv WHERE title = 'Half-Life 2';   -- materialized
REFRESH MATERIALIZED VIEW game_ratings_mv;
SELECT avg_rating FROM game_ratings_mv WHERE title = 'Half-Life 2';   -- after refresh
```
Why does the materialized view disagree with the plain view until you `REFRESH`? Clean up afterwards (`DELETE FROM reviews WHERE review_id = 99;` then `REFRESH MATERIALIZED VIEW game_ratings_mv;`).

---

## Part B — Windows keep the rows

**B1.** Predict the **row count** first (how many reviews are there?), then run:
```sql
SELECT g.title, r.rating,
       round(avg(r.rating) OVER (PARTITION BY r.game_id), 2) AS game_avg
FROM reviews r JOIN games g ON g.game_id = r.game_id
ORDER BY g.title, r.reviewed_on;
```
How many rows come back — one per review, or one per game? What does `game_avg` show for each of Cyberpunk's three reviews?

**B2.** Write the `GROUP BY` version of "average rating per game". Predict its row count and contrast with B1. Why can't a single `GROUP BY` query show each individual `rating` *and* the game average side by side, while the window version can?

**B3.** Add each review's rating as a fraction of its game's total stars:
```sql
SELECT g.title, r.rating,
       sum(r.rating) OVER (PARTITION BY r.game_id)                         AS game_total,
       round(r.rating::numeric / sum(r.rating) OVER (PARTITION BY r.game_id), 2) AS share
FROM reviews r JOIN games g ON g.game_id = r.game_id
WHERE g.title = 'Hades'
ORDER BY r.reviewed_on;
```
Predict Hades' three shares. Do they sum to 1?

---

## Part C — Ranking within groups

**C1.** Predict all three rank columns (watch the ties at 4.50 and 3.00) before running:
```sql
SELECT title, avg_rating,
       row_number() OVER w AS rn,
       rank()       OVER w AS rnk,
       dense_rank() OVER w AS drnk
FROM game_ratings
WHERE n_reviews > 0
WINDOW w AS (ORDER BY avg_rating DESC);
```
Explain the difference between `rnk` and `drnk` at the 3.00 games. Which function would you use for "the 2nd-best distinct score"?

**C2.** Top-rated game **per developer**. Predict each developer's rank-1 game:
```sql
SELECT d.name AS developer, gr.title, gr.avg_rating,
       rank() OVER (PARTITION BY g.developer_id ORDER BY gr.avg_rating DESC) AS rnk
FROM game_ratings gr
JOIN games g      ON g.game_id = gr.game_id
JOIN developers d ON d.developer_id = g.developer_id
WHERE gr.n_reviews > 0
ORDER BY d.name, rnk;
```
Which developer has a rank 2 at all, and why do the others only show rank 1?

**C3.** Now return **only each developer's best-rated game** (one row per developer). You can't put the window function in `WHERE` — predict the error if you try `WHERE rank() OVER (...) = 1`, then write the correct version wrapping C2 in a CTE and filtering `WHERE rnk = 1`.

---

## Part D — Running totals and neighbours

**D1.** ivan's cumulative spend over time. Predict the final `running_total` (recall ivan's lifetime spend from lesson 07):
```sql
WITH ivan_orders AS (
    SELECT p.purchase_id, p.purchased_at::date AS d, sum(pi.price_paid_eur) AS order_total
    FROM purchases p JOIN purchase_items pi ON pi.purchase_id = p.purchase_id
    WHERE p.user_id = 1
    GROUP BY p.purchase_id, p.purchased_at
)
SELECT d, order_total,
       sum(order_total) OVER (ORDER BY d) AS running_total
FROM ivan_orders ORDER BY d;
```
Why does the last `running_total` equal his total spend? What is the "window" for each row here?

**D2.** `LAG`: Cyberpunk's rating history and the change each review made. Predict the two deltas:
```sql
SELECT r.reviewed_on, r.rating,
       lag(r.rating) OVER (ORDER BY r.reviewed_on)             AS prev_rating,
       r.rating - lag(r.rating) OVER (ORDER BY r.reviewed_on)  AS delta
FROM reviews r JOIN games g ON g.game_id = r.game_id
WHERE g.title = 'Cyberpunk 2077'
ORDER BY r.reviewed_on;
```
What is `prev_rating` on the first row, and why? (Think lesson 02.)

**D3.** For each of ivan's purchases, show the **gap in days until his next purchase** using `lead()`. Predict which row has a `NULL` gap and why.

---

## Stretch (optional)

**S1.** Create your own view `top_game_per_developer` from C3's query (`CREATE VIEW … AS …`), then `SELECT * FROM top_game_per_developer`. What did naming it buy you? (When you're done: `DROP VIEW top_game_per_developer;`.)

**S2.** Using `game_revenue` **and** `game_ratings` together, rank games by revenue within rating bands — e.g. show, for each game with `n_reviews > 0`, its revenue rank among all reviewed games (`rank() OVER (ORDER BY revenue DESC)`) alongside its rating rank. Which game is #1 by revenue but not #1 by rating? What does that tell you about selling well vs. reviewing well?

**S3.** `WITH RECURSIVE` (extension). The storefront has no category tree yet, but you can still demonstrate the shape: generate each game's release *anniversary* years from `released_on` up to 2026 for `The Witcher 3`:
```sql
WITH RECURSIVE anniversaries(game_id, yr) AS (
    SELECT game_id, extract(year FROM released_on)::int
    FROM games WHERE title = 'The Witcher 3'
    UNION ALL
    SELECT game_id, yr + 1 FROM anniversaries WHERE yr < 2026
)
SELECT yr FROM anniversaries;
```
Explain the anchor and recursive step. How many rows come back, and what stops the recursion?

**S4.** A materialized view trades freshness for speed. Describe one storefront report where a *slightly stale* materialized view would be perfectly acceptable, and one where it would be dangerous. Tie your answer to the derived-vs-stored idea from lesson 05.
