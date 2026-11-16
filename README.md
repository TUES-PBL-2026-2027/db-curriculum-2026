# Databases with PostgreSQL — TUES, Grade 11

Welcome! This repository holds everything you need for our one-year course in **relational databases**, taught on **PostgreSQL**. By the end of the year you will be able to **design, build, explain, verify, and troubleshoot** a real database-backed application — not just write queries that happen to work, but understand *why* they work.

> **How you'll be assessed.** We grade *demonstrated competence*, not just a query that returns the right answer. For any task you should be able to:
> **predict** what will happen, **explain** your choices, **diagnose** what went wrong, **adapt** a solution to a new requirement, and **verify** your claims by running them.

---

## The big idea: one database, all year

Instead of a new throwaway example every week, the whole course grows **one application** — a Steam-like **game storefront and library**. Users own games, write reviews, and earn achievements; games have genres, developers, and prices that change during sales.

Each lesson adds to this *same* database. You will watch a realistic schema **grow, break, and get repaired** across the year. Every lesson ships a `setup.sql` file that rebuilds the database exactly as it stands at that point in the story — so you can always get to a known, clean state.

---

## What's in a lesson

There is **one folder per lesson**, numbered in the order we teach them. Each folder contains three files:

| File | What it is |
|------|------------|
| **`README.md`** | A one-screen overview: the lesson's goals and where to start. **Read this first.** |
| **`THEORY.md`** | The reference reading — concepts, worked examples, diagrams, and common pitfalls. This is your textbook for the lesson. |
| **`PRACTICE.md`** | Hands-on tasks. Each follows **Predict → Run → Explain** (see below). |
| **`setup.sql`** | A re-runnable snapshot of the storefront database at this lesson's stage. Loading it resets you to a clean start. |

*(Worked solutions to the practice tasks are kept by your teacher. The point of each task is for **you** to predict and then check against the real database — that's where the learning happens.)*

---

## Getting set up

You need a running **PostgreSQL 16+** and the `psql` command-line client. Pick **one** of the two options below.

### Option A — Docker (recommended, same for everyone)

If you have Docker Desktop installed, this gives everyone an identical PostgreSQL 18 with no local install. From the repository folder:

```bash
cp .env.example .env          # one time: copies default settings
docker compose up -d --build  # builds and starts PostgreSQL in the background
```

This creates an empty database called `storefront` (user `postgres`, password `postgres`). Your data **persists** across restarts — stopping and starting the container keeps everything. See **[`docker/README.md`](docker/README.md)** for the full workflow (and how to wipe it if you ever want a totally fresh start).

Open a database shell:

```bash
docker compose exec db psql -U postgres -d storefront
```

### Option B — a local PostgreSQL install

If PostgreSQL is installed directly on your machine, create the database once:

```bash
psql --version            # check you have psql (16 or newer)
createdb storefront       # create the database (one time)
```

---

## Running a lesson's database

Every `setup.sql` is **idempotent** — running it again rebuilds that lesson's tables and data from scratch, so you can re-run it any time to reset.

**Load a lesson** (example: lesson 01). Run this from the repository folder:

```bash
psql -d storefront -f 01-foundations-relational-model/setup.sql
```

> Using Docker? The repository is mounted inside the container at `/curriculum`, so the equivalent is:
> ```bash
> docker compose exec db psql -U postgres -d storefront -f /curriculum/01-foundations-relational-model/setup.sql
> ```
> (You can also add an alias so plain `psql -d storefront ...` works from your host — ask if you'd like help.)

**Open an interactive session** to run queries by hand:

```bash
psql -d storefront
```

Handy commands once you're inside `psql`:

| Command | Does |
|---|---|
| `\dt` | list the tables |
| `\d tablename` | describe a table (columns, types, constraints) |
| `\d+ viewname` | show a view's definition |
| `\x` | toggle expanded (one-column-per-line) output — great for wide rows |
| `\q` | quit |

---

## How to work through a lesson

Follow this loop for every lesson — it's the habit the whole course is built on:

1. **Read `README.md`** in the lesson folder (goals + prerequisites).
2. **Read `THEORY.md`.** Don't skim — the worked examples are the point.
3. **Load the database:** `psql -d storefront -f <lesson-folder>/setup.sql`.
4. **Do `PRACTICE.md` using Predict → Run → Explain:**
   - **Predict** — before running a query, write down what you expect (the rows, the count, or the error).
   - **Run** — execute it against the database.
   - **Explain** — compare reality with your prediction. If they match, say *why*. If they don't, that gap is the most valuable thing in the lesson — track down the reason (re-read the relevant part of `THEORY.md`).

A confident wrong prediction teaches you more than a lucky right answer. Resist the urge to skip straight to running.

---

## The course map

Lessons are released as we reach them. **Lessons 01–09 are available now**; the rest will appear through the year.

| # | Lesson | You'll learn |
|---|--------|--------------|
| 01 | `01-foundations-relational-model` | Why databases exist; the relational model; `psql`; types; first CRUD |
| 02 | `02-foundations-querying` | Filtering & ordering; `NULL` and three-valued logic; first constraints |
| 03 | `03-modeling-entities-relationships` | Entities, relationships, and cardinality; foreign keys; junction tables |
| 04 | `04-modeling-keys-constraints` | Primary/candidate/foreign keys; `UNIQUE`/`CHECK`; referential actions |
| 05 | `05-modeling-normalization` | Functional dependencies; normalization to 3NF; when to denormalize |
| 06 | `06-querying-joins` | Inner & outer joins; join cardinality; join inflation; anti-joins |
| 07 | `07-querying-aggregation` | `COUNT`/`SUM`/`AVG`; `GROUP BY`; `HAVING`; aggregates and `NULL` |
| 08 | `08-querying-subqueries-ctes` | Subqueries; `EXISTS`; the `NOT IN` + `NULL` trap; set operations; CTEs |
| 09 | `09-querying-views-window-functions` | Views & materialized views; window functions; ranking within groups |
| 10–23 | *(coming later)* | Transactions & concurrency, databases in applications, internals & performance, database-side programming, operations, and a final integration project |

---

## Troubleshooting

- **`psql: command not found`** → PostgreSQL's client isn't installed or isn't on your `PATH`. Use the Docker option, or install PostgreSQL 16+.
- **`database "storefront" does not exist`** → run `createdb storefront` (local), or start the Docker container which creates it automatically.
- **`could not connect to server` / port 5432 in use** → another PostgreSQL may be running. With Docker, change `POSTGRES_PORT` in `.env` (e.g. to `5433`) and reconnect with `-p 5433`. See [`docker/README.md`](docker/README.md).
- **A query errors or returns something surprising** → that's often intentional in the practice tasks! Read the error carefully; it's usually telling you exactly what rule you hit.

---

*Course materials for TUES (Technological School Electronic Systems, elsys-bg.org).*
