import os
import json
import signal
import time
from decimal import Decimal
from threading import Thread

import pika
from flask import Flask, jsonify
from sqlalchemy.exc import OperationalError, SQLAlchemyError
from app.database import SessionLocal, Base, engine
from app.models import Order

def required_environment(name):
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required RabbitMQ configuration: {name}")
    return value


RABBITMQ_HOST = required_environment("RABBITMQ_HOST")
RABBITMQ_PORT = int(required_environment("RABBITMQ_PORT"))
RABBITMQ_USER = required_environment("RABBITMQ_USER")
RABBITMQ_PASSWORD = required_environment("RABBITMQ_PASSWORD")
RABBITMQ_QUEUE = required_environment("RABBITMQ_QUEUE")
SERVICE_PORT = int(os.getenv("BILLING_PORT", "8080"))
SERVICE_READY = False


def start_health_server():
    health_app = Flask(__name__)

    @health_app.get("/health")
    def health():
        status = "ok" if SERVICE_READY else "starting"
        status_code = 200 if SERVICE_READY else 503
        return jsonify({"status": status, "service": "billing-app"}), status_code

    thread = Thread(
        target=health_app.run,
        kwargs={"host": "0.0.0.0", "port": SERVICE_PORT, "debug": False, "use_reloader": False},
        daemon=True,
    )
    thread.start()


def init_db():
    while True:
        try:
            Base.metadata.create_all(bind=engine)
            return
        except SQLAlchemyError as error:
            print(f" [!] Billing database not ready: {error}; retrying in 5 seconds...", flush=True)
            time.sleep(5)


def process_message(ch, method, _properties, body):
    session = SessionLocal()
    try:
        data = json.loads(body.decode('utf-8'))
        print(f" [x] Received order message: {data}")

        user_id = str(data.get("user_id"))
        number_of_items = int(data["number_of_items"])
        total_amount = Decimal(str(data["total_amount"]))

        new_order = Order(
            user_id=user_id,
            number_of_items=number_of_items,
            total_amount=total_amount
        )
        session.add(new_order)
        session.commit()
        print(" [✓] Order successfully inserted into orders table.")

        ch.basic_ack(delivery_tag=method.delivery_tag)

    except OperationalError as error:
        # billing-db can't be reached: put the order back in the queue and
        # wait before the next try, so no order is lost while it is down.
        print(f" [!] Billing database unavailable: {error}; order requeued, retrying in 5 seconds...", flush=True)
        session.rollback()
        time.sleep(5)
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

    except Exception as error:
        print(f" [!] Error processing message: {error}", flush=True)
        session.rollback()
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
    finally:
        session.close()


def stop_on_sigterm(_signum, _frame):
    # ECS stops a task with SIGTERM. Python running as PID 1 ignores it by
    # default, so the task would keep taking orders until ECS kills it 30 s
    # later. Stop consuming now instead: an order not yet acked goes back to
    # the queue.
    raise KeyboardInterrupt


def start_consumer():
    global SERVICE_READY

    signal.signal(signal.SIGTERM, stop_on_sigterm)
    start_health_server()
    init_db()
    
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
    parameters = pika.ConnectionParameters(
        host=RABBITMQ_HOST,
        port=RABBITMQ_PORT,
        credentials=credentials,
        heartbeat=600
    )

    # Connect, and reconnect whenever the connection is lost (RabbitMQ not
    # started yet, restarted or replaced). A message that wasn't acked goes
    # back to the queue, so no order is lost in between. While disconnected,
    # /health answers 503: if RabbitMQ stays away, ECS replaces the task.
    while True:
        connection = None
        try:
            connection = pika.BlockingConnection(parameters)
            channel = connection.channel()
            channel.queue_declare(queue=RABBITMQ_QUEUE, durable=True)

            channel.basic_qos(prefetch_count=1)

            channel.basic_consume(
                queue=RABBITMQ_QUEUE,
                on_message_callback=process_message,
                auto_ack=False
            )

            SERVICE_READY = True
            print(f" [*] Billing API service started. Waiting for messages in '{RABBITMQ_QUEUE}'...")
            channel.start_consuming()
        # OSError: rabbit-queue.local doesn't resolve while the broker task is
        # being replaced, which pika reports as a socket error.
        except (pika.exceptions.AMQPError, OSError) as error:
            SERVICE_READY = False
            print(f" [!] RabbitMQ not reachable ({error!r}), retrying in 5 seconds...")
        except KeyboardInterrupt:
            print(" [x] Stopping Billing Consumer...")
            return
        finally:
            if connection and connection.is_open:
                try:
                    connection.close()
                except pika.exceptions.AMQPError:
                    pass
        time.sleep(5)
