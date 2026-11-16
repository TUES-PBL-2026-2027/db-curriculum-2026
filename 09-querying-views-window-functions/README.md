# Lesson 09 — Views and Window Functions

**Module 3 · Querying relational data**

## Objectives

- Save a query as a reusable **view** and query it like a table; know when a view is read-only.
- Distinguish a virtual view (always current) from a **materialized view** (stored, stale until `REFRESH`).
- Use **window functions** (`func(...) OVER (...)`) to compute a value per row *without collapsing* rows — the thing `GROUP BY` cannot do.
- **Rank within groups** with `row_number` / `rank` / `dense_rank` — the named Module 3 competence.
- Compute running totals (`SUM OVER (ORDER BY)`) and read neighbouring rows (`LAG`/`LEAD`).

## Start here

1. Read **`THEORY.md`**.
2. Load the Stage-9 database: `psql -d storefront -f 09-querying-views-window-functions/setup.sql`.
3. Work through **`PRACTICE.md`** — for every task, predict *collapse or keep* (the row count) before you run.
4. **Verify as you go:** run each query and compare the real output with your prediction; when they differ, work out why (re-read `THEORY.md`). Worked solutions are kept by your teacher.

## Files

| File | For |
|---|---|
| `THEORY.md` | Reading |
| `PRACTICE.md` | Hands-on tasks (predict row counts and ranks) |
| `setup.sql` | Stage-9 storefront DB: adds the `game_ratings` and `game_revenue` **views** and a `game_ratings_mv` **materialized view**; no new base tables |

## Prerequisites

Lessons 01–08, especially: `NULL` and three-valued logic (02) — it reappears at window edges; aggregation and the GROUP-BY-collapses-rows idea (07) — window functions are the "keep the rows" counterpart; subqueries/CTEs (08) — used to filter window results. This is the **final lesson of Module 3**; next is Module 4 (transactions).
