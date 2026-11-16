# Lesson 03 — Entities, Relationships & Cardinality

**Module 2 · Relational modeling and schema design**

## Objectives

- Identify entities and the relationships between them; classify cardinality (1:1, 1:N, M:N).
- Implement a one-to-many relationship with a foreign key (on the correct side).
- Implement a many-to-many relationship with a junction table (composite PK + two FKs).
- Explain referential integrity: references are always valid, and the DB protects both ends.

## Start here

1. Read **`THEORY.md`**.
2. Load the Stage-3 database: `psql -d storefront -f 03-modeling-entities-relationships/setup.sql`.
3. Work through **`PRACTICE.md`** — predict the FK/junction outcomes before running.
4. **Verify as you go:** run each query and compare the real output with your prediction; when they differ, work out why (re-read `THEORY.md`). Worked solutions are kept by your teacher.

## Files

| File | For |
|---|---|
| `THEORY.md` | Reading |
| `PRACTICE.md` | Hands-on tasks |
| `setup.sql` | Stage-3 storefront DB: FKs + `genres`/`game_genres` M:N |

## Prerequisites

Lessons 01–02 (relational model, types, constraints, NULL / three-valued logic).
