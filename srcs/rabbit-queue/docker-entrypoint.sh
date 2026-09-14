#!/bin/sh
set -eu

for name in RABBITMQ_USER RABBITMQ_PASSWORD RABBITMQ_QUEUE; do
    if [ -z "$(printenv "$name")" ]; then
        echo "$name is required" >&2
        exit 1
    fi
done

if [ "$RABBITMQ_USER" = "guest" ]; then
    echo "Do not use guest as RABBITMQ_USER" >&2
    exit 1
fi

mkdir -p "$RABBITMQ_MNESIA_BASE"
chown -R rabbitmq:rabbitmq /var/lib/rabbitmq

MARKER_FILE=/var/lib/rabbitmq/.initialized

if [ ! -f "$MARKER_FILE" ]; then
    echo "Starting RabbitMQ for first-time setup"
    runuser -u rabbitmq -- rabbitmq-server -detached

    for attempt in $(seq 1 30); do
        runuser -u rabbitmq -- rabbitmq-diagnostics -q check_running && break
        sleep 2
    done
    runuser -u rabbitmq -- rabbitmq-diagnostics -q check_running

    runuser -u rabbitmq -- rabbitmqctl add_user "$RABBITMQ_USER" "$RABBITMQ_PASSWORD"
    runuser -u rabbitmq -- rabbitmqctl set_permissions -p / "$RABBITMQ_USER" '.*' '.*' '.*'
    runuser -u rabbitmq -- rabbitmqctl delete_user guest
    runuser -u rabbitmq -- rabbitmqctl shutdown

    touch "$MARKER_FILE"
    chown rabbitmq:rabbitmq "$MARKER_FILE"
fi

exec runuser -u rabbitmq -- rabbitmq-server
