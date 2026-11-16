# Lesson 05 — Practice

**Module 2 · Functional Dependencies & Normalization**

> **Predict → Run → Explain.** Several tasks are *analysis on paper* — normalization is as much reasoning as SQL. For those, write your answer before checking. Write the prediction down first — the effort of predicting is what makes the answer stick.

## Setup

```bash
psql -d storefront -f 05-modeling-normalization/setup.sql     # resets to Stage 5
storefront
```

---

## Part A — Seeing the anomalies

**A1.** Run the deliberately-bad view and study it:
```sql
SELECT * FROM games_denormalized_bad ORDER BY developer_name, title;
```
Identify a developer whose facts (country, founded year) are **repeated** across rows. How many rows would you have to touch to correct CD Projekt Red's country in this flattened shape?

**A2.** For each anomaly, describe concretely what goes wrong *in the bad view's shape* (not the real tables):
- **Update:** CD Projekt Red relocates to Warsaw.
- **Insertion:** you sign a new studio that has not released any game yet.
- **Deletion:** `Indie Newcomer`'s only game (`Untitled Project`) is removed.

**A3.** Show how the **real** schema avoids each of A2's problems — which single table/statement handles each case?

---

## Part B — Functional dependencies

**B1.** Write the functional dependencies for `developers` and for `game_genres`. Which column(s) is the determinant in each?

**B2.** In the bad wide shape `games_wide(game_id, title, price_eur, developer_name, dev_country, dev_founded)`, identify the **transitive dependency** that violates 3NF. Write it as a chain `A → B → C`.

**B3.** Consider a hypothetical `purchase_items_bad(purchase_id, game_id, price_paid_eur, game_title)`. Which normal form does `game_title` violate, and why? What is the fix?

---

## Part C — The price actually paid (the payoff)

**C1.** **Predict:** for purchase 1, what did `ivan` pay for *Hades*, and what is *Hades*'s current price? Then run:
```sql
SELECT pi.purchase_id, g.title, pi.price_paid_eur, g.price_eur AS current_price
FROM purchase_items pi JOIN games g ON g.game_id = pi.game_id
ORDER BY pi.purchase_id, g.title;
```
Which rows show a difference, and why is that difference *correct* rather than a bug?

**C2.** The store raises *Hades* to 29.99:
```sql
UPDATE games SET price_eur = 29.99 WHERE title = 'Hades';
```
Re-run the C1 query. Did `ivan`'s and `maria`'s **paid** prices change? Should they have? Explain in terms of "same fact vs. different fact." *(Reset afterwards.)*

**C3.** Compute each user's **total spend** (sum of what they actually paid across all purchases). Then compute what the same baskets would cost at **today's** prices. Explain why a business cares about the first number, not the second, for revenue.

---

## Part D — Normalize a new requirement

**D1.** Marketing wants to attach a **publisher** to each game (distinct from the developer — e.g. a game developed by Supergiant could be published by a larger company). A junior proposes adding `publisher_name text` and `publisher_country text` **columns to `games`**.
- Which normal form does that proposal violate, and what anomalies would appear?
- Design the normalized alternative (tables, keys, FKs). Is publisher↔game 1:N or M:N? Justify.

**D2.** Decide, for each of these, whether it's **justified denormalization** (store the value) or a **3NF violation to fix** (reference it). Give the one-line reason:
- the line-item `price_paid_eur` on `purchase_items`;
- a `developer_country` column copied onto every `games` row;
- a precomputed `review_count` column on `games` kept in sync by the application;
- an `order_total_eur` stored on `purchases` equal to the sum of its items.

---

## Stretch (optional)

**S1.** Our schema has no `order_total` column — the total is *derived* by summing `purchase_items.price_paid_eur`. Write the query that returns each `purchase_id` with its computed total. What's the trade-off between deriving it on read vs. storing it (and when would Module 6 lead you to store it)?

**S2.** Argue whether `reviews` is in BCNF. Identify every determinant and check each is a candidate key. *(Hint: consider `review_id` and the `UNIQUE(user_id, game_id, reviewed_on)` triple.)*
