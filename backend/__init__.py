from dotenv import load_dotenv
load_dotenv()   # Must run before Config is imported

from flask import Flask

from config.config import Config
from config.logger import get_logger

from backend.endpoints.frontend_routes import frontend_blueprint
from backend.endpoints.db_admin_routes import db_admin_api
from backend.endpoints.record_label import record_label_api
from backend.endpoints.employee import employee_api
from backend.endpoints.songs import songs_api
from backend.endpoints.contributors import contributors_api
from backend.endpoints.collaborations import collab_api
from backend.endpoints.dashboard import dashboard_api

logger = get_logger(__name__)

def create_app():
    app = Flask(
        __name__,
        static_folder='../frontend/static',      # point to static folder
        template_folder='../frontend/templates'  # point to templates folder
    )

    # Load and validate configuration from environment variables into Flask config
    app.config.from_object(Config)

    app.register_blueprint(frontend_blueprint)
    app.register_blueprint(db_admin_api)
    app.register_blueprint(record_label_api)
    app.register_blueprint(employee_api)
    app.register_blueprint(songs_api)
    app.register_blueprint(contributors_api)
    app.register_blueprint(collab_api)
    app.register_blueprint(dashboard_api)

    return app