import os
import json
import time
from decimal import Decimal
from threading import Thread

import pika
from flask import Flask, jsonify
from sqlalchemy.exc import SQLAlchemyError
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

    except Exception as error:
        print(f" [!] Error processing message: {error}", flush=True)
        session.rollback()
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)
    finally:
        session.close()


def start_consumer():
    global SERVICE_READY

    start_health_server()
    init_db()
    
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
    parameters = pika.ConnectionParameters(
        host=RABBITMQ_HOST,
        port=RABBITMQ_PORT,
        credentials=credentials,
        heartbeat=600
    )

    while True:
        try:
            connection = pika.BlockingConnection(parameters)
            break
        except pika.exceptions.AMQPConnectionError:
            print(" [!] RabbitMQ not ready yet, retrying in 5 seconds...")
            time.sleep(5)

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
    try:
        channel.start_consuming()
    except KeyboardInterrupt:
        print(" [x] Stopping Billing Consumer...")
        channel.stop_consuming()
        connection.close()
