from flask import Flask
from dotenv import load_dotenv

load_dotenv()


def create_app():
    # Requests are logged by gunicorn (--access-logfile -) to stdout, which
    # ECS sends to CloudWatch Logs.
    app = Flask(__name__)

    from app.routes import gateway_bp

    app.register_blueprint(gateway_bp)

    return app
