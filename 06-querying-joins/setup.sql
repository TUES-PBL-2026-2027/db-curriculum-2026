-- =============================================================================
-- Lesson 06 · Querying — Joins and Join Cardinality
-- Storefront database snapshot (STAGE 6)
-- =============================================================================
--
-- Builds on Stage 5 (lesson 05). The schema so far is SOUND (normalized through
-- Module 2); from here Module 3 stops SHAPING data and starts ASKING questions
-- of it. What changed vs. the previous lesson:
--   * NEW tables for an achievements feature, giving us a second independent M:N
--     relationship to join alongside genres — so we can demonstrate how joining
--     two independent one-to-many relationships MULTIPLIES rows (join inflation):
--       - achievements        : one row per achievement a game defines
--       - user_achievements    : which user unlocked which achievement, and when
--   * RICHER review seed: more games now have reviews, with a spread of ratings
--     and multiple reviews per game, so aggregation (lesson 07) and window-
--     function rankings (lesson 09) have something real to chew on. Some games
--     still have NO reviews on purpose — that is the anti-join / "find the gaps"
--     material (LEFT JOIN ... IS NULL, NOT EXISTS).
--
-- NOTHING is removed. Every table and row from Stage 5 still exists; we only add.
--
-- Idempotent. Load with:  storefront -f 06-querying-joins/setup.sql
-- =============================================================================

DROP VIEW  IF EXISTS games_denormalized_bad;
DROP TABLE IF EXISTS user_achievements;
DROP TABLE IF EXISTS achievements;
DROP TABLE IF EXISTS purchase_items;
DROP TABLE IF EXISTS purchases;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS game_genres;
DROP TABLE IF EXISTS genres;
DROP TABLE IF EXISTS games;
DROP TABLE IF EXISTS developers;
DROP TABLE IF EXISTS users;

CREATE TABLE developers (
    developer_id integer PRIMARY KEY,
    name         text    NOT NULL UNIQUE,
    country      text,
    country_code char(2) CHECK (country_code ~ '^[A-Z]{2}$'),
    founded_year integer CHECK (founded_year BETWEEN 1950 AND 2100)
);

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

CREATE TABLE reviews (
    review_id    integer PRIMARY KEY,
    user_id      integer NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
    game_id      integer NOT NULL REFERENCES games (game_id) ON DELETE CASCADE,
    rating       integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
    body         text,
    reviewed_on  date    NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE (user_id, game_id, reviewed_on)
);

CREATE TABLE purchases (
    purchase_id  integer     PRIMARY KEY,
    user_id      integer     NOT NULL REFERENCES users (user_id) ON DELETE RESTRICT,
    purchased_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE purchase_items (
    purchase_id    integer      NOT NULL REFERENCES purchases (purchase_id) ON DELETE CASCADE,
    game_id        integer      NOT NULL REFERENCES games (game_id) ON DELETE RESTRICT,
    price_paid_eur numeric(8,2) NOT NULL CHECK (price_paid_eur >= 0),
    PRIMARY KEY (purchase_id, game_id)
);

-- -----------------------------------------------------------------------------
-- achievements  (one row per achievement a game defines)
--   A game HAS MANY achievements; each achievement belongs to ONE game (1:N).
--   Surrogate PK; (game_id, code) is the natural key — unique within a game.
-- -----------------------------------------------------------------------------
CREATE TABLE achievements (
    achievement_id integer PRIMARY KEY,
    game_id        integer NOT NULL REFERENCES games (game_id) ON DELETE CASCADE,
    code           text    NOT NULL,               -- short stable identifier, unique per game
    name           text    NOT NULL,
    UNIQUE (game_id, code)
);

-- -----------------------------------------------------------------------------
-- user_achievements  (which user unlocked which achievement, and when)
--   M:N between users and achievements, resolved by this junction (lesson 03's
--   pattern). Composite PK: a user unlocks a given achievement at most once.
-- -----------------------------------------------------------------------------
CREATE TABLE user_achievements (
    user_id        integer     NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
    achievement_id integer     NOT NULL REFERENCES achievements (achievement_id) ON DELETE CASCADE,
    unlocked_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, achievement_id)
);

-- =============================================================================
-- Seed data
-- =============================================================================

INSERT INTO developers (developer_id, name, country, country_code, founded_year) VALUES
    (1, 'Valve', 'United States', 'US', 1996),
    (2, 'CD Projekt Red', 'Poland', 'PL', 1994),
    (3, 'Supergiant Games', 'United States', 'US', 2009),
    (4, 'Mojang Studios', 'Sweden', 'SE', 2009),
    (5, 'Indie Newcomer', NULL, NULL, NULL);

INSERT INTO games (game_id, title, developer_id, price_eur, released_on, is_published) VALUES
    (1, 'Half-Life 2', 1, 9.99, DATE '2004-11-16', true),
    (2, 'Portal 2', 1, 19.99, DATE '2011-04-19', true),
    (3, 'Cyberpunk 2077', 2, 59.99, DATE '2020-12-10', true),
    (4, 'The Witcher 3', 2, 39.99, DATE '2015-05-19', true),
    (5, 'Hades', 3, 24.99, DATE '2020-09-17', true),
    (6, 'Minecraft', 4, 26.99, DATE '2011-11-18', true),
    (7, 'Untitled Project', 5, 0.00, NULL, false),
    (8, 'Hades II', 3, 29.99, NULL, true);

