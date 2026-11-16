# Lesson 05 — Functional Dependencies & Normalization

**Module 2 · Relational modeling and schema design**

> **By the end of this lesson you should be able to:** state a **functional dependency** and spot one in data; name the three **anomalies** (update, insertion, deletion) a redundant schema suffers; normalize a design through **1NF → 2NF → 3NF** (and recognise **BCNF**); and — just as importantly — justify a *deliberate* denormalization by showing it stores a **different fact**, as with the price a customer actually paid.

---

## 1. Why redundancy rots a schema

Suppose we had designed games as one wide table repeating the developer's details on every game:

```
game_id │ title          │ developer_name   │ dev_country │ dev_founded
────────┼────────────────┼──────────────────┼─────────────┼────────────
   3    │ Cyberpunk 2077 │ CD Projekt Red   │ Poland      │ 1994
   4    │ The Witcher 3  │ CD Projekt Red   │ Poland      │ 1994     ← same facts, repeated
```

Load the deliberately-bad view that mimics this and look:

```sql
SELECT * FROM games_denormalized_bad ORDER BY developer_name, title;
```

The developer's country and founding year are **duplicated on every one of their games**. That redundancy causes three classic **anomalies**:

| Anomaly | Symptom in the bad design |
|---|---|
| **Update anomaly** | CD Projekt moves to Warsaw — you must update *every* game row; miss one and the data now disagrees with itself. |
| **Insertion anomaly** | You cannot record a brand-new studio until it has at least one game — there's nowhere to put a developer with no games. |
| **Deletion anomaly** | Delete a studio's last game and you lose the studio's details entirely — the only copy vanished. |

Our real schema avoids all three because developer facts live in **one** place (`developers`) and games merely **reference** them. Normalization is the systematic theory of *why* that is better and *how* to get there.

---

## 2. Functional dependencies

A **functional dependency (FD)** `X → Y` means: *knowing X determines exactly one Y.* It is a statement about the real-world rules, read off the meaning of the data, not from a particular table of rows.

In the storefront:

- `game_id → title, price_eur, developer_id` — a game id determines its one title, price, developer.
- `developer_id → name, country, founded_year` — a developer id determines that developer's details.
- `genre_id → name` — a genre id determines its name.
- `(purchase_id, game_id) → price_paid_eur` — an order line is identified by the pair.

The trouble in the bad wide table was a **transitive dependency**:

```
game_id → developer_id → dev_country
```

`game_id` determines `developer_id`, which in turn determines `dev_country`. So `dev_country` depends on `game_id` only *through* `developer_id` — it is not a direct fact about the game. Storing `dev_country` in the games table therefore repeats it. Removing exactly this kind of indirect dependency is what 3NF is about.

---

## 3. The normal forms (through 3NF)

Normalization proceeds in stages. Each **normal form** is a stricter condition; a table in 3NF is also in 2NF and 1NF.

### First Normal Form (1NF) — atomic values, no repeating groups

Every column holds a **single value**; no lists, no arrays-as-columns, no `genre1, genre2, genre3`.

> This is *why* lesson 03 forbade "a column with a list of genre ids" and used the `game_genres` junction table. The junction is the 1NF-respecting way to model many values.

### Second Normal Form (2NF) — no partial dependency on part of a composite key

In a table whose key is **composite**, every non-key column must depend on the **whole** key, not just part of it.

Classic violation (a hypothetical bad order-line table):

```
purchase_items_bad(purchase_id, game_id, price_paid_eur, game_title)
                    └──────── composite key ────────┘
```

Here `game_title` depends only on `game_id` (half the key), not on the whole `(purchase_id, game_id)`. That's a **partial dependency** — a 2NF violation. Fix: `game_title` belongs in `games`, keyed by `game_id` alone; the order line keeps only what depends on the full key (`price_paid_eur`). Our real `purchase_items` is already 2NF.

### Third Normal Form (3NF) — no transitive dependency

Non-key columns must depend on the key **directly**, not through another non-key column. This is exactly the `game_id → developer_id → dev_country` problem from §2. Fix: give developers their own table; reference it by key.

> **A memorable summary (Codd):** every non-key column must depend on *"the key, the whole key, and nothing but the key."* The three clauses correspond to 1NF (there is a key / atomic), 2NF (the *whole* key), and 3NF (*nothing but* the key).

### BCNF (a stricter 3NF) — brief note

