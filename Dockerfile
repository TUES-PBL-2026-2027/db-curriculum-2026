# PostgreSQL for the DB curriculum.
#
# Thin wrapper over the official image, pinned to 18 (current stable major).
FROM postgres:18

# Example of how we'd add things later (left commented on purpose):
#   RUN apt-get update && apt-get install -y --no-install-recommends postgresql-contrib \
#       && rm -rf /var/lib/apt/lists/*
#
# Anything placed in /docker-entrypoint-initdb.d is run ONLY on first init of an
# empty data directory. We intentionally do NOT auto-load lesson scripts: lessons
# are meant to be loaded one snapshot at a time, by hand (see docker/README.md).
