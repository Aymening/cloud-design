# RabbitMQ queue topology

Read straight from the actual pika code in `srcs/api-gateway-app/app/routes.py`
and `srcs/billing-app/app/consumer.py` — not a guess.

```mermaid
flowchart LR
    Client -->|POST /api/billing| Gateway[api-gateway-app]
    Gateway -->|"publish (default exchange, routing_key=billing_queue)"| Queue[("billing_queue<br/>durable")]
    Queue -->|basic_consume| Billing[billing-app]
    Billing -->|INSERT| DB[(billing-db)]
```

## Details

- **Exchange**: none — publishes go to RabbitMQ's built-in default exchange
  (`exchange=''`), which routes by routing key straight to a queue of the
  same name. No custom exchange or bindings to manage.
- **Queue**: single queue, name `billing_queue` (from the `RABBITMQ_QUEUE`
  env var), declared `durable=true` by both the publisher and the consumer
  so it survives a broker restart.
- **Delivery mode**: `delivery_mode=2` (persistent) on publish, so queued
  messages are written to disk, not just kept in memory.
- **Consumption**: `billing-app` manually acks (`basic_ack`) after a
  successful DB insert, or nacks without requeue (`basic_nack(requeue=False)`)
  on error — a poison message is dropped rather than retried forever.
- **Message body**: raw JSON forwarded as-is from the gateway's request body,
  e.g. `{"user_id": "...", "number_of_items": 2, "total_amount": 41.98}`.

## Why this needs persistent storage on AWS

The queue is durable and messages are persistent, but that only protects
against a broker *restart* — the data still lives on whatever filesystem the
container sees. On ECS, a task's local filesystem is ephemeral: if the task
is replaced, `/var/lib/rabbitmq` is gone with it. Sub-task 3 attaches an EFS
volume so RabbitMQ's data directory survives task replacement, not just
broker restarts.
