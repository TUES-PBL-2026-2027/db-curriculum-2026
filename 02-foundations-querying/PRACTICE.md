# Lesson 2 — Practice

**Module 1 · Querying & Integrity Basics**

> **Predict → Run → Explain.** Write your prediction *before* running. The null tasks in particular are designed so that a confident wrong prediction teaches more than a lucky right one. Write the prediction down first — the effort of predicting is what makes the answer stick.

## Setup

```bash
psql -d storefront -f setup.sql     # resets to this lesson's Stage-2 schema + data
psql -d storefront
```

---

## Part A — Precise filtering

**A1.** Published games priced **between €10.00 and €30.00 inclusive**, cheapest first.

**A2.** Games made by Valve (`developer_id = 1`) **or** Supergiant (`developer_id = 3`). Write it two ways: once with `OR`, once with `IN`.

**A3.** **Predict first.** What does this return, and why might it surprise someone?
```sql
SELECT title FROM games WHERE developer_id = 1 OR developer_id = 3 AND price_cents = 0;
```
Then rewrite it with parentheses to mean *"(Valve or Supergiant) and free."* Compare the two result sets.

**A4.** All games whose title contains "hades", case-insensitive.

---

## Part B — Ordering & top-N

**B1.** The 3 most expensive published games (title + price).

**B2.** All games ordered by `released_on` ascending. **Predict** where the NULL-dated games land. Then re-run forcing them to the **end** regardless of direction.

**B3.** Order games by `price_cents` ascending, breaking ties by `title`. Which games tie on price, and did your tie-breaker order them as you expected?

---

## Part C — NULL and three-valued logic (the core)

**C1.** **Predict the row count for each**, then run all four:
```sql
SELECT username FROM users WHERE email = NULL;
SELECT username FROM users WHERE email <> NULL;
SELECT username FROM users WHERE email IS NULL;
SELECT username FROM users WHERE email IS NOT NULL;
```
Explain why the first two return what they do.

**C2.** **Predict:** what does `SELECT NULL = NULL;` return? Not `true` — why not? What about `SELECT NULL IS NULL;`?

**C3.** List every user with a displayable email, substituting the text `(no email on file)` for those without one. *(Hint: `COALESCE`.)*

**C4.** A colleague wants "all games **not** made by developer 5." They write `WHERE developer_id <> 5`. **Predict**: does this include games whose `developer_id` is `NULL`? (First insert a test game with a `NULL` developer: `INSERT INTO games (game_id, title, price_cents, developer_id) VALUES (50, 'Orphan', 100, NULL);`.) Run the query. Was the orphan included? Explain, then write a version that *does* include unknown-developer games.

---

## Part D — Constraints

**D1.** For each statement below, **predict** whether it succeeds or fails, and which constraint is responsible. Then run each and confirm.
```sql
INSERT INTO games (game_id, title, price_cents) VALUES (60, 'Negative', -1);
INSERT INTO users (user_id, username, email) VALUES (60, 'ivan', 'new@example.bg');
INSERT INTO users (user_id, username, email) VALUES (61, 'newbie', 'ivan@example.bg');
INSERT INTO users (user_id, username) VALUES (62, 'nomail1');
INSERT INTO users (user_id, username) VALUES (63, 'nomail2');
INSERT INTO developers (developer_id, name, founded_year) VALUES (9, 'Timewarp', 1700);
```

**D2.** Explain *in one sentence each* why statements 4 **and** 5 in D1 both succeed even though both users have no email. (This is the UNIQUE-plus-NULL subtlety.)

**D3.** **Design task.** We decide a username must be at least 3 characters. Which constraint type expresses this, and what would the clause look like? (You don't have to alter the table — just write the `CHECK (...)` expression.)

---

## Part E — Safe modification

**E1.** Unpublish every game made by `Indie Newcomer` (developer 5). Use the **select-first** habit: show the matching rows, *then* update, *then* verify.

**E2.** *The Witcher 3* goes on sale: €39.99 → €11.99. Update it safely and verify only that one row changed.

---

## Stretch (optional)

**S1.** Using `COUNT`, how many users have an email vs. how many rows are in `users`? Explain the difference between `COUNT(email)` and `COUNT(*)`. *(Preview of Module 3.)*

**S2.** Write a single `WHERE` clause that selects games that are *either* free *or* have no release date — and make sure unknown-dated free games are included exactly once.
