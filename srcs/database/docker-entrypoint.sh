#!/bin/sh
set -eu

for name in POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB; do
    if [ -z "$(printenv "$name")" ]; then
        echo "$name is required" >&2
        exit 1
    fi
done

mkdir -p "$PGDATA" /run/postgresql
chown -R postgres:postgres "$PGDATA" /run/postgresql
chmod 700 "$PGDATA"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "Initializing PostgreSQL data directory"
    runuser -u postgres -- initdb \
        --pgdata="$PGDATA" \
        --username=postgres \
        --auth-local=trust \
        --auth-host=scram-sha-256

    printf "\nlisten_addresses = '*'\n" >> "$PGDATA/postgresql.conf"
    printf "\nhost all all 0.0.0.0/0 scram-sha-256\nhost all all ::/0 scram-sha-256\n" \
        >> "$PGDATA/pg_hba.conf"

    runuser -u postgres -- pg_ctl \
        --pgdata="$PGDATA" \
        --options="-c listen_addresses=''" \
        --wait start

    trap 'runuser -u postgres -- pg_ctl --pgdata="$PGDATA" --mode=fast --wait stop' EXIT INT TERM

    runuser -u postgres -- psql -U postgres -d postgres \
        -v db_user="$POSTGRES_USER" \
        -v db_password="$POSTGRES_PASSWORD" \
        -v db_name="$POSTGRES_DB" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN', :'db_user')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'db_user') \gexec
SELECT format('ALTER ROLE %I WITH PASSWORD %L', :'db_user', :'db_password') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db_name') \gexec
SQL

    runuser -u postgres -- pg_ctl -D "$PGDATA" -m fast -w stop
    trap - EXIT INT TERM
fi

exec runuser -u postgres -- postgres -D "$PGDATA"
