from .env_loader import get_env_variable

class Config: 
    HOST = get_env_variable("HOST", default="localhost")
    PORT = get_env_variable("PORT", default=5000, cast=int)
