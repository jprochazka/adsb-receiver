from datetime import timedelta
from flask import Flask, render_template
from flask_apscheduler import APScheduler
from flask_jwt_extended import JWTManager
from backend.jobs.data_collection import data_collection_job
from backend.jobs.maintenance import maintenance_job
from backend.routes.flights import flights
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

    # /API/SCHEDULER

    app.config["SCHEDULER_API_ENABLED"] = True
    app.config["SCHEDULER_API_PREFIX"] = "/api/scheduler"
    scheduler = APScheduler()
    scheduler.add_job(id = 'data_collection', func=data_collection_job, trigger="interval", seconds=15)
    scheduler.add_job(id = 'maintenance', func=maintenance_job, trigger="cron", hour=0)
    scheduler.init_app(app)
    scheduler.start()

    # /API/DOCS

    @app.route('/api/docs')
    def get_docs():
        return render_template('swaggerui.html')
    
    # INIT_APP

    from . import db
    db.init_app(app)
    
    return app