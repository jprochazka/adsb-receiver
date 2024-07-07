from flask import Flask, render_template
from backend.routes.blog import blog
from backend.routes.flights import flights
from backend.routes.links import links
from backend.routes.settings import settings
from backend.routes.users import users

def create_app():
    app = Flask(__name__)
    app.json.sort_keys = False

    app.register_blueprint(blog)
    app.register_blueprint(flights)
    app.register_blueprint(links)
    app.register_blueprint(settings)
    app.register_blueprint(users)

    # /API/DOCS

    @app.route('/api/docs')
    def get_docs():
        return render_template('swaggerui.html')
    
    return app