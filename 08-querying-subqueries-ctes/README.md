# Lesson 08 — Subqueries, `EXISTS`, Set Operations, CTEs

**Module 3 · Querying relational data**

## Objectives

- Use a subquery as a **value** (scalar), a **set** (`IN`, `EXISTS`), or a **table** (derived table in `FROM`).
- Recognise and avoid the **`NOT IN` + `NULL` trap**; prefer `NOT EXISTS` for "find what's missing".
- Fix an inflated `SUM` structurally by **pre-aggregating in a derived table / CTE** (lesson 07 payoff).
- Combine result sets with `UNION`/`UNION ALL`/`INTERSECT`/`EXCEPT`.
- Make complex queries readable with **CTEs (`WITH`)**; preview `WITH RECURSIVE`.

## Start here

1. Read **`THEORY.md`**.
2. Load the Stage-8 database: `psql -d storefront -f 08-querying-subqueries-ctes/setup.sql` (same data as Stage 7).
3. Work through **`PRACTICE.md`** — predict every result before you run, especially Part B.
4. **Verify as you go:** run each query and compare the real output with your prediction; when they differ, work out why (re-read `THEORY.md`). Worked solutions are kept by your teacher.

## Files

| File | For |
|---|---|
| `THEORY.md` | Reading |
| `PRACTICE.md` | Hands-on tasks (predict results; Part B is the trap) |
| `setup.sql` | Stage-8 storefront DB: **same schema and data as Stage 7** — this lesson is about expressing queries, not growing the database |

## Prerequisites

Lessons 01–07, especially: `NULL` and three-valued logic (02) — the `NOT IN` trap is its sharpest payoff; joins and the anti-join (06); and the inflated `SUM` (07), fixed here by pre-aggregation.