INSERT INTO genres (genre_id, name) VALUES
    (1,'Action'),(2,'Adventure'),(3,'RPG'),(4,'Puzzle'),(5,'Roguelike'),(6,'Sandbox'),(7,'Shooter');

INSERT INTO game_genres (game_id, genre_id) VALUES
    (1,1),(1,7),(2,4),(2,1),(3,3),(3,1),(3,2),(4,3),(4,2),(5,5),(5,1),(6,6),(6,2),(8,5),(8,1);

INSERT INTO users (user_id, username, email) VALUES
    (1,'ivan','ivan@example.bg'),(2,'maria','maria@example.bg'),(3,'georgi',NULL),
    (4,'elena','elena@example.bg'),(5,'petar',NULL),(6,'dimitar',NULL);

-- Richer review seed than Stage 5: a spread of ratings, several games reviewed,
-- multiple reviews per game. Games 1 (Half-Life 2), 7 (Untitled Project) and
-- 8 (Hades II) still have NO reviews on purpose (anti-join material).
INSERT INTO reviews (review_id, user_id, game_id, rating, body, reviewed_on) VALUES
    (1, 1, 3, 2, 'Buggy at launch.',            DATE '2020-12-12'),
    (2, 1, 3, 4, 'Much better after patches.',  DATE '2023-05-01'),
    (3, 2, 5, 5, 'Perfect roguelike.',          DATE '2021-02-10'),
    (4, 4, 4, 5, 'A masterpiece.',               DATE '2016-01-20'),
    (5, 1, 5, 4, 'Great run-based combat.',     DATE '2021-03-03'),
    (6, 2, 3, 3, 'Good now, still rough edges.', DATE '2024-02-14'),
    (7, 3, 4, 4, 'Huge world, great writing.',   DATE '2017-08-09'),
    (8, 2, 2, 5, 'Still the best puzzle game.',  DATE '2019-06-30'),
    (9, 4, 2, 4, 'Clever and funny.',            DATE '2020-01-11'),
    (10,5, 6, 3, 'Fun but repetitive.',          DATE '2022-11-02'),
    (11,3, 5, 5, 'Addictive.',                    DATE '2022-07-19');

INSERT INTO purchases (purchase_id, user_id, purchased_at) VALUES
    (1, 1, TIMESTAMPTZ '2021-01-05 14:30:00+00'),
    (2, 2, TIMESTAMPTZ '2021-02-11 09:15:00+00'),
    (3, 1, TIMESTAMPTZ '2023-06-20 20:00:00+00');

INSERT INTO purchase_items (purchase_id, game_id, price_paid_eur) VALUES
    (1, 5, 14.99),
    (1, 3, 59.99),
    (2, 5, 24.99),
    (3, 4, 11.99);

-- Achievements. Games 3 (Cyberpunk) and 5 (Hades) define several; Portal 2 (2)
-- defines one; most games define none (so a games⟕achievements LEFT JOIN has
-- NULLs to talk about).
INSERT INTO achievements (achievement_id, game_id, code, name) VALUES
    (1, 3, 'THE_WANDERING_FOOL', 'The Wandering Fool'),
    (2, 3, 'BREATHTAKING',        'Breathtaking'),
    (3, 5, 'IS_THERE_NO_ESCAPE',  'Is There No Escape?'),
    (4, 5, 'THE_FAMILY_SECRET',   'The Family Secret'),
    (5, 5, 'LIQUID_GOLD',         'Liquid Gold'),
    (6, 2, 'TOTAL_PERSPECTIVE',   'Total Perspective Vortex');

-- Who unlocked what. ivan (1) and maria (2) are active; petar (5), elena (4)
-- a little; georgi (3) and dimitar (6) have unlocked nothing (anti-join material).
INSERT INTO user_achievements (user_id, achievement_id, unlocked_at) VALUES
    (1, 1, TIMESTAMPTZ '2023-05-02 18:00:00+00'),
    (1, 3, TIMESTAMPTZ '2021-03-01 21:30:00+00'),
    (1, 4, TIMESTAMPTZ '2021-03-10 19:00:00+00'),
    (2, 3, TIMESTAMPTZ '2021-02-12 10:00:00+00'),
    (2, 6, TIMESTAMPTZ '2019-07-01 12:00:00+00'),
    (4, 6, TIMESTAMPTZ '2020-01-12 08:00:00+00'),
    (5, 1, TIMESTAMPTZ '2024-03-03 15:00:00+00');

-- =============================================================================
-- Discussion queries (see PRACTICE.md):
--   -- Join inflation: joining genres AND achievements to games multiplies rows.
--   --   Cyberpunk has 3 genres and 2 achievements -> 3*2 = 6 rows for ONE game.
--   SELECT g.title, ge.name AS genre, a.name AS achievement
--   FROM games g
--   JOIN game_genres gg ON gg.game_id = g.game_id
--   JOIN genres ge      ON ge.genre_id = gg.genre_id
--   JOIN achievements a ON a.game_id   = g.game_id
--   WHERE g.title = 'Cyberpunk 2077';
--
--   -- Anti-join: games with no reviews at all.
--   SELECT g.title FROM games g
--   LEFT JOIN reviews r ON r.game_id = g.game_id
--   WHERE r.review_id IS NULL ORDER BY g.title;
-- =============================================================================
