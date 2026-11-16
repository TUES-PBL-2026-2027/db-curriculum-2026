# Lesson 04 — Practice

**Module 2 · Keys and Constraints**

> **Predict → Run → Explain.** The referential-action tasks (Part C) each *change* the data — reset with `setup.sql` between experiments when asked. Predict the outcome before every delete.

## Setup

```bash
psql -d storefront -f 04-modeling-keys-constraints/setup.sql     # resets to Stage 4
storefront
```

---

## Part A — Keys

**A1.** `developers` has two candidate keys. Name them. Which is the primary key, and how is the other one enforced? *(Hint: `\d developers`.)*

**A2.** Why is `review_id` a surrogate key here instead of using `(user_id, game_id)` as the primary key? Find the seed data that would be **illegal** under a `(user_id, game_id)` primary key but is legal now. *(Hint: look for a user who reviewed the same game twice.)*

**A3.** The `reviews` table has a composite `UNIQUE (user_id, game_id, reviewed_on)`. **Predict** whether this insert succeeds, then run it:
```sql
INSERT INTO reviews (review_id, user_id, game_id, rating, reviewed_on)
VALUES (99, 1, 3, 5, DATE '2020-12-12');
```
Explain using the existing reviews. *(Reset afterwards if it changed anything.)*

---

## Part B — Types done right

**B1.** List each game's title and `price_eur`, most expensive first. Confirm the prices read as natural euros (e.g. `19.99`), not cents.

**B2.** **Predict pass/fail**, then run:
```sql
INSERT INTO developers (developer_id, name, country, country_code)
VALUES (9, 'Lowercase Co', 'France', 'fr');
```
What rejects it? Fix the statement so it succeeds, then clean up (`DELETE FROM developers WHERE developer_id = 9;`).

**B3.** A teammate proposes `country_code varchar(50)` "to be safe." Argue in two sentences why `char(2)` with the regex `CHECK` is the better model for an ISO country code — and why `country` (the name) should stay `text`.

---

## Part C — Referential actions (reset between each)

**C1. SET NULL.** **Predict**, then run:
```sql
DELETE FROM developers WHERE developer_id = 1;         -- Valve
SELECT game_id, title, developer_id FROM games WHERE game_id IN (1, 2);
```
What happened to Half-Life 2 and Portal 2? Which action caused it?
*Reset:* `psql -d storefront -f 04-modeling-keys-constraints/setup.sql`

**C2. CASCADE.** **Predict** how many `game_genres` rows exist for Cyberpunk (game 3), then:
```sql
SELECT count(*) FROM game_genres WHERE game_id = 3;    -- before
DELETE FROM games WHERE game_id = 3;
SELECT count(*) FROM game_genres WHERE game_id = 3;    -- after
```
Explain the "after" count. What else got deleted that the `DELETE` never mentioned? *(Hint: did Cyberpunk have reviews?)*
*Reset afterwards.*

**C3. RESTRICT.** **Predict**, then run:
```sql
DELETE FROM genres WHERE genre_id = 1;                 -- Action
```
Why is this rejected when C1 and C2 were allowed? What would you have to do first to delete the Action genre?

---

## Part D — Design decisions

**D1.** For each relationship below, state which referential action you'd choose and why:
- a game's **reviews** when the game is deleted;
- a user's **reviews** when the user is deleted;
- a game's **developer** when the developer is deleted;
- a **genre** that games still reference.

Then check your choices against the actual FK definitions in `setup.sql`.

**D2.** The store wants to add **wishlists**: a user can wishlist many games; a game can be wishlisted by many users; each (user, game) wishlist entry is recorded once, with the date added. Write the `CREATE TABLE`: choose the primary key (natural or surrogate — justify), the foreign keys, and the right `ON DELETE` action for each.

---

## Stretch (optional)

**S1.** Add a `CHECK` to `games` (on paper, as an `ALTER TABLE ... ADD CONSTRAINT`) enforcing that a **published** game must have a `released_on` date, while an unpublished game may leave it NULL. *(Hint: a `CHECK` can reference several columns: `(NOT is_published) OR (released_on IS NOT NULL)`.)* Why does this belong in the database rather than the application?

**S2.** `numeric(8,2)` caps prices at `999999.99`. What happens if you try `INSERT ... price_eur = 12345678.00`? Predict, run (with a throwaway `game_id`), and explain the error. Reset afterwards.
