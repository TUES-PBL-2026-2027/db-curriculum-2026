# Lesson 03 — Entities, Relationships & Cardinality

**Module 2 · Relational modeling and schema design**

> **By the end of this lesson you should be able to:** identify the *entities* in a domain and the *relationships* between them; classify a relationship's **cardinality** (1:1, 1:N, M:N); implement a one-to-many relationship with a **foreign key** and a many-to-many relationship with a **junction table**; and explain why a foreign key makes a relationship *enforced* rather than merely *hoped for*.

---

## 1. From single tables to a connected schema

In Module 1 we treated tables in isolation. But the end of lesson 02 flagged a gap:

> *"Right now a game points to a developer only by a bare `developer_id` integer — nothing stops a game referencing developer 999 who doesn't exist."*

That is the problem this module solves. Real data is a **web of related entities**: a game is *made by* a developer, *belongs to* genres, *is reviewed by* users. Modeling is the craft of representing those relationships so the database **enforces** them.

An **entity** is a thing we store data about — `developers`, `games`, `genres`, `users`. A **relationship** connects entities — "a game is made by a developer." The central question for every relationship is its **cardinality**: *how many* of one side relate to *how many* of the other.

---

## 2. The three cardinalities

```
   One-to-one (1:1)        One-to-many (1:N)         Many-to-many (M:N)
   ┌──────┐  ┌──────┐      ┌──────┐  ┌──────┐        ┌──────┐  ┌──────┐
   │ user │──│profile│      │ dev  │─<│ game │        │ game │>─<│genre │
   └──────┘  └──────┘      └──────┘  └──────┘        └──────┘  └──────┘
   each user has at most    one developer makes       a game has many genres
   one profile, & vice      many games; each game     AND a genre has many
   versa                    has one developer         games
```

| Cardinality | Example in the storefront | How it is implemented |
|---|---|---|
| **1:N** | A developer makes many games; each game has one developer. | A **foreign key** on the "many" side (`games.developer_id`). |
| **M:N** | A game has many genres; a genre has many games. | A **junction table** (`game_genres`) with a foreign key to each side. |
| **1:1** | A user has one settings row (not yet in our schema). | A foreign key on one side, made `UNIQUE`. |

The guiding rule:

> **The foreign key always lives on the "many" side.** A game points to its one developer; a developer does *not* list its many games in a column.

---

## 3. One-to-many with a foreign key

A **foreign key (FK)** is a column whose values must match an existing value in another table's key column (usually its primary key). It is the database-enforced version of "this game's developer must be a real developer."

```sql
CREATE TABLE games (
    game_id      integer PRIMARY KEY,
    title        text    NOT NULL,
    developer_id integer REFERENCES developers (developer_id),  -- the foreign key
    ...
);
```

Now the earlier gap is closed. Watch it bite:

```sql
INSERT INTO games (game_id, title, developer_id, price_cents)
VALUES (99, 'Ghost', 999, 100);
-- ERROR: insert or update on table "games" violates foreign key constraint
--        Key (developer_id)=(999) is not present in table "developers".
```

The database **refuses** to create a game pointing at a non-existent developer. This property is called **referential integrity**: references between tables are always valid.

> **NULL is still allowed.** `developer_id` has no `NOT NULL`, so a game with an *unknown* studio (`developer_id = NULL`) is fine — a foreign key only constrains **non-NULL** values. This is three-valued logic again (lesson 02): an unknown reference is permitted; a *wrong* one is not. If every game must have a developer, add `NOT NULL`.

### The two directions of a 1:N relationship

```sql
-- "many → one": each game and its developer's name
SELECT g.title, d.name
FROM games g
JOIN developers d ON d.developer_id = g.developer_id;

-- "one → many": all games by a given developer
SELECT title FROM games WHERE developer_id = 3;   -- Supergiant's games
```

We write joins properly in Module 3; for now notice the FK is what makes the connection *reliable*.

---

## 4. Many-to-many with a junction table

