import os

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.engine import URL
from dotenv import load_dotenv

load_dotenv()

db = SQLAlchemy()


def required_environment(*names):
    missing = [name for name in names if not os.getenv(name)]
    if missing:
        raise RuntimeError(f"Missing required Inventory configuration: {', '.join(missing)}")


def create_app():
    app = Flask(__name__)

    required_environment(
        "INVENTORY_DB_USER",
        "INVENTORY_DB_PASSWORD",
        "INVENTORY_DB_HOST",
        "INVENTORY_DB_PORT",
        "INVENTORY_DB_NAME",
    )

    app.config["SQLALCHEMY_DATABASE_URI"] = URL.create(
        drivername="postgresql+psycopg2",
        username=os.environ["INVENTORY_DB_USER"],
        password=os.environ["INVENTORY_DB_PASSWORD"],
        host=os.environ["INVENTORY_DB_HOST"],
        port=int(os.environ["INVENTORY_DB_PORT"]),
        database=os.environ["INVENTORY_DB_NAME"],
    )
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

    db.init_app(app)

    with app.app_context():
        from . import models  # noqa: F401

        db.create_all()

    from .routes import inventory_bp

    app.register_blueprint(inventory_bp)
    return app
