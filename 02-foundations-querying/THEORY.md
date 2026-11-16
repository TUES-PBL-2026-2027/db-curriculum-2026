# Lesson 2 — Querying & Integrity Basics

**Module 1 · Database foundations and basic SQL**

> **By the end of this lesson you should be able to:** filter rows with precise boolean conditions and order results deterministically; reason correctly about `NULL` using **three-valued logic**; distinguish `NULL` from `0` and from the empty string; and define the first integrity **constraints** (`NOT NULL`, `UNIQUE`, `CHECK`, `PRIMARY KEY`, `DEFAULT`) that stop bad data from ever entering the database.

---

## 1. Filtering: `WHERE` in depth

`WHERE` keeps only the rows for which a condition is **true**. The building blocks:

```sql
SELECT title, price_cents FROM games
WHERE price_cents < 2000;                    -- comparison

SELECT * FROM games
WHERE developer_id = 1 AND is_published;     -- AND / is_published is already boolean

SELECT * FROM games
WHERE price_cents = 0 OR price_cents > 3000; -- OR

SELECT * FROM games
WHERE NOT is_published;                      -- NOT
```

Useful operators you will reach for constantly:

| Operator | Meaning | Example |
|---|---|---|
| `=`, `<>`, `<`, `<=`, `>`, `>=` | Comparisons (`<>` is "not equal") | `price_cents >= 2000` |
| `BETWEEN a AND b` | Inclusive range | `price_cents BETWEEN 1000 AND 3000` |
| `IN (...)` | Membership in a list | `developer_id IN (1, 3)` |
| `LIKE` / `ILIKE` | Pattern match (`%` = any run, `_` = one char); `ILIKE` is case-insensitive | `title ILIKE '%hades%'` |

> **Precedence trap.** `AND` binds tighter than `OR`. `a OR b AND c` means `a OR (b AND c)`. When in doubt, **parenthesise** — it costs nothing and prevents silent logic bugs.

---

## 2. Ordering: `ORDER BY`

A relation has no inherent order (Lesson 1). `ORDER BY` is the *only* way to guarantee one.

```sql
SELECT title, price_cents, released_on
FROM games
ORDER BY price_cents DESC, title ASC;     -- price high→low; ties broken by title A→Z
```

- `ASC` (default) ascending, `DESC` descending.
- You may sort by several keys; later keys break ties in earlier ones.
- Pair with `LIMIT n` (and `OFFSET`) to get "top N" results:

```sql
SELECT title, price_cents FROM games
WHERE is_published
ORDER BY price_cents DESC
LIMIT 3;                                   -- the three most expensive published games
```

> Without `ORDER BY`, `LIMIT 3` returns *some* three rows — not necessarily the three you mean. "Top N" always needs an explicit order.

---

## 3. `NULL` — the absence of a value

This section is the intellectual heart of the lesson. Professionals get `NULL` wrong; make sure you do not.

`NULL` means **"unknown / not applicable / missing."** It is emphatically **not**:

- the number `0` (a game that is **free** has `price_cents = 0`, a known value);
- the empty string `''` (a username could theoretically be `''` — a known, empty value);
- `false`.

In our data, `georgi` has `email = NULL` — we simply *don't know* his email. `Hades II` has `released_on = NULL` — the release date *isn't decided yet*.

### Three-valued logic

Because `NULL` means "unknown," SQL conditions evaluate to one of **three** values: **true**, **false**, or **unknown**. Any comparison *with* `NULL` yields **unknown**:

```sql
SELECT NULL = NULL;      -- NULL (unknown!) — "is an unknown value equal to another unknown value?"
SELECT NULL = 5;         -- NULL (unknown)
SELECT NULL <> 5;        -- NULL (unknown)
```

And — the crucial consequence — **`WHERE` keeps a row only when the condition is true, not when it is unknown.**

```sql
SELECT username FROM users WHERE email = NULL;      -- returns ZERO rows (never true!)
SELECT username FROM users WHERE email <> NULL;     -- also ZERO rows
```

This is the single most common `NULL` mistake. To test for null you must use **`IS NULL` / `IS NOT NULL`**:

```sql
SELECT username FROM users WHERE email IS NULL;      -- georgi, petar, dimitar
SELECT username FROM users WHERE email IS NOT NULL;  -- ivan, maria, elena
```

### Truth tables (keep these nearby)

```
   AND  │ T   F   U            OR   │ T   F   U           NOT │
   ─────┼──────────            ─────┼──────────           ────┼────
    T   │ T   F   U             T   │ T   T   T            T  │ F
    F   │ F   F   F             F   │ T   F   U            F  │ T
    U   │ U   F   U             U   │ T   U   U            U  │ U
```

