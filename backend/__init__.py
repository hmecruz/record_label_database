from dotenv import load_dotenv
load_dotenv()   # Must run before Config is imported

from flask import Flask

from config.config import Config
from config.logger import get_logger

from backend.endpoints.frontend_routes import frontend_blueprint

logger = get_logger(__name__)

def create_app():
    app = Flask(
        __name__,
        static_folder='../frontend',          # Static files: CSS, JS
        template_folder='../frontend'         # HTML files
    )

    # Load and validate configuration from environment variables into Flask config
    app.config.from_object(Config)

    app.register_blueprint(frontend_blueprint)

    return app