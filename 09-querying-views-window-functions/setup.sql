-- =============================================================================
-- Lesson 09 · Querying — Views and Window Functions
-- Storefront database snapshot (STAGE 9)
-- =============================================================================
--
-- Builds on Stage 8 (lesson 08). The BASE TABLES and SEED DATA are unchanged.
-- What is NEW this stage is two VIEWS, promoted to first-class schema objects —
-- the inflation-safe per-game reports we kept rewriting in lessons 07/08 now
-- have names and live in the checkpoint:
--   * game_ratings  : per-game review count and average rating (0-review games
--                     kept, avg = NULL) — the lesson-07 report, reusable.
--   * game_revenue  : per-game copies sold and total revenue (never-sold games
--                     kept at 0).
-- Plus one MATERIALIZED VIEW as the extension demo:
--   * game_ratings_mv : a stored snapshot of game_ratings you must REFRESH.
--
-- Views add no data — they are saved queries. They close Module 3: we have now
-- read the storefront every way, and wrapped the good reports for reuse.
--
-- NOTHING is removed. Idempotent (views are dropped and recreated).
-- Load with:  storefront -f 09-querying-views-window-functions/setup.sql
-- =============================================================================

DROP MATERIALIZED VIEW IF EXISTS game_ratings_mv;
DROP VIEW  IF EXISTS game_revenue;
DROP VIEW  IF EXISTS game_ratings;
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

CREATE TABLE achievements (
    achievement_id integer PRIMARY KEY,
    game_id        integer NOT NULL REFERENCES games (game_id) ON DELETE CASCADE,
    code           text    NOT NULL,
    name           text    NOT NULL,
    UNIQUE (game_id, code)
);

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

-- Stage 7: expanded purchase history (was 3 purchases / 4 items in Stage 6).
-- Spread chosen so aggregation has something to say:
--   ivan   (1): purchases 1, 3, 7  -> several purchases, the biggest spender
--   maria  (2): purchases 2, 6     -> two purchases
--   elena  (4): purchase  4        -> one purchase, two items
--   petar  (5): purchase  5        -> one purchase, one item (the single-buy case)
--   georgi (3), dimitar (6): no purchases at all (anti-join material, lesson 08)
-- Prices are the price PAID (historical), often below today's price_eur — some
-- of these were bought during sales. This is the lesson-05 "capture the price at
-- purchase" rule still doing its job.
INSERT INTO purchases (purchase_id, user_id, purchased_at) VALUES
    (1, 1, TIMESTAMPTZ '2021-01-05 14:30:00+00'),
    (2, 2, TIMESTAMPTZ '2021-02-11 09:15:00+00'),
    (3, 1, TIMESTAMPTZ '2023-06-20 20:00:00+00'),
    (4, 4, TIMESTAMPTZ '2022-03-15 11:00:00+00'),
    (5, 5, TIMESTAMPTZ '2023-11-20 17:45:00+00'),
    (6, 2, TIMESTAMPTZ '2024-02-01 08:05:00+00'),
    (7, 1, TIMESTAMPTZ '2024-07-04 22:10:00+00');

INSERT INTO purchase_items (purchase_id, game_id, price_paid_eur) VALUES
    (1, 5, 14.99),   -- ivan:  Hades (sale)
    (1, 3, 59.99),   -- ivan:  Cyberpunk (full price)
    (2, 5, 24.99),   -- maria: Hades (full price)
    (3, 4, 11.99),   -- ivan:  The Witcher 3 (deep sale)
    (4, 2, 19.99),   -- elena: Portal 2
    (4, 4, 39.99),   -- elena: The Witcher 3 (full price)
    (5, 6, 26.99),   -- petar: Minecraft
    (6, 3, 49.99),   -- maria: Cyberpunk (sale)
    (7, 2,  9.99),   -- ivan:  Portal 2 (sale)
    (7, 6, 26.99);   -- ivan:  Minecraft

INSERT INTO achievements (achievement_id, game_id, code, name) VALUES
    (1, 3, 'THE_WANDERING_FOOL', 'The Wandering Fool'),
    (2, 3, 'BREATHTAKING',        'Breathtaking'),
    (3, 5, 'IS_THERE_NO_ESCAPE',  'Is There No Escape?'),
    (4, 5, 'THE_FAMILY_SECRET',   'The Family Secret'),
    (5, 5, 'LIQUID_GOLD',         'Liquid Gold'),
    (6, 2, 'TOTAL_PERSPECTIVE',   'Total Perspective Vortex');

INSERT INTO user_achievements (user_id, achievement_id, unlocked_at) VALUES
    (1, 1, TIMESTAMPTZ '2023-05-02 18:00:00+00'),
    (1, 3, TIMESTAMPTZ '2021-03-01 21:30:00+00'),
    (1, 4, TIMESTAMPTZ '2021-03-10 19:00:00+00'),
    (2, 3, TIMESTAMPTZ '2021-02-12 10:00:00+00'),
    (2, 6, TIMESTAMPTZ '2019-07-01 12:00:00+00'),
    (4, 6, TIMESTAMPTZ '2020-01-12 08:00:00+00'),
    (5, 1, TIMESTAMPTZ '2024-03-03 15:00:00+00');

-- =============================================================================
-- Views  (NEW this stage) — saved queries, no new data.
-- =============================================================================

-- game_ratings: the per-game rating report from lessons 07/08, named once.
-- LEFT JOIN keeps the three unreviewed games (avg_rating = NULL).
CREATE VIEW game_ratings AS
SELECT g.game_id,
       g.title,
       count(r.review_id)      AS n_reviews,
       round(avg(r.rating), 2) AS avg_rating
FROM games g
LEFT JOIN reviews r ON r.game_id = g.game_id
GROUP BY g.game_id, g.title;

-- game_revenue: per-game copies sold and total revenue (never-sold games at 0).
CREATE VIEW game_revenue AS
SELECT g.game_id,
       g.title,
       count(pi.price_paid_eur)               AS copies_sold,
       coalesce(sum(pi.price_paid_eur), 0)    AS revenue
FROM games g
LEFT JOIN purchase_items pi ON pi.game_id = g.game_id
GROUP BY g.game_id, g.title;

-- Extension demo: a MATERIALIZED view stores the result on disk. Unlike a plain
-- view it does NOT track changes — you must REFRESH MATERIALIZED VIEW it after
-- the underlying data changes. (Ties to the Module 5/6 derived-vs-stored thread.)
CREATE MATERIALIZED VIEW game_ratings_mv AS
SELECT * FROM game_ratings;

-- =============================================================================
-- Discussion queries (see PRACTICE.md):
--   -- A view is used exactly like a table:
--   SELECT * FROM game_ratings ORDER BY avg_rating DESC NULLS LAST, title;
--
--   -- Window function: rank games WITHIN each developer, keeping every row.
--   SELECT d.name AS developer, gr.title, gr.avg_rating,
--          rank() OVER (PARTITION BY g.developer_id ORDER BY gr.avg_rating DESC) AS rnk
--   FROM game_ratings gr
--   JOIN games g      ON g.game_id = gr.game_id
--   JOIN developers d ON d.developer_id = g.developer_id
--   WHERE gr.n_reviews > 0
--   ORDER BY d.name, rnk;
--
--   -- Window AVG beside each row (contrast with GROUP BY, which collapses):
--   SELECT g.title, r.rating,
--          round(avg(r.rating) OVER (PARTITION BY r.game_id), 2) AS game_avg
--   FROM reviews r JOIN games g ON g.game_id = r.game_id
--   ORDER BY g.title, r.reviewed_on;
-- =============================================================================
