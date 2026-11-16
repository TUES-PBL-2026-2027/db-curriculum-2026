# Lesson 2 — Querying & Integrity Basics

**Module 1 · Database foundations and basic SQL**

## Objectives

- Filter with precise boolean conditions (operators, precedence) and order deterministically (`ORDER BY`, `LIMIT`, NULL ordering).
- Reason correctly about `NULL` via three-valued logic; test nulls with `IS NULL` / `IS NOT NULL`.
- Define the first integrity constraints: `NOT NULL`, `PRIMARY KEY`, `UNIQUE`, `CHECK`, `DEFAULT`.
- Modify only the intended rows, safely.

## Start here

1. Read **`THEORY.md`** (§3 on `NULL` is the crux).
2. Reset the database: `psql -d storefront -f setup.sql`.
3. Work through **`PRACTICE.md`** — predict the NULL/constraint results before running.
4. **Verify as you go:** run each query and compare the real output with your prediction; when they differ, work out why (re-read `THEORY.md`). Worked solutions are kept by your teacher.

## Files

| File | For |
|---|---|
| `THEORY.md` | Reading |
| `PRACTICE.md` | Hands-on tasks |
| `setup.sql` | Stage-2 storefront database (constraints added) |
