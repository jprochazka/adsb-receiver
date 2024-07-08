from flask import Blueprint, jsonify
from flask_jwt_extended import create_access_token, create_refresh_token, get_jwt_identity, jwt_required


tokens = Blueprint('tokens', __name__)

# TODO: Some form of authentication needs to be added still
@tokens.route("/api/token/login", methods=["POST"])
def login():
    access_token = create_access_token(identity="developer")
    refresh_token = create_refresh_token(identity="developer")
    return jsonify(access_token=access_token, refresh_token=refresh_token)

# http POST :5000/refresh Authorization:"Bearer $REFRESH_TOKEN"
@tokens.route("/api/token/refresh", methods=["POST"])
@jwt_required(refresh=True)
def refresh():
    identity = get_jwt_identity()
    access_token = create_access_token(identity=identity)
    return jsonify(access_token=access_token)