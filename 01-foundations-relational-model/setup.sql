-- =============================================================================
-- Module 1 · Lesson 1 — Why Databases & the Relational Model
-- Storefront database snapshot (STAGE 1: the very first schema)
-- =============================================================================
--
-- This is the first snapshot of the game-storefront database that we will grow
-- throughout the whole course. It is deliberately TINY: three tables, a handful
-- of columns, and only the constraints we have introduced so far.
--
-- The script is IDEMPOTENT: running it again drops and recreates everything,
-- so you can always reset to a known starting point.
--
--   psql -d storefront -f setup.sql
--
-- Re-running is safe and expected.
-- =============================================================================

-- Drop in reverse dependency order so re-runs are clean.
DROP TABLE IF EXISTS games;
DROP TABLE IF EXISTS developers;
DROP TABLE IF EXISTS users;

-- -----------------------------------------------------------------------------
-- developers: the studios that make games.
-- -----------------------------------------------------------------------------
CREATE TABLE developers (
    developer_id integer PRIMARY KEY,     -- we assign ids by hand for now
    name         text    NOT NULL,
    country      text,                     -- may be unknown -> allowed to be NULL
    founded_year integer
);

-- -----------------------------------------------------------------------------
-- games: titles sold on the storefront.
-- 'price' is in whole cents to avoid floating-point money bugs (see THEORY.md).
-- -----------------------------------------------------------------------------
CREATE TABLE games (
    game_id      integer PRIMARY KEY,
    title        text    NOT NULL,
    developer_id integer,                  -- which studio made it (links to developers)
    price_cents  integer NOT NULL,         -- current store price, in cents
    released_on  date,                     -- release date; NULL = unreleased/unknown
    is_published boolean NOT NULL DEFAULT true
);

-- -----------------------------------------------------------------------------
-- users: storefront accounts.
-- -----------------------------------------------------------------------------
CREATE TABLE users (
    user_id      integer PRIMARY KEY,
    username     text    NOT NULL,
    email        text,                      -- optional at this stage
    created_at   timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- Seed data — small enough to reason about entirely by hand.
-- =============================================================================

INSERT INTO developers (developer_id, name, country, founded_year) VALUES
    (1, 'Valve',             'USA',    1996),
    (2, 'CD Projekt Red',    'Poland', 1994),
    (3, 'Supergiant Games',  'USA',    2009),
    (4, 'Mojang Studios',    'Sweden', 2009),
    (5, 'Indie Newcomer',    NULL,     NULL);   -- country & founding year unknown

INSERT INTO games (game_id, title, developer_id, price_cents, released_on, is_published) VALUES
    (1, 'Half-Life 2',        1, 999,   DATE '2004-11-16', true),
    (2, 'Portal 2',           1, 1999,  DATE '2011-04-19', true),
    (3, 'Cyberpunk 2077',     2, 5999,  DATE '2020-12-10', true),
    (4, 'The Witcher 3',      2, 3999,  DATE '2015-05-19', true),
    (5, 'Hades',              3, 2499,  DATE '2020-09-17', true),
    (6, 'Minecraft',          4, 2699,  DATE '2011-11-18', true),
    (7, 'Untitled Project',   5, 0,     NULL,              false),  -- unreleased, free, no date
    (8, 'Hades II',           3, 2999,  NULL,              true);   -- announced, no release date yet

INSERT INTO users (user_id, username, email) VALUES
    (1, 'ivan',    'ivan@example.bg'),
    (2, 'maria',   'maria@example.bg'),
    (3, 'georgi',  NULL),                   -- user never provided an email
    (4, 'elena',   'elena@example.bg');

-- =============================================================================
-- Quick sanity check (uncomment to run after loading):
--   SELECT title, price_cents, released_on FROM games ORDER BY price_cents;
-- =============================================================================
