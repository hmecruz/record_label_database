from dotenv import load_dotenv
load_dotenv()   # Must run before Config is imported

from flask import Flask
from config.config import Config
from config.logger import get_logger

logger = get_logger(__name__)

def create_app():
    app = Flask(__name__)

    # Load and validate configuration from environment variables into Flask config
    app.config.from_object(Config)

    return app