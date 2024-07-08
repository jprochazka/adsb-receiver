from datetime import timedelta
from flask import Flask, render_template
from flask_jwt_extended import JWTManager
from backend.routes.blog import blog
from backend.routes.flights import flights
from backend.routes.links import links
from backend.routes.notifications import notifications
from backend.routes.settings import settings
from backend.routes.tokens import tokens
from backend.routes.users import users

def create_app():
    app = Flask(__name__)
    app.json.sort_keys = False

    app.config["JWT_SECRET_KEY"] = "CHANGE_THIS_IN_PRODUCTION"  # Change this!
    app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(hours=1)
    app.config["JWT_REFRESH_TOKEN_EXPIRES"] = timedelta(days=365)
    jwt = JWTManager(app)

    app.register_blueprint(blog)
    app.register_blueprint(flights)
    app.register_blueprint(links)
    app.register_blueprint(notifications)
    app.register_blueprint(settings)
    app.register_blueprint(tokens)
    app.register_blueprint(users)

    # /API/DOCS

    @app.route('/api/docs')
    def get_docs():
        return render_template('swaggerui.html')
    
    return app