A game has many genres; a genre has many games. **Neither side can hold a foreign key to the other** — you can't put "many genre ids" in a single column (that would violate first normal form, which we meet in lesson 05). The relational answer is a third table whose rows *are* the relationship:

```sql
CREATE TABLE game_genres (
    game_id  integer NOT NULL REFERENCES games (game_id),
    genre_id integer NOT NULL REFERENCES genres (genre_id),
    PRIMARY KEY (game_id, genre_id)      -- a COMPOSITE primary key
);
```

Each row says *"this game is in this genre."* Three design points worth dwelling on:

1. **Two foreign keys.** `game_id` references `games`; `genre_id` references `genres`. The junction can only pair things that actually exist.
2. **A composite primary key** `(game_id, genre_id)`. This makes each pairing **unique** — you cannot say "Hades is Roguelike" twice — and it is the natural identifier of a relationship row. (We dissect composite vs. surrogate keys in lesson 04.)
3. **The junction can carry its own attributes.** If we later wanted "when was this genre tag added?" we'd add an `added_at` column to `game_genres`. The relationship itself can have data.

```
         game_genres
   game_id │ genre_id
   ────────┼─────────
      1    │   1       Half-Life 2 ─ Action
      1    │   7       Half-Life 2 ─ Shooter
      3    │   3       Cyberpunk  ─ RPG
      3    │   1       Cyberpunk  ─ Action
      3    │   2       Cyberpunk  ─ Adventure
```

See the junction enforce both sides:

```sql
INSERT INTO game_genres (game_id, genre_id) VALUES (1, 1);     -- ERROR: duplicate pair (PK)
INSERT INTO game_genres (game_id, genre_id) VALUES (1, 999);   -- ERROR: genre 999 missing (FK)
```

> **A game with no genres is still valid.** `Untitled Project` (game 7) simply has no rows in `game_genres`. "Zero related rows" is a normal state in a 1:N or M:N relationship — don't confuse *optional participation* with a broken schema.

---

## 5. Reading an entity–relationship sketch

Before writing `CREATE TABLE`, model on paper. A lightweight **entity–relationship (ER)** sketch for our current schema:

```
  developers ──1────<── games ──>────M:N────<── genres
                          │
                          │ (reviews, purchases, achievements
                          │  arrive in later lessons)
  users ─────────────────┘
```

- A **box** is an entity (becomes a table).
- A **line** is a relationship; the crow's-foot/`<` end marks the "many" side.
- Each **M:N line resolves into a junction table** when you implement it.

Modeling discipline: name entities as **singular concepts**, give every entity a primary key, put each fact in exactly one place, and decide the cardinality of every relationship *before* choosing where the foreign key goes.

---

## Key terms

- **Entity / relationship** — a thing we store; a connection between things.
- **Cardinality** — 1:1, 1:N, M:N: how many relate to how many.
- **Foreign key (FK)** — a column whose non-NULL values must exist in another table's key; gives **referential integrity**.
- **Junction (associative) table** — resolves an M:N relationship into two 1:N relationships; often has a **composite primary key**.
- **Optional participation** — zero related rows is a legal state.

## Common misconceptions this lesson targets

1. *"A foreign key stores the related row."* — No; it stores a *reference* (the key value); the data stays in one place.
2. *"M:N just needs a column with a list of ids."* — No; use a junction table. One value per cell.
3. *"A foreign key forbids NULL."* — No; it only constrains non-NULL values. Add `NOT NULL` if the relationship is mandatory.
4. *"The FK could go on either side of a 1:N."* — No; it goes on the **many** side.
5. *"Every game must have at least one genre/review."* — Not unless a constraint says so; zero related rows is normal.

---

**Next:** Lesson 04 — the different *kinds* of keys (candidate, primary, surrogate vs. natural, composite), deeper constraints, **referential actions** (what happens to games when a developer is deleted), and the proper treatment of types for money (`numeric`) and codes (`text` vs. `char(2)`).
