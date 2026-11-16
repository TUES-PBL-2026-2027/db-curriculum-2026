# Lesson 1 — Why Databases & the Relational Model

**Module 1 · Database foundations and basic SQL**

> **By the end of this lesson you should be able to:** explain *why* databases exist and what problems they solve that files do not; distinguish a *database* from a *DBMS*; describe the *relational model* in precise terms (relations, tuples, attributes, domains); connect to PostgreSQL with `psql`; create tables, choose appropriate column types, and run your first `INSERT` and `SELECT`.

---

## 1. Why do databases exist?

Every program eventually needs to **remember** things between runs. The naive answer is "write it to a file." That works until it doesn't. Consider a game storefront that keeps its catalogue in a text file:

```
Half-Life 2;9.99;Valve
Portal 2;19.99;Valve
Cyberpunk 2077;59.99;CD Projekt Red
```

This is fine for ten lines. Now imagine the real requirements:

| Requirement | Why the file struggles |
|---|---|
| "Show all games under €20, cheapest first." | You must read the *entire* file and sort in memory every time. |
| "Two people buy the last copy at the same instant." | Two processes writing the same file corrupt each other's changes. |
| "Never allow a game with no title." | Nothing stops a malformed line from being appended. |
| "The developer's name changed — update it everywhere." | 'Valve' is duplicated on every row; you must find and edit each one. |
| "The power died mid-write." | You may be left with half a line and no way to tell. |

A **database management system (DBMS)** exists precisely to solve these problems. It provides, as built-in guarantees, the things you would otherwise have to re-implement (badly) for every application:

- **Efficient queries** over large data — including fast filtering, sorting, and joining — without loading everything into memory.
- **Concurrency control** — many clients reading and writing *at the same time* without corrupting each other.
- **Integrity** — rules the data is *not allowed* to violate (e.g. "price cannot be negative", "every game must have a title").
- **Durability** — once the system says a change is saved, it survives a crash or power loss.
- **A declarative query language (SQL)** — you say *what* you want, not *how* to compute it; the system figures out an efficient plan.

We will spend the whole year unpacking each of these. Today we start at the beginning.

### Database vs. DBMS — a distinction worth getting right

These two words are used loosely in conversation, but they are not the same thing:

- A **database** is the actual collection of data — your storefront's games, users, and purchases.
- A **DBMS** (Database Management System) is the *software* that stores, protects, and serves that data. **PostgreSQL** is a DBMS.

> One PostgreSQL *server* can host **many databases**. In this course each of you will have a database (we will call it `storefront`), served by the one PostgreSQL DBMS running on your machine.

---

## 2. The relational model

Almost every serious database you will meet — PostgreSQL, MySQL, SQL Server, Oracle, SQLite — is built on the **relational model**, proposed by **E. F. Codd in 1970**. Its power is that it rests on a small, precise mathematical idea: data is organised as **relations**.

A **relation** is, informally, a **table**:

```
                    attributes (columns)
            ┌───────────┬──────────────┬─────────────┐
            │ game_id   │ title        │ price_cents │   ← header: name + domain of each attribute
            ├───────────┼──────────────┼─────────────┤
   tuples   │ 1         │ Half-Life 2  │ 999         │   ← each row is a tuple
  (rows)    │ 2         │ Portal 2     │ 1999        │
            │ 3         │ Cyberpunk... │ 5999        │
            └───────────┴──────────────┴─────────────┘
```

The formal vocabulary matters because it makes later reasoning exact:

| Formal term | Everyday term | In our storefront |
|---|---|---|
| **Relation** | Table | `games` |
| **Tuple** | Row | one game |
| **Attribute** | Column | `title`, `price_cents` |
| **Domain** | The type/set of allowed values for an attribute | `price_cents` ∈ integers |
| **Degree** | Number of attributes | `games` has degree 6 |
| **Cardinality** | Number of tuples | `games` has 8 tuples |

Two properties of the model deserve emphasis because beginners silently assume the opposite:

1. **Rows have no inherent order.** A relation is a *set* of tuples. `SELECT * FROM games` may return rows in any order unless you add `ORDER BY`. Never rely on "insertion order."
2. **Columns are identified by name, not position.** You ask for `title`, not "the second column."

> **Why this abstraction wins.** Because the model is about *sets and logic*, you can describe what you want declaratively ("all games cheaper than €20") and let the DBMS choose how to compute it. Decades of research into query optimisation, indexing, and concurrency all build on this one foundation.

---

## 3. Meeting PostgreSQL through `psql`

`psql` is PostgreSQL's interactive terminal. You will live in it this year.

```bash
# Create your working database once:
createdb storefront

# Connect:
psql -d storefront
```

Your prompt becomes `storefront=#`. A few essential **meta-commands** (they start with a backslash and are `psql` features, *not* SQL):

| Command | Does |
|---|---|
| `\dt` | List tables |
| `\d games` | Describe the `games` table (columns, types, constraints) |
| `\l` | List databases |
| `\x` | Toggle expanded (one-field-per-line) output — great for wide rows |
| `\q` | Quit |

