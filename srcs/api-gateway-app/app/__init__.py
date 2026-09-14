import logging
import os

from flask import Flask, request
from dotenv import load_dotenv

load_dotenv()


def create_app():
    app = Flask(__name__)

    log_file = os.getenv("GATEWAY_LOG_FILE")
    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
        app.logger.addHandler(file_handler)
        app.logger.setLevel(logging.INFO)

    from app.routes import gateway_bp

    app.register_blueprint(gateway_bp)

    @app.after_request
    def log_request(response):
        app.logger.info(
            "%s %s %s",
            response.status_code,
            response.content_length or 0,
            request.path,
        )
        return response

    return app
