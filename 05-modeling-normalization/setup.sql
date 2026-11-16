-- =============================================================================
-- Lesson 05 · Modeling — Functional Dependencies & Normalization
-- Storefront database snapshot (STAGE 5)
-- =============================================================================
--
-- Builds on Stage 4 (lesson 04). What changed vs. the previous lesson:
--   * NEW tables for the purchase flow, modelled in THIRD NORMAL FORM:
--       - purchases       : one row per order (who bought, when)
--       - purchase_items  : one row per game in an order (the "order line")
--   * The order line captures price_paid_eur AT THE TIME OF PURCHASE. This is a
--     DELIBERATE, JUSTIFIED duplication of games.price_eur: the historical fact
--     "what the customer actually paid" must NOT change when the current store
--     price later changes. This is the one place we knowingly denormalize, and
--     lesson 05 explains exactly why it is correct (it is a different fact).
--
--   * Also provided: a view 'games_denormalized_bad' that FLATTENS data to
--     demonstrate the update/insert/delete ANOMALIES a non-normalized design
--     suffers. It exists only to be criticized in class; the real tables stay 3NF.
--
-- Idempotent. Load with:  storefront -f 05-modeling-normalization/setup.sql
-- =============================================================================

DROP VIEW  IF EXISTS games_denormalized_bad;
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
    price_eur    numeric(8,2)  NOT NULL CHECK (price_eur >= 0),   -- CURRENT store price
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

-- -----------------------------------------------------------------------------
-- purchases  (one row per order) — 3NF: every non-key column depends on the
-- whole key (user_id/purchased_at are facts about the order itself).
-- -----------------------------------------------------------------------------
CREATE TABLE purchases (
    purchase_id  integer     PRIMARY KEY,
    user_id      integer     NOT NULL REFERENCES users (user_id) ON DELETE RESTRICT,
    purchased_at timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- purchase_items  (the "order line": one row per game in a purchase)
--   price_paid_eur is the historical price AT PURCHASE TIME. It intentionally
--   does NOT reference games.price_eur, because it is a DIFFERENT FACT: the
--   current catalogue price can change later; what the customer paid cannot.
--   This is justified denormalization, discussed in THEORY.md.
-- -----------------------------------------------------------------------------
CREATE TABLE purchase_items (
    purchase_id    integer      NOT NULL REFERENCES purchases (purchase_id) ON DELETE CASCADE,
    game_id        integer      NOT NULL REFERENCES games (game_id) ON DELETE RESTRICT,
    price_paid_eur numeric(8,2) NOT NULL CHECK (price_paid_eur >= 0),  -- frozen at purchase time
    PRIMARY KEY (purchase_id, game_id)
);

-- =============================================================================
-- Seed data (developers/games/etc. as in stage 4)
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

INSERT INTO reviews (review_id, user_id, game_id, rating, body, reviewed_on) VALUES
    (1,1,3,2,'Buggy at launch.',DATE '2020-12-12'),
    (2,1,3,4,'Much better after patches.',DATE '2023-05-01'),
    (3,2,5,5,'Perfect roguelike.',DATE '2021-02-10'),
    (4,4,4,5,'A masterpiece.',DATE '2016-01-20'),
    (5,1,5,4,'Great run-based combat.',DATE '2021-03-03');

-- Purchases. Note Hades was bought by ivan during a SALE at 14.99, even though
-- its current catalogue price is 24.99 — the order line preserves 14.99 forever.
INSERT INTO purchases (purchase_id, user_id, purchased_at) VALUES
    (1, 1, TIMESTAMPTZ '2021-01-05 14:30:00+00'),
    (2, 2, TIMESTAMPTZ '2021-02-11 09:15:00+00'),
    (3, 1, TIMESTAMPTZ '2023-06-20 20:00:00+00');

INSERT INTO purchase_items (purchase_id, game_id, price_paid_eur) VALUES
    (1, 5, 14.99),      -- ivan bought Hades on sale for 14.99 (current price is 24.99)
    (1, 3, 59.99),      -- ... and Cyberpunk at full price in the same order
    (2, 5, 24.99),      -- maria bought Hades later at full price
    (3, 4, 11.99);      -- ivan bought Witcher 3 in a 2023 sale (current price 39.99)

-- =============================================================================
-- A DELIBERATELY BAD, denormalized view — for class criticism only.
-- It flattens game + developer into one wide shape; use it to SEE the anomalies
-- (the real base tables remain normalized).
-- =============================================================================
CREATE VIEW games_denormalized_bad AS
SELECT g.game_id, g.title, g.price_eur,
       d.name         AS developer_name,     -- developer facts repeated on every game row
       d.country      AS developer_country,
       d.country_code AS developer_country_code,
       d.founded_year AS developer_founded_year
FROM games g
LEFT JOIN developers d ON d.developer_id = g.developer_id;

-- =============================================================================
-- Discussion queries (see PRACTICE.md):
--   SELECT * FROM games_denormalized_bad ORDER BY developer_name, title;
--     -> 'CD Projekt Red / Poland / PL / 1994' is duplicated on BOTH its games.
--        Changing the country means updating EVERY such row (update anomaly).
--
--   -- The historical price is independent of the current price:
--   SELECT pi.purchase_id, g.title, pi.price_paid_eur, g.price_eur AS current_price
--   FROM purchase_items pi JOIN games g ON g.game_id = pi.game_id ORDER BY pi.purchase_id;
-- =============================================================================
