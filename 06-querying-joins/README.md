# Lesson 06 — Joins and Join Cardinality

**Module 3 · Querying relational data**

## Objectives

- Combine related tables with `INNER`, `LEFT`/`RIGHT`/`FULL OUTER`, and `CROSS` joins.
- Read a join's cardinality and predict its row count from the 1-vs-N relationship.
- Recognise, diagnose, and fix **join inflation** (row multiplication).
- Find rows with no match using an **anti-join** (`LEFT JOIN … IS NULL`, `NOT EXISTS`).

## Start here

1. Read **`THEORY.md`**.
2. Load the Stage-6 database: `psql -d storefront -f 06-querying-joins/setup.sql`.
3. Work through **`PRACTICE.md`** — predict every row count before you run.
4. **Verify as you go:** run each query and compare the real output with your prediction; when they differ, work out why (re-read `THEORY.md`). Worked solutions are kept by your teacher.

## Files

| File | For |
|---|---|
| `THEORY.md` | Reading |
| `PRACTICE.md` | Hands-on tasks (predict row counts) |
| `setup.sql` | Stage-6 storefront DB: adds `achievements` + `user_achievements` and a richer review seed for joins, inflation, and anti-joins |

## Prerequisites

Lessons 01–05 (SELECT/WHERE/ORDER BY, NULL & three-valued logic, foreign keys, junction tables, the normalized schema). This is the first lesson of **Module 3 — Querying**.
