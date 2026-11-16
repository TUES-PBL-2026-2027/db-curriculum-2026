# Lesson 07 — Aggregation, `GROUP BY`, `HAVING`

**Module 3 · Querying relational data**

## Objectives

- Summarise many rows into one value with `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`.
- Build per-group reports with `GROUP BY`; obey the rule that every selected column is grouped or aggregated.
- Filter **groups** with `HAVING` and know why that differs from filtering **rows** with `WHERE`.
- Predict how aggregates treat `NULL` (`avg` of nothing is `NULL`, not `0`; `count(*)` vs `count(col)`).
- **Diagnose and fix an inflated `SUM` caused by a join** — the named Module 3 competence.

## Start here

1. Read **`THEORY.md`**.
2. Load the Stage-7 database: `psql -d storefront -f 07-querying-aggregation/setup.sql`.
3. Work through **`PRACTICE.md`** — predict every value before you run.
4. **Verify as you go:** run each query and compare the real output with your prediction; when they differ, work out why (re-read `THEORY.md`). Worked solutions are kept by your teacher.

## Files

| File | For |
|---|---|
| `THEORY.md` | Reading |
| `PRACTICE.md` | Hands-on tasks (predict the summary values) |
| `setup.sql` | Stage-7 storefront DB: same schema as Stage 6, with a fuller purchase history (7 purchases, 10 line items) so revenue aggregation has real spread |

## Prerequisites

Lessons 01–06, especially: `NULL` and three-valued logic (02), functional dependencies (05), and joins — cardinality, `LEFT JOIN` coverage, and **join inflation** (06). This lesson turns that inflation into a wrong `SUM` and teaches you to catch it.
