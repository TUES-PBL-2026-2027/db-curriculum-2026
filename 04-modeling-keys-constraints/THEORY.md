# Lesson 04 — Keys and Constraints

**Module 2 · Relational modeling and schema design**

> **By the end of this lesson you should be able to:** distinguish **candidate**, **primary**, and **foreign** keys, and **composite** from single-column keys; choose between a **surrogate** and a **natural** key with reasons; use **referential actions** (`ON DELETE CASCADE / SET NULL / RESTRICT`) to say *what happens* when a referenced row is deleted; and pick the right **type** for a column — exact `numeric` money and fixed-width `char(2)` codes versus free-text `text`.

---

## 1. The vocabulary of keys

A **key** is a set of columns that identifies rows. The relational model distinguishes several kinds; the differences are not pedantry — they drive real design choices.

| Term | Definition | In the storefront |
|---|---|---|
| **Superkey** | Any column set that is unique across rows (possibly with redundant columns). | `(game_id, title)` is a superkey — unique, but `title` is redundant. |
| **Candidate key** | A *minimal* superkey: unique, with no removable column. | `game_id`; also `title` *if* titles were guaranteed unique. |
| **Primary key** | The one candidate key you choose as *the* identifier. Implies `UNIQUE` + `NOT NULL`. | `games.game_id`. |
| **Alternate key** | A candidate key you did **not** pick as primary; enforced with `UNIQUE`. | `developers.name` (`UNIQUE`). |
| **Composite key** | A key made of **more than one column**. | `game_genres (game_id, genre_id)`. |
| **Foreign key** | A column set referencing another table's key; gives referential integrity. | `games.developer_id → developers`. |

> A table can have **several candidate keys** but exactly **one primary key**. The others become `UNIQUE` constraints (alternate keys). In `developers`, both `developer_id` and `name` are candidate keys; we chose the first as primary and enforced the second with `UNIQUE`.

---

## 2. Natural vs. surrogate keys

When choosing a primary key, you pick between:

- A **natural key** — data that already identifies the entity in the real world (an ISBN, an ISO country code, an email).
- A **surrogate key** — an artificial, meaningless-but-stable identifier the database makes up (`game_id`, `review_id`), typically an auto-generated integer.

| | Natural key | Surrogate key |
|---|---|---|
| **Meaning** | Carries real-world meaning | None — just an identity |
| **Stability** | Can change (people rename things; "facts" turn out wrong) | Never changes |
| **Width in FKs** | Can be wide/multi-column, repeated everywhere | Small, uniform integer |
| **Risk** | A changing natural key must cascade everywhere it's referenced | Needs a separate `UNIQUE` to stop duplicate real-world rows |

The pragmatic default in application databases is a **surrogate primary key**, *plus* a `UNIQUE` constraint on the natural key to prevent duplicates. Our new `reviews` table shows exactly this pattern, and *why* a natural key failed here:

```sql
CREATE TABLE reviews (
    review_id   integer PRIMARY KEY,                      -- surrogate: stable identity
    user_id     integer NOT NULL REFERENCES users (user_id)  ON DELETE CASCADE,
    game_id     integer NOT NULL REFERENCES games (game_id)  ON DELETE CASCADE,
    rating      integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
    body        text,
    reviewed_on date    NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE (user_id, game_id, reviewed_on)                 -- a candidate key, enforced separately
);
```

Why not make `(user_id, game_id)` the primary key, as you might have in lesson 03? Because the business rule changed: **a user may review a game more than once over time** (e.g. after a patch). So `(user_id, game_id)` is *not* unique and cannot be the primary key. We use a surrogate `review_id`, and express the (weaker) real rule — "at most one review per user per game per day" — as a separate composite `UNIQUE`. The seed data has `ivan` reviewing *Cyberpunk 2077* twice, on different dates, which is now legal.

> **Lesson:** the right key depends on the **rules**, not on habit. When the natural key stops being unique, a surrogate key plus a `UNIQUE` constraint keeps both identity and the real invariant.

---

## 3. Referential actions — what happens on delete

Lesson 03 showed that deleting a developer with games was **blocked**. That is just the *default*. A foreign key can specify what should happen to the child rows when the parent is deleted (or its key updated):

