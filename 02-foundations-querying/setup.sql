-- =============================================================================
-- Module 1 · Lesson 2 — Querying & Integrity Basics
-- Storefront database snapshot (STAGE 2)
-- =============================================================================
--
-- Same three tables as Lesson 1, but now with the INTEGRITY CONSTRAINTS this
-- lesson introduces:
--   * NOT NULL where a value is genuinely required
--   * UNIQUE to forbid duplicates (usernames, emails, developer names)
--   * CHECK to forbid nonsensical values (negative prices, impossible years)
--   * explicit column DEFAULTs
--
-- The seed data is a little richer so that NULL behaviour and filtering have
-- something interesting to show (e.g. several users without an email, prices
-- spanning the sale boundary).
--
-- Idempotent: re-running drops and recreates everything.
--   psql -d storefront -f setup.sql
-- =============================================================================

DROP TABLE IF EXISTS games;
DROP TABLE IF EXISTS developers;
DROP TABLE IF EXISTS users;

-- -----------------------------------------------------------------------------
-- developers
-- -----------------------------------------------------------------------------
CREATE TABLE developers (
    developer_id integer PRIMARY KEY,
    name         text    NOT NULL UNIQUE,                 -- no two studios share a name
    country      text,                                     -- may be unknown
    founded_year integer CHECK (founded_year BETWEEN 1950 AND 2100)
);

-- -----------------------------------------------------------------------------
-- games
-- -----------------------------------------------------------------------------
CREATE TABLE games (
    game_id      integer PRIMARY KEY,
    title        text    NOT NULL,
    developer_id integer,
    price_cents  integer NOT NULL CHECK (price_cents >= 0),  -- free is ok; negative is not
    released_on  date,
    is_published boolean NOT NULL DEFAULT true
);

-- -----------------------------------------------------------------------------
-- users
--   username is required and unique.
--   email is OPTIONAL (may be NULL) but, when present, must be unique.
--   PostgreSQL UNIQUE treats NULLs as distinct, so many users may have no email.
-- -----------------------------------------------------------------------------
CREATE TABLE users (
    user_id    integer     PRIMARY KEY,
    username   text        NOT NULL UNIQUE,
    email      text        UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- Seed data
-- =============================================================================

INSERT INTO developers (developer_id, name, country, founded_year) VALUES
    (1, 'Valve',            'USA',    1996),
    (2, 'CD Projekt Red',   'Poland', 1994),
    (3, 'Supergiant Games', 'USA',    2009),
    (4, 'Mojang Studios',   'Sweden', 2009),
    (5, 'Indie Newcomer',   NULL,     NULL);

INSERT INTO games (game_id, title, developer_id, price_cents, released_on, is_published) VALUES
    (1, 'Half-Life 2',      1, 999,   DATE '2004-11-16', true),
    (2, 'Portal 2',         1, 1999,  DATE '2011-04-19', true),
    (3, 'Cyberpunk 2077',   2, 5999,  DATE '2020-12-10', true),
    (4, 'The Witcher 3',    2, 3999,  DATE '2015-05-19', true),
    (5, 'Hades',            3, 2499,  DATE '2020-09-17', true),
    (6, 'Minecraft',        4, 2699,  DATE '2011-11-18', true),
    (7, 'Untitled Project', 5, 0,     NULL,              false),
    (8, 'Hades II',         3, 2999,  NULL,              true),
    (9, 'Free Weekend Demo',1, 0,     DATE '2023-03-01', true);

INSERT INTO users (user_id, username, email) VALUES
    (1, 'ivan',   'ivan@example.bg'),
    (2, 'maria',  'maria@example.bg'),
    (3, 'georgi', NULL),              -- no email
    (4, 'elena',  'elena@example.bg'),
    (5, 'petar',  NULL),              -- no email -> allowed, because NULLs are distinct for UNIQUE
    (6, 'dimitar',NULL);              -- another user with no email

-- =============================================================================
-- Try these AFTER loading to see the constraints bite (each should FAIL):
--
--   INSERT INTO games (game_id, title, price_cents) VALUES (99, 'Bad', -500);
--      -- violates CHECK (price_cents >= 0)
--
--   INSERT INTO users (user_id, username) VALUES (99, 'ivan');
--      -- violates UNIQUE on username
--
--   INSERT INTO games (game_id, title, price_cents) VALUES (1, 'Dup', 100);
--      -- violates PRIMARY KEY (game_id already exists)
-- =============================================================================
