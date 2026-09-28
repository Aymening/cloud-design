#!/bin/bash
# Publishes a test order message directly onto billing_queue (same way
# api-gateway-app does) and confirms billing-app actually consumed it and
# wrote the row to billing-db - a real end-to-end test, not just a health
# check.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo ".env not found - copy .env.example to .env first" >&2
  exit 1
fi
set -a
source .env
set +a

TEST_USER_ID="smoke-test-$(date +%s)"

cleanup() {
  echo "Tearing down..."
  docker compose down --volumes
}
trap cleanup EXIT

echo "Building and starting the stack..."
docker compose up -d --build

echo "Waiting for billing-app to become healthy..."
for i in $(seq 1 30); do
  curl -sf http://localhost:8082/health >/dev/null && break
  sleep 2
done

echo "Publishing a test message onto billing_queue for user $TEST_USER_ID..."
docker compose exec -T billing-app python -c "
import os, json, pika

credentials = pika.PlainCredentials(os.environ['RABBITMQ_USER'], os.environ['RABBITMQ_PASSWORD'])
parameters = pika.ConnectionParameters(
    host=os.environ['RABBITMQ_HOST'],
    port=int(os.environ['RABBITMQ_PORT']),
    credentials=credentials,
)
connection = pika.BlockingConnection(parameters)
channel = connection.channel()
queue = os.environ['RABBITMQ_QUEUE']
channel.queue_declare(queue=queue, durable=True)
channel.basic_publish(
    exchange='',
    routing_key=queue,
    body=json.dumps({'user_id': '$TEST_USER_ID', 'number_of_items': 3, 'total_amount': 42.50}),
    properties=pika.BasicProperties(delivery_mode=2),
)
connection.close()
print('Published test message.')
"

echo "Waiting for billing-app to consume it and write the row..."
for i in $(seq 1 15); do
  row=$(docker compose exec -T billing-db psql -U "$BILLING_DB_USER" -d "$BILLING_DB_NAME" -tAc \
    "SELECT user_id || '|' || number_of_items || '|' || total_amount FROM orders WHERE user_id = '$TEST_USER_ID';" \
    2>/dev/null || true)

  if [ -n "$row" ]; then
    echo "Row found in billing-db: $row"
    if [ "$row" = "$TEST_USER_ID|3|42.50" ]; then
      echo "PASS: message was consumed and persisted correctly."
      exit 0
    else
      echo "FAIL: row exists but doesn't match what was published." >&2
      exit 1
    fi
  fi

  sleep 2
done

echo "FAIL: no matching row appeared within 30 seconds." >&2
docker compose logs billing-app --tail=50
exit 1
