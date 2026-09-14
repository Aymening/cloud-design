import os

import pika
import requests
from flask import Blueprint, Response, jsonify, request

gateway_bp = Blueprint('gateway', __name__)


@gateway_bp.get('/health')
def health():
    return jsonify({"status": "ok", "service": "api-gateway-app"}), 200


def required_environment(name):
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required Gateway configuration: {name}")
    return value


INVENTORY_SERVICE_URL = required_environment("INVENTORY_SERVICE_URL")
RABBITMQ_HOST = required_environment("RABBITMQ_HOST")
RABBITMQ_PORT = int(required_environment("RABBITMQ_PORT"))
RABBITMQ_USER = required_environment("RABBITMQ_USER")
RABBITMQ_PASSWORD = required_environment("RABBITMQ_PASSWORD")
RABBITMQ_QUEUE = required_environment("RABBITMQ_QUEUE")


def publish_to_rabbitmq(message_body):
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASSWORD)
    parameters = pika.ConnectionParameters(
        host=RABBITMQ_HOST,
        port=RABBITMQ_PORT,
        credentials=credentials
    )
    connection = None
    try:
        connection = pika.BlockingConnection(parameters)
        channel = connection.channel()
        channel.queue_declare(queue=RABBITMQ_QUEUE, durable=True)
        channel.basic_publish(
            exchange='',
            routing_key=RABBITMQ_QUEUE,
            body=message_body,
            properties=pika.BasicProperties(delivery_mode=2)
        )
    finally:
        if connection and connection.is_open:
            connection.close()


@gateway_bp.route(
    '/api/movies',
    defaults={'path': ''},
    methods=['GET', 'POST', 'DELETE'],
    strict_slashes=False
)
@gateway_bp.route(
    '/api/movies/<path:path>',
    methods=['GET', 'PUT', 'DELETE'],
    strict_slashes=False
)
def proxy_to_inventory(path):
    target_url = f"{INVENTORY_SERVICE_URL}/api/movies"
    if path:
        target_url = f"{target_url}/{path}"
        
    headers = {key: value for key, value in request.headers if key.lower() != 'host'}
    
    try:
        resp = requests.request(
            method=request.method,
            url=target_url,
            headers=headers,
            params=request.args,
            data=request.get_data(),
            allow_redirects=False,
            timeout=10
        )
        excluded_headers = ['content-encoding', 'content-length', 'transfer-encoding', 'connection']
        resp_headers = [(name, value) for (name, value) in resp.raw.headers.items()
                        if name.lower() not in excluded_headers]
        
        return Response(resp.content, resp.status_code, resp_headers)
    except requests.exceptions.RequestException:
        return jsonify({"error": "Inventory service unavailable"}), 503


@gateway_bp.route('/api/billing', methods=['POST'], strict_slashes=False)
def proxy_to_billing():
    if not request.is_json:
        return jsonify({"error": "Content-Type must be application/json"}), 400

    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify({"error": "Request body must be a JSON object"}), 400

    required_fields = ["user_id", "number_of_items", "total_amount"]
    missing_fields = [field for field in required_fields if field not in data]
    
    if missing_fields:
        return jsonify({"error": f"Missing required fields: {', '.join(missing_fields)}"}), 400

    try:
        number_of_items = int(data["number_of_items"])
        total_amount = float(data["total_amount"])
        if number_of_items <= 0 or total_amount < 0:
            raise ValueError
    except (TypeError, ValueError):
        return jsonify({"error": "number_of_items must be positive and total_amount must be non-negative"}), 400

    try:
        publish_to_rabbitmq(request.get_data())
        return jsonify({"message": "Message posted"}), 200
    except (pika.exceptions.AMQPError, OSError):
        return jsonify({"error": "Billing queue unavailable"}), 503
