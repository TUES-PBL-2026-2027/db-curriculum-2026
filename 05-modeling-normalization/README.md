# Lesson 05 — Functional Dependencies & Normalization

**Module 2 · Relational modeling and schema design**

## Objectives

- State a functional dependency and spot one (transitive, partial) in a design.
- Name the three anomalies (update, insertion, deletion) that redundancy causes.
- Normalize a flat table through 1NF → 2NF → 3NF, and recognise BCNF.
- Justify a *deliberate* denormalization using the same-fact / different-fact test (historical `price_paid_eur`).

## Start here

1. Read **`THEORY.md`**.
2. Load the Stage-5 database: `psql -d storefront -f 05-modeling-normalization/setup.sql`.
3. Work through **`PRACTICE.md`** — several tasks are analysis on paper; write before you check. Reset with `setup.sql` after the price-change experiment (Part C).
4. **Verify as you go:** run each query and compare the real output with your prediction; when they differ, work out why (re-read `THEORY.md`). Worked solutions are kept by your teacher.

## Files

| File | For |
|---|---|
| `THEORY.md` | Reading |
| `PRACTICE.md` | Hands-on + on-paper tasks |
| `setup.sql` | Stage-5 storefront DB: `purchases` + `purchase_items` (frozen `price_paid_eur`), and a deliberately-bad view for demonstrating anomalies |

## Prerequisites

Lessons 01–04 (constraints, NULL, entities/relationships, junction tables, keys, referential actions, `numeric` money).
