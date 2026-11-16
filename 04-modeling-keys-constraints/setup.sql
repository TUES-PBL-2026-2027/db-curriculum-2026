-- =============================================================================
-- Lesson 04 · Modeling — Keys and Constraints
-- Storefront database snapshot (STAGE 4)
-- =============================================================================
--
-- Builds on Stage 3 (lesson 03). What changed vs. the previous lesson:
--   * REFERENTIAL ACTIONS added to foreign keys (ON DELETE ...), so we control
--     what happens to children when a parent row is deleted.
--       - games.developer_id        ON DELETE SET NULL   (studio closes -> games become "unknown studio")
--       - game_genres.game_id        ON DELETE CASCADE     (delete a game -> its genre tags vanish)
--       - game_genres.genre_id       ON DELETE RESTRICT    (can't delete a genre still in use)
--   * TYPES revisited (paying off threads from Module 1):
--       - price is now numeric(8,2) in EUROS, not integer cents. We discuss the
--         trade-off vs. integer minor units; both are correct, floats are not.
--       - developers.country_code is char(2) (a standardized ISO code), while
--         the free-text developers.country stays text. The text-vs-char rule.
--   * NEW table 'reviews' demonstrating a SURROGATE primary key (review_id)
--     plus a separate UNIQUE constraint expressing a business rule.
--
-- Idempotent. Load with:  storefront -f 04-modeling-keys-constraints/setup.sql
-- =============================================================================

DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS game_genres;
DROP TABLE IF EXISTS genres;
DROP TABLE IF EXISTS games;
DROP TABLE IF EXISTS developers;
DROP TABLE IF EXISTS users;

-- -----------------------------------------------------------------------------
-- developers
--   country_code: ISO 3166-1 alpha-2 — a STANDARDIZED, fixed-width domain, so
--                 char(2) is appropriate and documents the invariant.
--   country:      the free-text display name — unpredictable length -> text.
-- -----------------------------------------------------------------------------
CREATE TABLE developers (
    developer_id integer PRIMARY KEY,
    name         text    NOT NULL UNIQUE,
    country      text,                                   -- display name: free text
    country_code char(2) CHECK (country_code ~ '^[A-Z]{2}$'),  -- ISO code: fixed width
    founded_year integer CHECK (founded_year BETWEEN 1950 AND 2100)
);

-- -----------------------------------------------------------------------------
-- games
--   price_eur: numeric(8,2) — EXACT decimal money (euros). Contrast with the
--              integer price_cents used in Module 1; both avoid float error.
--   developer_id FK now SET NULL on delete: if a studio is removed, its games
--              survive as "unknown studio" rather than blocking the delete.
-- -----------------------------------------------------------------------------
CREATE TABLE games (
    game_id      integer       PRIMARY KEY,
    title        text          NOT NULL,
    developer_id integer       REFERENCES developers (developer_id) ON DELETE SET NULL,
    price_eur    numeric(8,2)  NOT NULL CHECK (price_eur >= 0),
    released_on  date,
    is_published boolean       NOT NULL DEFAULT true
);

CREATE TABLE genres (
    genre_id integer PRIMARY KEY,
    name     text    NOT NULL UNIQUE
);

-- -----------------------------------------------------------------------------
-- game_genres
--   game_id  ON DELETE CASCADE : deleting a game removes its tag rows.
--   genre_id ON DELETE RESTRICT: a genre can't be deleted while games use it.
-- -----------------------------------------------------------------------------
CREATE TABLE game_genres (
    game_id  integer NOT NULL REFERENCES games (game_id)  ON DELETE CASCADE,
    genre_id integer NOT NULL REFERENCES genres (genre_id) ON DELETE RESTRICT,
    PRIMARY KEY (game_id, genre_id)
);

CREATE TABLE users (
    user_id    integer     PRIMARY KEY,
    username   text        NOT NULL UNIQUE,
    email      text        UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- reviews
--   SURROGATE primary key review_id (a meaningless-but-stable identifier),
--   because a user may review a game more than once over time, so the natural
--   candidate key (user_id, game_id) is NOT unique. We instead express a weaker
--   business rule with a partial-free UNIQUE here: at most one review per
--   (user, game) PER DAY — demonstrating a composite UNIQUE separate from the PK.
-- -----------------------------------------------------------------------------
CREATE TABLE reviews (
    review_id    integer     PRIMARY KEY,                 -- surrogate key
    user_id      integer     NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
    game_id      integer     NOT NULL REFERENCES games (game_id) ON DELETE CASCADE,
    rating       integer     NOT NULL CHECK (rating BETWEEN 1 AND 5),
    body         text,
    reviewed_on  date        NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE (user_id, game_id, reviewed_on)                -- candidate key, not the PK
);

-- =============================================================================
-- Seed data
-- =============================================================================

INSERT INTO developers (developer_id, name, country, country_code, founded_year) VALUES
    (1, 'Valve',            'United States', 'US', 1996),
    (2, 'CD Projekt Red',   'Poland',        'PL', 1994),
    (3, 'Supergiant Games', 'United States', 'US', 2009),
    (4, 'Mojang Studios',   'Sweden',        'SE', 2009),
    (5, 'Indie Newcomer',   NULL,            NULL, NULL);

INSERT INTO games (game_id, title, developer_id, price_eur, released_on, is_published) VALUES
    (1, 'Half-Life 2',      1,  9.99, DATE '2004-11-16', true),
    (2, 'Portal 2',         1, 19.99, DATE '2011-04-19', true),
    (3, 'Cyberpunk 2077',   2, 59.99, DATE '2020-12-10', true),
    (4, 'The Witcher 3',    2, 39.99, DATE '2015-05-19', true),
    (5, 'Hades',            3, 24.99, DATE '2020-09-17', true),
    (6, 'Minecraft',        4, 26.99, DATE '2011-11-18', true),
    (7, 'Untitled Project', 5,  0.00, NULL,              false),
    (8, 'Hades II',         3, 29.99, NULL,              true);

INSERT INTO genres (genre_id, name) VALUES
    (1, 'Action'), (2, 'Adventure'), (3, 'RPG'),
    (4, 'Puzzle'), (5, 'Roguelike'), (6, 'Sandbox'), (7, 'Shooter');

INSERT INTO game_genres (game_id, genre_id) VALUES
    (1, 1), (1, 7), (2, 4), (2, 1), (3, 3), (3, 1), (3, 2),
    (4, 3), (4, 2), (5, 5), (5, 1), (6, 6), (6, 2), (8, 5), (8, 1);

INSERT INTO users (user_id, username, email) VALUES
    (1, 'ivan', 'ivan@example.bg'), (2, 'maria', 'maria@example.bg'),
    (3, 'georgi', NULL), (4, 'elena', 'elena@example.bg'),
    (5, 'petar', NULL), (6, 'dimitar', NULL);

INSERT INTO reviews (review_id, user_id, game_id, rating, body, reviewed_on) VALUES
    (1, 1, 3, 2, 'Buggy at launch.',          DATE '2020-12-12'),
    (2, 1, 3, 4, 'Much better after patches.', DATE '2023-05-01'),   -- same user+game, different day: allowed
    (3, 2, 5, 5, 'Perfect roguelike.',         DATE '2021-02-10'),
    (4, 4, 4, 5, 'A masterpiece.',             DATE '2016-01-20'),
    (5, 1, 5, 4, 'Great run-based combat.',    DATE '2021-03-03');

-- =============================================================================
-- Experiments to try AFTER loading (reset with setup.sql afterwards):
--
--   -- SET NULL in action: close a studio, its games survive as unknown.
--   DELETE FROM developers WHERE developer_id = 1;
--   SELECT title, developer_id FROM games WHERE game_id IN (1,2);  -- developer_id now NULL
--
--   -- CASCADE: delete a game, its genre tags disappear automatically.
--   DELETE FROM games WHERE game_id = 3;
--   SELECT * FROM game_genres WHERE game_id = 3;                   -- 0 rows
--
--   -- RESTRICT: can't delete a genre still used by a game.
--   DELETE FROM genres WHERE genre_id = 1;                         -- ERROR
--
--   -- UNIQUE candidate key: a second review same user+game+day fails.
--   INSERT INTO reviews (review_id,user_id,game_id,rating,reviewed_on)
--     VALUES (99,1,3,5,DATE '2020-12-12');                         -- ERROR (dup of review 1's day)
-- =============================================================================
