from flask import Blueprint, jsonify, request
from sqlalchemy import text

from . import db
from .models import Movie

inventory_bp = Blueprint("inventory", __name__)


@inventory_bp.get("/health")
def health():
    try:
        db.session.execute(text("SELECT 1"))
        return jsonify({"status": "ok", "service": "inventory-app"}), 200
    except Exception:
        db.session.rollback()
        return jsonify({"status": "unavailable", "service": "inventory-app"}), 503


@inventory_bp.route("/api/movies", methods=["GET", "POST", "DELETE"], strict_slashes=False)
def handle_movies():
    if request.method == "GET":
        query = Movie.query
        if title := request.args.get("title"):
            query = query.filter(Movie.title.ilike(f"%{title}%"))
        movies = query.all()
        return jsonify([movie.to_dict() for movie in movies]), 200

    if request.method == "POST":
        data = request.get_json(silent=True)
        if not isinstance(data, dict) or not data.get("title"):
            return jsonify({"error": "Movie title is required"}), 400

        new_movie = Movie(title=data["title"], description=data.get("description", ""))
        db.session.add(new_movie)
        db.session.commit()
        return jsonify(new_movie.to_dict()), 201

    deleted_count = db.session.query(Movie).delete()
    db.session.commit()
    return jsonify({"message": f"Successfully deleted all {deleted_count} movies."}), 200


@inventory_bp.route(
    "/api/movies/<int:movie_id>", methods=["GET", "PUT", "DELETE"], strict_slashes=False
)
def handle_movie_by_id(movie_id):
    movie = db.session.get(Movie, movie_id)
    if not movie:
        return jsonify({"error": "Movie not found"}), 404

    if request.method == "GET":
        return jsonify(movie.to_dict()), 200

    if request.method == "PUT":
        data = request.get_json(silent=True)
        if not isinstance(data, dict) or not data:
            return jsonify({"error": "Invalid payload"}), 400

        if "title" in data:
            if not data["title"]:
                return jsonify({"error": "Movie title is required"}), 400
            movie.title = data["title"]
        if "description" in data:
            movie.description = data["description"]

        db.session.commit()
        return jsonify(movie.to_dict()), 200

    db.session.delete(movie)
    db.session.commit()
    return jsonify({"message": f"Movie with ID {movie_id} deleted successfully."}), 200