| Action | On deleting the parent row… | Use when |
|---|---|---|
| `RESTRICT` / `NO ACTION` (default) | …the delete is **rejected** if children exist. | The reference must never dangle and you want an explicit cleanup first. |
| `CASCADE` | …the children are **deleted too**. | Children are meaningless without the parent (tag rows, a game's reviews). |
| `SET NULL` | …the child's FK column becomes **NULL**. | The relationship is optional; the child survives as "unknown". |
| `SET DEFAULT` | …the child's FK column becomes its column default. | Rare; needs a sensible default parent. |

Our Stage-4 schema makes a deliberate choice per relationship:

```sql
-- A game survives if its studio closes, becoming "unknown studio":
developer_id integer REFERENCES developers (developer_id) ON DELETE SET NULL

-- Deleting a game should remove its genre tags (they mean nothing alone):
game_id integer NOT NULL REFERENCES games (game_id) ON DELETE CASCADE

-- But a genre in use must not be deletable out from under games:
genre_id integer NOT NULL REFERENCES genres (genre_id) ON DELETE RESTRICT

-- A user's reviews die with the user:
user_id integer NOT NULL REFERENCES users (user_id) ON DELETE CASCADE
```

Observe them:

```sql
DELETE FROM developers WHERE developer_id = 1;    -- Valve's games survive; developer_id → NULL
DELETE FROM games WHERE game_id = 3;              -- Cyberpunk's genre tags cascade away
DELETE FROM genres WHERE genre_id = 1;            -- ERROR: Action is still used (RESTRICT)
```

> **`CASCADE` is powerful and dangerous.** It silently deletes related data. Choose it only where the child genuinely cannot exist without the parent, and be aware a single `DELETE` may remove far more than it names. For important parents, `RESTRICT` + an explicit cleanup is safer.

---

## 4. Choosing types, revisited

Two threads promised in Module 1 come due here.

### Money: `numeric(p,s)` vs. integer minor units

Module 1 stored price as integer `price_cents`. Stage 4 switches to `price_eur numeric(8,2)`:

```sql
price_eur numeric(8,2) NOT NULL CHECK (price_eur >= 0)   -- 8 total digits, 2 after the point
```

`numeric(p,s)` (a.k.a. `decimal`) stores **exact** decimals: `p` significant digits, `s` of them after the decimal point. `numeric(8,2)` holds up to `999999.99`. Both approaches are **correct** and avoid the floating-point money bug from lesson 01; they trade off differently:

| | Integer cents | `numeric(8,2)` euros |
|---|---|---|
| Exactness | Exact (integers) | Exact (fixed decimal) |
| Reads naturally | `1999` needs mental `/100` | `19.99` is the price |
| Arithmetic | Plain integer math; you manage scaling | Decimal math built in |
| Fractional cents | Impossible (sometimes a feature) | Possible if you widen scale |

> **Never `float`/`real`/`double precision` for money** (lesson 01). Pick integer minor units *or* `numeric`; we use `numeric` from here on because the prices read naturally in queries.

### Text: `text` vs. `varchar(n)` vs. `char(n)`

The practical PostgreSQL rule (promised in lesson 01's "prefer `text`"):

- **Default to `text`.** In PostgreSQL `text` and `varchar(n)` have *identical* performance; an arbitrary length cap like `varchar(50)` mostly just causes painful `ALTER` migrations the day a value needs 51 characters. If a maximum truly matters, express it as a `CHECK (char_length(col) <= n)` on a `text` column, where it's visible and easy to change.
- **Use `char(n)` / `varchar(n)` for genuinely standardized, fixed-domain codes** — values drawn from a controlled set with a known, meaningful width. ISO country codes are the textbook case:

```sql
country      text,                                        -- display name: free, variable
country_code char(2) CHECK (country_code ~ '^[A-Z]{2}$')  -- ISO 3166-1 alpha-2: exactly 2 letters
```

`country` ("United States", "Czechia") is unpredictable free text → `text`. `country_code` ("US", "PL") is always exactly two uppercase letters from a standard → `char(2)`, and the `CHECK` with a regex documents and enforces the format. This is the general principle: **fixed-width `char`/`varchar(n)` for standardized codes, `text` for everything else.**

---

## Key terms

- **Candidate / primary / alternate / composite / foreign key** — the key taxonomy.
- **Surrogate vs. natural key** — artificial stable id vs. real-world identifier; default to surrogate PK + `UNIQUE` on the natural key.
- **Referential action** — `CASCADE` / `SET NULL` / `RESTRICT` / `SET DEFAULT`: what happens to children on parent delete.
- **`numeric(p,s)`** — exact fixed-point decimal; correct for money.
- **`text` vs. `char(n)`** — free text vs. standardized fixed-width codes.

## Common misconceptions this lesson targets

1. *"A table has one key."* — It can have several candidate keys; one is primary, the rest `UNIQUE`.
2. *"Always use the natural key as the primary key."* — Only if it is stable and unique forever; otherwise surrogate PK + `UNIQUE`.
3. *"Foreign keys always block deletes."* — Only with `RESTRICT`/default; `CASCADE` and `SET NULL` are explicit choices.
4. *"`CASCADE` is just convenient."* — It silently deletes related data; use deliberately.
5. *"`varchar(50)` is safer / faster than `text`."* — Not in PostgreSQL; prefer `text` + a `CHECK` if a limit is real; reserve `char(n)` for standardized codes.

---

**Next:** Lesson 05 — functional dependencies, normalization through 3NF, the update/insert/delete **anomalies** that bad schemas suffer, and the one place we *deliberately* denormalize: capturing the price a buyer actually paid, independent of the current price.