Load this lesson's schema and data:

```bash
psql -d storefront -f setup.sql
```

---

## 4. Creating tables and choosing types

Here is the heart of this lesson's `setup.sql`:

```sql
CREATE TABLE games (
    game_id      integer PRIMARY KEY,
    title        text    NOT NULL,
    developer_id integer,
    price_cents  integer NOT NULL,
    released_on  date,
    is_published boolean NOT NULL DEFAULT true
);
```

Every column has a **type** (its domain). Choosing types well is a real design decision — the type is your *first and cheapest line of defence* against bad data.

### PostgreSQL types you will use constantly

| Type | Use for | Notes |
|---|---|---|
| `integer` | Whole numbers (ids, counts) | 4 bytes; range ±2.1 billion. `bigint` if you need more. |
| `text` | Strings of any length | Prefer `text` in PostgreSQL; `varchar(n)` only when a length *limit* is a genuine rule. |
| `boolean` | True/false | Accepts `true`/`false`. |
| `date` | A calendar date | No time-of-day. |
| `timestamptz` | A point in time, timezone-aware | **Prefer over `timestamp`** — it stores an unambiguous instant. |
| `numeric(p,s)` | Exact decimals (money!) | We revisit money below. |

### Money: never use floating point

Notice we store price as `price_cents integer` — **9.99 is stored as `999`.** Why not `price numeric` or a float?

- **Never `float`/`real`/`double precision` for money.** Binary floating point cannot represent `0.10` exactly, so sums drift. `0.1 + 0.2` is famously *not* `0.3`.
- Two correct choices exist: **integer minor units** (cents), which we use for simplicity and speed, or **`numeric(p,s)`**, which stores exact decimals. We will meet `numeric` later; for now, cents keep arithmetic honest and comparisons trivial.

> **Takeaway:** the type you choose is a *constraint*. `price_cents integer` already makes "€9.995" and "nine euros" impossible to store.

---

## 5. Your first CRUD

**CRUD** = Create, Read, Update, Delete — the four fundamental operations on data.

```sql
-- CREATE (insert a row)
INSERT INTO games (game_id, title, developer_id, price_cents, released_on, is_published)
VALUES (9, 'Stray', 5, 2999, DATE '2022-07-19', true);

-- READ (query rows)
SELECT title, price_cents FROM games;

-- UPDATE (change existing rows)
UPDATE games SET price_cents = 1499 WHERE game_id = 3;

-- DELETE (remove rows)
DELETE FROM games WHERE game_id = 9;
```

Two rules to internalise *immediately*, because forgetting them is the most common and most dangerous beginner mistake:

> ### ⚠️ `UPDATE` and `DELETE` without `WHERE` affect **every row**.
> `DELETE FROM games;` empties the table. `UPDATE games SET price_cents = 0;` makes every game free. There is no "undo button" in the shell. We will learn the real safety net — **transactions** — in Module 4. Until then: *look at your `WHERE` clause before you press Enter.*

### `SELECT` is declarative

```sql
SELECT title, price_cents
FROM games
WHERE price_cents < 2000
ORDER BY price_cents;
```

You described a **result** — "titles and prices of games under €20, cheapest first" — not an algorithm. You did not write a loop, open a file, or sort anything yourself. The DBMS parses your request, chooses a plan, and executes it. That separation of *what* from *how* is the single most important idea in this course, and Module 6 is devoted to what happens behind it.

---

## 6. File vs. database — the experiment to carry forward

Keep the opening comparison in mind as a running thread. A flat file can *store* the storefront catalogue, but the DBMS additionally gives us, for free:

- a query (`WHERE price_cents < 2000 ORDER BY price_cents`) that does not scan-and-sort-by-hand;
- rules (`NOT NULL`, `PRIMARY KEY`) that a file cannot enforce — we meet these properly next lesson;
- safe concurrent access and crash durability — the subjects of Modules 4 and 6.

In the practice you will *feel* this difference rather than just read about it.

---

## Key terms

- **DBMS / database** — the software vs. the data it manages.
- **Relational model** — data as relations (tables) of tuples (rows) with named, typed attributes (columns).
- **Relation, tuple, attribute, domain, degree, cardinality** — the precise vocabulary.
- **CRUD** — Create / Read / Update / Delete.
- **Declarative query** — stating *what* you want, not *how* to compute it.

## Common misconceptions this lesson targets

1. *"Rows come back in the order I inserted them."* — No. Without `ORDER BY`, order is undefined.
2. *"A database is just a fancy spreadsheet / file."* — The guarantees (integrity, concurrency, durability, query optimisation) are the whole point.
3. *"I'll store prices as decimals/floats."* — Floating point corrupts money. Use integer minor units or `numeric`.
4. *"`DELETE`/`UPDATE` only touch what I meant."* — Only if the `WHERE` clause says so.

---

**Next:** Lesson 2 — filtering and ordering in depth, the strange and important behaviour of `NULL`, and the first real integrity constraints.
