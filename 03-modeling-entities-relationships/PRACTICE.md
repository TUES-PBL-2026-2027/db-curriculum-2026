# Lesson 03 — Practice

**Module 2 · Entities, Relationships & Cardinality**

> **Predict → Run → Explain.** Write your prediction before running. The foreign-key and junction-table tasks are designed so a wrong prediction teaches you where referential integrity bites. Write the prediction down first — the effort of predicting is what makes the answer stick.

## Setup

```bash
psql -d storefront -f 03-modeling-entities-relationships/setup.sql     # resets to Stage 3
storefront                                                     # interactive shell
```

---

## Part A — Reading the relationships

**A1.** List every game with its developer's **name** (not id). *(Hint: a `JOIN` between `games` and `developers` on `developer_id`.)*

**A2.** `Untitled Project`'s developer is `Indie Newcomer`. Show all games made by that developer, by name — without hard-coding `developer_id = 5` (look the developer up by name).

**A3.** How many genres does `Cyberpunk 2077` have, and which ones? *(Hint: join `games` → `game_genres` → `genres`.)*

---

## Part B — Cardinality in action

**B1.** **Predict:** which games have **no genre** at all? Then write a query to find them. *(Hint: a game with no matching rows in `game_genres`.)*

**B2.** Which genre has the **most** games? Return the genre name and the count, highest first.

**B3.** **Predict first.** How many rows does this return, and why might the number surprise you?
```sql
SELECT g.title FROM games g JOIN game_genres gg ON gg.game_id = g.game_id;
```
Compare the row count to the number of games. Explain the difference. *(This previews "join inflation" from Module 3.)*

---

## Part C — Foreign keys enforce referential integrity

**C1.** **Predict pass/fail**, then run each:
```sql
INSERT INTO games (game_id, title, developer_id, price_cents) VALUES (99, 'Ghost', 999, 100);
INSERT INTO games (game_id, title, developer_id, price_cents) VALUES (99, 'Mystery', NULL, 100);
INSERT INTO game_genres (game_id, genre_id) VALUES (1, 1);
INSERT INTO game_genres (game_id, genre_id) VALUES (7, 3);
INSERT INTO game_genres (game_id, genre_id) VALUES (7, 999);
```
For each, name which constraint (and on which table) is responsible for the outcome.
*(Reset with `setup.sql` afterwards — some of these succeed.)*

**C2.** **Predict:** what happens if you try to delete `Supergiant Games` (developer 3) while it still has games?
```sql
DELETE FROM developers WHERE developer_id = 3;
```
Run it. Explain the error in terms of referential integrity. *(We fix this properly with referential actions in lesson 04 — for now, just observe that the database protects the reference.)*

---

## Part D — Modeling on paper

**D1.** The storefront wants to add **user reviews**: a user writes a review of a game (a rating 1–5 and some text). A user can review many games; a game can be reviewed by many users; but a user may review a given game **at most once**.
- What is the cardinality between `users` and `games` for "reviews"?
- Sketch the table(s) you would add. What is the primary key of the review table, and why?
- Which two foreign keys does it need?

**D2.** Suppose instead each user may write **several** reviews of the same game over time (e.g. after updates). How does your answer to D1 change — specifically, can the primary key still be `(user_id, game_id)`? What would you use instead?

---

## Stretch (optional)

**S1.** Find every **pair of games that share at least one genre**, without listing a game paired with itself and without listing both `(A,B)` and `(B,A)`. *(Hint: self-join `game_genres` to itself on `genre_id`, with `g1.game_id < g2.game_id`.)*

**S2.** Add a `char(2)` `country_code` column idea to `developers` on paper: why might an ISO country code be a good case for `char(2)` while the free-text `country` name is better as `text`? (Connect to the text-vs-varchar discussion flagged for this module.)
