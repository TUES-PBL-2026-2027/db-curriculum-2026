-- =============================================================================
-- Lesson 03 · Modeling — Entities, Relationships & Cardinality
-- Storefront database snapshot (STAGE 3)
-- =============================================================================
--
-- Builds on Stage 2 (lesson 02). What changed vs. the previous lesson:
--   * games.developer_id is now a REAL FOREIGN KEY referencing developers.
--     In lessons 01-02 it was a "bare integer" that nothing stopped from
--     pointing at a non-existent developer. That gap is now closed.
--   * NEW many-to-many relationship: games <-> genres, via the junction
--     table game_genres. A game can have several genres; a genre has many games.
--
-- This lesson is about RELATIONSHIPS and CARDINALITY (1:1, 1:N, M:N). The
-- deeper treatment of key *types* and referential *actions* comes in lesson 04;
-- here we just establish that relationships are enforced, not merely implied.
--
-- Idempotent. Load with:  storefront -f 03-modeling-entities-relationships/setup.sql
-- =============================================================================

DROP TABLE IF EXISTS game_genres;
DROP TABLE IF EXISTS genres;
DROP TABLE IF EXISTS games;
DROP TABLE IF EXISTS developers;
DROP TABLE IF EXISTS users;

-- -----------------------------------------------------------------------------
-- developers  (unchanged from stage 2)
-- -----------------------------------------------------------------------------
CREATE TABLE developers (
    developer_id integer PRIMARY KEY,
    name         text    NOT NULL UNIQUE,
    country      text,
    founded_year integer CHECK (founded_year BETWEEN 1950 AND 2100)
);

-- -----------------------------------------------------------------------------
-- games
--   developer_id is now a FOREIGN KEY: every non-NULL value must match an
--   existing developers.developer_id. A game may still have NULL developer
--   (unknown studio), but it can NEVER reference a developer that doesn't exist.
-- -----------------------------------------------------------------------------
CREATE TABLE games (
    game_id      integer PRIMARY KEY,
    title        text    NOT NULL,
    developer_id integer REFERENCES developers (developer_id),  -- <== the relationship, enforced
    price_cents  integer NOT NULL CHECK (price_cents >= 0),
    released_on  date,
    is_published boolean NOT NULL DEFAULT true
);

-- -----------------------------------------------------------------------------
-- genres  (new entity)
-- -----------------------------------------------------------------------------
CREATE TABLE genres (
    genre_id integer PRIMARY KEY,
    name     text    NOT NULL UNIQUE
);

-- -----------------------------------------------------------------------------
-- game_genres  (junction / associative table for the M:N relationship)
--   One row = "this game is in this genre". The pair must be unique, so the
--   PRIMARY KEY is the COMBINATION of the two columns (a composite key).
--   Each column is itself a foreign key into its parent table.
-- -----------------------------------------------------------------------------
CREATE TABLE game_genres (
    game_id  integer NOT NULL REFERENCES games (game_id),
    genre_id integer NOT NULL REFERENCES genres (genre_id),
    PRIMARY KEY (game_id, genre_id)
);

-- -----------------------------------------------------------------------------
-- users  (unchanged from stage 2)
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
    (8, 'Hades II',         3, 2999,  NULL,              true);

INSERT INTO genres (genre_id, name) VALUES
    (1, 'Action'),
    (2, 'Adventure'),
    (3, 'RPG'),
    (4, 'Puzzle'),
    (5, 'Roguelike'),
    (6, 'Sandbox'),
    (7, 'Shooter');

-- A game can belong to several genres (M:N). Note some games share genres.
INSERT INTO game_genres (game_id, genre_id) VALUES
    (1, 1), (1, 7),            -- Half-Life 2: Action, Shooter
    (2, 4), (2, 1),            -- Portal 2: Puzzle, Action
    (3, 3), (3, 1), (3, 2),    -- Cyberpunk 2077: RPG, Action, Adventure
    (4, 3), (4, 2),            -- The Witcher 3: RPG, Adventure
    (5, 5), (5, 1),            -- Hades: Roguelike, Action
    (6, 6), (6, 2),            -- Minecraft: Sandbox, Adventure
    (8, 5), (8, 1);            -- Hades II: Roguelike, Action
    -- game 7 (Untitled Project) deliberately has NO genres yet.

INSERT INTO users (user_id, username, email) VALUES
    (1, 'ivan',    'ivan@example.bg'),
    (2, 'maria',   'maria@example.bg'),
    (3, 'georgi',  NULL),
    (4, 'elena',   'elena@example.bg'),
    (5, 'petar',   NULL),
    (6, 'dimitar', NULL);

-- =============================================================================
-- Try these AFTER loading to see relationships enforced (each should FAIL):
--
--   INSERT INTO games (game_id, title, developer_id, price_cents)
--     VALUES (99, 'Ghost', 999, 100);        -- developer 999 does not exist (FK)
--
--   INSERT INTO game_genres (game_id, genre_id) VALUES (1, 1);  -- duplicate pair (PK)
--
--   INSERT INTO game_genres (game_id, genre_id) VALUES (1, 999); -- genre 999 missing (FK)
-- =============================================================================
