# Lesson 1 — Practice

**Module 1 · Why Databases & the Relational Model**

> **How to work.** Every task uses **Predict → Run → Explain**:
> 1. **Predict** — write down (on paper or in a comment) what you expect *before* running anything.
> 2. **Run** — execute the SQL.
> 3. **Explain** — if the result differs from your prediction, work out *why*. The gap is where the learning is.
>
> Always attempt a task — prediction included — before you run it. The effort of predicting is what makes the answer stick; a lucky guess teaches nothing.

## Setup

```bash
createdb storefront        # once
psql -d storefront -f setup.sql
psql -d storefront         # interactive session
```

Re-run the `psql -f setup.sql` line any time you want a clean reset.

---

## Part A — Orientation

**A1.** List the tables in your database, then describe the `games` table.
*(Hint: these are `psql` meta-commands, not SQL.)*

**A2.** Before running it — **predict** how many rows `SELECT * FROM games;` returns, and in what order. Then run it. Was the order what you expected? Why can you not be certain?

---

## Part B — Reading data (SELECT)

**B1.** Select only the `title` and `price_cents` of every game.

**B2.** **Predict**, then run: show every game that costs **less than €20** (remember prices are in cents), cheapest first.

**B3.** Show all games made by developer `1` (Valve). Then show all games released **in or after 2020**. (You will need the `released_on` column.)

**B4.** Show games ordered by `released_on`, newest first. **Predict** where the two games with no release date (`Untitled Project`, `Hades II`) will appear — top, bottom, or somewhere else? Run it and see.

---

## Part C — Choosing types & writing data (CRUD)

**C1.** Insert a new developer of your choice (pick an unused `developer_id`), then insert one new game made by them. Verify both with `SELECT`.

**C2.** The store is putting *Cyberpunk 2077* on sale for €14.99. Write the `UPDATE` that sets its `price_cents` correctly. Verify.

**C3.** **Predict first:** what would `UPDATE games SET price_cents = 0;` (no `WHERE`) do? Do **not** run it. Then write the *correct*, targeted version that only makes `Untitled Project` free. Verify that the other prices are unchanged.

**C4.** Delete the game you created in C1. Confirm it is gone.

---

## Part D — The point of a database (file vs. DBMS)

**D1.** You are asked: *"Give me the three cheapest published games, with their prices."* Write a single query that answers this. Now describe, in two or three sentences, what you would have had to write **by hand** to answer the same question from a plain `games.txt` file.

**D2.** (Thinking task — no SQL required.) Your teammate suggests storing prices as `price numeric` holding euros like `9.99`, or even as a floating-point number. Give **one concrete reason** integer cents (or `numeric`) is safer than floating point for money.

---

## Stretch (optional)

**S1.** Find all games whose title contains the word "Hades". *(Hint: look up the `LIKE` operator.)*

**S2.** `released_on` is a `date`. Write a query returning each released game's title and **how many days ago** it came out. *(Hint: you can subtract a `date` from `CURRENT_DATE`.)*
