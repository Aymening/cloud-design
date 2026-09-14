FROM debian:12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends rabbitmq-server \
    && rm -rf /var/lib/apt/lists/*

ENV HOME=/var/lib/rabbitmq \
    RABBITMQ_MNESIA_BASE=/var/lib/rabbitmq/mnesia \
    RABBITMQ_NODENAME=rabbit@rabbit-queue

COPY --chmod=755 srcs/rabbit-queue/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

EXPOSE 5672
VOLUME ["/var/lib/rabbitmq"]
STOPSIGNAL SIGTERM

HEALTHCHECK --interval=5s --timeout=10s --start-period=30s --retries=12 \
    CMD runuser -u rabbitmq -- rabbitmq-diagnostics -q ping || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["rabbitmq-server"]