Note the sensible bits: `F AND U = F` (a false conjunct kills it regardless), `T OR U = T` (a true disjunct wins regardless). Everything else involving `U` stays `U`.

### `NULL` in other places

- **Aggregates ignore `NULL`.** `COUNT(email)` counts non-null emails; `COUNT(*)` counts rows. (More in Module 3.)
- **Ordering.** PostgreSQL sorts `NULL` as *larger than everything* by default: `NULLS LAST` for `ASC`, `NULLS FIRST` for `DESC`. Override with `ORDER BY released_on DESC NULLS LAST`.
- **`COALESCE`** gives a fallback: `COALESCE(email, '(no email)')` yields the email or the literal when null.

---

## 4. Integrity constraints — rules the data cannot break

So far nothing stops someone inserting a negative price or two users with the same name. **Constraints** move those rules *into the database*, where they are enforced for **every** client, forever — not scattered across application code that might forget them.

### `NOT NULL`

The column must always have a value.

```sql
title text NOT NULL     -- every game must have a title
```

### `PRIMARY KEY`

Uniquely identifies each row. Implies **`UNIQUE` + `NOT NULL`**. Every table should have one.

```sql
game_id integer PRIMARY KEY
```

### `UNIQUE`

No two rows may share the value.

```sql
username text NOT NULL UNIQUE     -- usernames can't repeat
email    text UNIQUE              -- emails can't repeat ...
```

> **Subtle but important:** `UNIQUE` treats `NULL`s as **distinct** from one another. That is *why* several users can have `email IS NULL` at once without violating the `UNIQUE (email)` constraint — two "unknowns" are not considered equal. This is three-valued logic showing up in constraint enforcement.

### `CHECK`

An arbitrary boolean rule per row.

```sql
price_cents  integer NOT NULL CHECK (price_cents >= 0)              -- no negative prices
founded_year integer CHECK (founded_year BETWEEN 1950 AND 2100)    -- plausible years only
```

> A `CHECK` that evaluates to **unknown** (because of a `NULL`) is treated as **satisfied** — the row is allowed. `founded_year` is `NULL` for *Indie Newcomer*, and the `BETWEEN` check passes because unknown is not a violation. If you need the value present, add `NOT NULL`.

### `DEFAULT`

A value supplied when the inserting statement omits the column.

```sql
is_published boolean NOT NULL DEFAULT true
created_at   timestamptz NOT NULL DEFAULT now()
```

### Watch a constraint bite

```sql
INSERT INTO games (game_id, title, price_cents) VALUES (99, 'Broken', -500);
-- ERROR:  new row for relation "games" violates check constraint "games_price_cents_check"
```

The write is **rejected**. The database stays correct. This is the entire point: *the rule lives with the data, so it cannot be bypassed.*

---

## 5. Modifying only what you mean — safely

Lesson 1 warned about `UPDATE`/`DELETE` without `WHERE`. A professional habit that works even before we learn transactions:

> **Select before you mutate.** Run your `WHERE` clause as a `SELECT` first, confirm it matches exactly the rows you intend, *then* change the verb to `UPDATE`/`DELETE`.

```sql
SELECT * FROM games WHERE developer_id = 5;          -- 1. check what matches
UPDATE games SET is_published = false WHERE developer_id = 5;   -- 2. same WHERE, now mutate
```

In Module 4 we will wrap such operations in **transactions** so they can be rolled back; for now, the select-first habit is your safety net.

---

## Key terms

- **Three-valued logic** — conditions are true / false / **unknown**; `WHERE` keeps only *true*.
- **`IS NULL` / `IS NOT NULL`** — the *only* correct null tests.
- **Constraint** — a rule enforced by the database: `NOT NULL`, `PRIMARY KEY`, `UNIQUE`, `CHECK`, `DEFAULT`.
- **`COALESCE`** — first non-null argument; a null fallback.

## Common misconceptions this lesson targets

1. *"`WHERE email = NULL` finds users with no email."* — No; it returns nothing. Use `IS NULL`.
2. *"`NULL` is just zero / empty string."* — No; it is *unknown*, and behaves differently in logic, aggregates, and ordering.
3. *"A `CHECK` with a NULL fails."* — No; unknown counts as satisfied.
4. *"`UNIQUE` forbids multiple NULLs."* — No; NULLs are distinct, so many are allowed.
5. *"Validation belongs in the app."* — Put invariants in the database; the app can forget, the constraint cannot.

---

**Next:** Module 2 — relationships between tables, foreign keys, and designing a schema that resists anomalies as the storefront grows.