**Boyce–Codd Normal Form** tightens 3NF: *every* determinant (left side of an FD) must be a candidate key. It differs from 3NF only in unusual cases with overlapping candidate keys. For this course, aim for 3NF; recognise BCNF as the stricter version and know it exists. Our storefront schema is in BCNF as well.

---

## 4. Normalizing by example

Take the bad wide shape and normalize it:

```
BAD (one table):
  games_wide(game_id, title, price_eur, developer_name, dev_country, dev_founded)

Step to 3NF — split off the transitively-dependent developer facts:
  developers(developer_id PK, name, country, founded_year)
  games(game_id PK, title, price_eur, developer_id FK → developers)
```

Each fact now lives once. Changing a developer's country is a single `UPDATE developers`. A studio with no games is a plain `developers` row (no insertion anomaly). Deleting a game never erases a studio (no deletion anomaly). This is precisely our Stage-4/5 schema.

---

## 5. Deliberate denormalization: the price actually paid

Normalization is a default, not a dogma. Sometimes repeating a value is **correct** — when the "duplicate" is actually a **different fact**. The storefront's purchase flow is the canonical example.

```sql
CREATE TABLE purchase_items (
    purchase_id    integer      NOT NULL REFERENCES purchases (purchase_id) ON DELETE CASCADE,
    game_id        integer      NOT NULL REFERENCES games (game_id)         ON DELETE RESTRICT,
    price_paid_eur numeric(8,2) NOT NULL CHECK (price_paid_eur >= 0),     -- frozen at purchase
    PRIMARY KEY (purchase_id, game_id)
);
```

It looks like we are duplicating `games.price_eur` into `price_paid_eur`. We are not. Consider:

```sql
SELECT pi.purchase_id, g.title, pi.price_paid_eur, g.price_eur AS current_price
FROM purchase_items pi JOIN games g ON g.game_id = pi.game_id
ORDER BY pi.purchase_id;
```

| purchase | title | price_paid_eur | current_price |
|---|---|---|---|
| 1 | Hades | **14.99** | 24.99 |
| 1 | Cyberpunk 2077 | 59.99 | 59.99 |
| 3 | The Witcher 3 | **11.99** | 39.99 |

`ivan` bought *Hades* in a sale for **14.99**; the catalogue price today is 24.99. If `purchase_items` merely *referenced* the current `games.price_eur`, then raising the price later would silently rewrite history — his receipt, the store's revenue reports, any refund, would all become wrong. **"The price the customer paid on that date" is a distinct fact from "the current catalogue price."** Freezing it in the order line is not redundancy; it is recording the fact that mattered at that moment.

> **The test for justified denormalization:** is the stored value *the same fact* as the source (then normalize — reference it) or a *point-in-time snapshot / different fact* (then store it)? Historical prices, invoice totals, and audit records are different facts. A developer's current country copied onto every game is the same fact — normalize that.

Other legitimate reasons to denormalize (performance caches, precomputed aggregates) exist and come up in Module 6; they are *optimizations* you justify with measurement, and you accept the cost of keeping copies in sync.

---

## Key terms

- **Functional dependency `X → Y`** — X determines a unique Y.
- **Transitive / partial dependency** — Y depends on the key via another column / via only part of a composite key.
- **Anomalies** — update, insertion, deletion problems caused by redundancy.
- **1NF / 2NF / 3NF / BCNF** — atomic values; whole-key dependence; no transitive dependence; every determinant a candidate key.
- **Justified denormalization** — storing a *different fact* (e.g. historical `price_paid_eur`), not the same one.

## Common misconceptions this lesson targets

1. *"Normalization is about having many tables."* — It's about each fact living in exactly one place; tables are the consequence.
2. *"Denormalization is always a hack."* — Not when the value is a distinct fact (historical price) or a measured optimization.
3. *"Storing the price twice violates normalization."* — Only if it's the *same* fact; the price *paid* is a different fact from the *current* price.
4. *"3NF needs memorizing rules."* — "The key, the whole key, and nothing but the key" captures 1→3NF.
5. *"1NF is obvious / irrelevant."* — It's exactly why M:N needs a junction table, not a list column (lesson 03).

---

**Next:** Module 3 — *Querying relational data.* Now that the schema is sound, we extract answers from it: joins (and the row-inflation you glimpsed in lesson 03), aggregation, subqueries, CTEs, and window functions — reporting over this very storefront.
