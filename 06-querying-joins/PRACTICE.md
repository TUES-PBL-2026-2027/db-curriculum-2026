# Lesson 06 — Practice

**Module 3 · Joins and Join Cardinality**

> **Predict → Run → Explain.** For every task, write down the rows (or the row *count*) you expect **before** running it. Joins are where intuition and reality diverge — the prediction is the point. Write the prediction down first — the effort of predicting is what makes the answer stick.

## Setup

```bash
psql -d storefront -f 06-querying-joins/setup.sql     # loads Stage 6
storefront
```

---

## Part A — Inner joins and cardinality

**A1.** Predict the row count, then run:
```sql
SELECT g.title, d.name AS developer
FROM games g
JOIN developers d ON d.developer_id = g.developer_id;
```
There are 8 games. Do you get 8 rows? Why does joining to the "one" side (developers) not change the count?

**A2.** Now join to the "many" side:
```sql
SELECT g.title, r.rating
FROM games g
JOIN reviews r ON r.game_id = g.game_id
ORDER BY g.title;
```
Predict the count before running. Which game(s) appear more than once, and why? Which games are **absent** — and what does their absence tell you about `INNER JOIN`?

**A3.** `Indie Newcomer`'s game references developer 5, but suppose a game had `developer_id` set to NULL (a studio that closed — recall lesson 04's `SET NULL`). Would that game appear in A1's inner join? Predict, then test it:
```sql
SELECT g.title, d.name
FROM games g
JOIN developers d ON d.developer_id = g.developer_id
WHERE g.developer_id IS NULL;   -- how many rows can this ever return?
```

---

## Part B — Outer joins

**B1.** Change A2 from `JOIN` to `LEFT JOIN`. Predict the new count first.
```sql
SELECT g.title, r.rating
FROM games g
LEFT JOIN reviews r ON r.game_id = g.game_id
ORDER BY g.title;
```
How many rows now? Which rows are new compared to A2, and what is in their `rating` column?

**B2.** Find every game together with *how many* reviews it has, **including games with zero** (predict which show 0):
```sql
SELECT g.title, count(r.review_id) AS review_count
FROM games g
LEFT JOIN reviews r ON r.game_id = g.game_id
GROUP BY g.title
ORDER BY review_count, g.title;
```
Why `count(r.review_id)` and not `count(*)`? Predict what `count(*)` would give for an unreviewed game, then try it and explain the difference. *(This is the lesson-02 "aggregates ignore NULL" thread — lesson 07 goes deeper.)*

**B3.** Use a `FULL OUTER JOIN` to list every achievement alongside every user who unlocked it, keeping **both** achievements nobody unlocked **and** (hypothetically) unlocks with no achievement. Which achievements come back with a NULL user?

---

## Part C — Join inflation (the headline)

**C1.** **Predict the row count** for Cyberpunk 2077 (game 3) before running — it has 3 genres and 2 achievements:
```sql
SELECT g.title, ge.name AS genre, a.name AS achievement
FROM games g
JOIN game_genres gg ON gg.game_id = g.game_id
JOIN genres ge      ON ge.genre_id = gg.genre_id
JOIN achievements a ON a.game_id   = g.game_id
WHERE g.title = 'Cyberpunk 2077';
```
How many rows? Explain the number as a product. What is this phenomenon called?

**C2.** A colleague writes this to "count Cyberpunk's genres" and gets a surprising number:
```sql
SELECT count(*) AS genre_count
FROM games g
JOIN game_genres gg ON gg.game_id = g.game_id
JOIN achievements a ON a.game_id = g.game_id
WHERE g.title = 'Cyberpunk 2077';
```
Predict the result. Cyberpunk has 3 genres — why isn't the answer 3? Diagnose precisely what inflated it, then fix the query to return 3 **two different ways** (hint: one uses `COUNT(DISTINCT …)`; one removes the irrelevant join).

**C3.** Generalise: without running it, predict how many rows a genres×achievements join produces for `Hades` (game 5). Check your reasoning against the data (`game_genres` and `achievements` for game 5), then run it.

---

## Part D — Anti-joins (finding the gaps)

**D1.** List every game with **no reviews at all**, two ways — a `LEFT JOIN … IS NULL` and a `NOT EXISTS`. Predict the set first.
```sql
-- (a)
SELECT g.title FROM games g
LEFT JOIN reviews r ON r.game_id = g.game_id
WHERE r.review_id IS NULL ORDER BY g.title;
```
Write (b) with `NOT EXISTS` yourself. Do they agree? Why is it `IS NULL`, not `= NULL`?

**D2.** In the LEFT-JOIN version, what breaks if you filter on `WHERE r.rating IS NULL` instead of `WHERE r.review_id IS NULL`? (Think: could a *real* review have a NULL rating? Could a real review row have a NULL `review_id`?) Explain why you must test a **non-nullable right-side key**.

**D3.** Find every user who has unlocked **no** achievement. Predict the set, then write it as an anti-join.

---

## Stretch (optional)

**S1.** Write one query that lists each **developer** with the number of **distinct games that have at least one review**, including developers whose games have no reviews (show 0). Beware inflation: a game with 3 reviews must not count as 3 games. Which developer(s) show 0?

**S2.** A `CROSS JOIN` of `genres` (7 rows) and `developers` (5 rows) produces how many rows? Predict, run `SELECT count(*) FROM genres CROSS JOIN developers;`, and explain when a cross join is a deliberate tool versus the accidental result of forgetting an `ON` clause.
