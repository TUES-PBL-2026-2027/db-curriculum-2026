# Running PostgreSQL locally with Docker

A containerized **PostgreSQL 18** for working through the lessons, with data that
**persists across restarts**.

## One-time setup

```bash
cp .env.example .env          # credentials & port; edit if 5432 is taken
docker compose up -d --build  # build the image and start the container
```

The container is named `db-curriculum` and creates an **empty** database called
`storefront` (user `postgres`, password `postgres` by default). Lessons are loaded
one snapshot at a time, by hand (see below).

## Persistence — what survives, what doesn't

Data lives in the Docker named volume **`storefront_pgdata`**, not inside the
container itself.

| Command | Your data |
|---|---|
| `docker compose stop` / `start` | **kept** |
| `docker compose restart` | **kept** |
| `docker compose down` | **kept** (container removed, volume stays) |
| `docker compose up -d` (again) | **kept** (reattaches the volume) |
| `docker compose down -v` | **ERASED** (the `-v` deletes the volume) |

So you can freely stop and restart; only `down -v` (or deleting the volume) wipes it.

## Everyday use

Open a `psql` shell inside the container:

```bash
docker compose exec db psql -U postgres -d storefront
```

Load a lesson's snapshot (the repo is mounted read-only at `/curriculum`):

```bash
docker compose exec db psql -U postgres -d storefront \
  -f /curriculum/01-foundations-relational-model/setup.sql
```

Or connect from your host's own `psql` / GUI client:

```bash
psql -h localhost -p 5432 -U postgres -d storefront
```

Reset a lesson to its clean state any time by re-running its `setup.sql` — every
script is idempotent (it drops and recreates its tables).

## Troubleshooting

- **Port already in use** → set `POSTGRES_PORT=5433` (or similar) in `.env`, then
  `docker compose up -d`. Connect with `-p 5433`.
- **Start fresh from scratch** → `docker compose down -v && docker compose up -d --build`.
- **Check health / logs** → `docker compose ps`, `docker compose logs -f db`.
