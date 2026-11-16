# Lesson 04 — Keys and Constraints

**Module 2 · Relational modeling and schema design**

## Objectives

- Distinguish candidate, primary, alternate, composite, and foreign keys.
- Choose between surrogate and natural keys with justification.
- Use referential actions (`CASCADE` / `SET NULL` / `RESTRICT`) to design delete behaviour.
- Model money with `numeric(p,s)` and standardized codes with `char(n)` + `CHECK`; default to `text` otherwise.

## Start here

1. Read **`THEORY.md`**.
2. Load the Stage-4 database: `psql -d storefront -f 04-modeling-keys-constraints/setup.sql`.
3. Work through **`PRACTICE.md`** — reset with `setup.sql` between the referential-action experiments.
4. **Verify as you go:** run each query and compare the real output with your prediction; when they differ, work out why (re-read `THEORY.md`). Worked solutions are kept by your teacher.

## Files

| File | For |
|---|---|
| `THEORY.md` | Reading |
| `PRACTICE.md` | Hands-on tasks |
| `setup.sql` | Stage-4 storefront DB: referential actions, `numeric` money, `char(2)` codes, `reviews` |

## Prerequisites

Lessons 01–03 (constraints, NULL, entities/relationships, foreign keys, junction tables).
