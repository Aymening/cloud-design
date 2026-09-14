FROM debian:12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-15 \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/postgresql/15/main

ENV PGDATA=/var/lib/postgresql/data \
    PATH=/usr/lib/postgresql/15/bin:$PATH

COPY --chmod=755 srcs/database/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

EXPOSE 5432
VOLUME ["/var/lib/postgresql/data"]
STOPSIGNAL SIGINT

HEALTHCHECK --interval=5s --timeout=5s --start-period=20s --retries=10 \
    CMD pg_isready -h 127.0.0.1 -p 5432 -U "$POSTGRES_USER" -d "$POSTGRES_DB" || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
