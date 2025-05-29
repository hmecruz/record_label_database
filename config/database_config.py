from .env_loader import get_env_variable

class DatabaseConfig:
    DB_USER = get_env_variable("DB_USER", default="p1g9")
    DB_PASSWORD = get_env_variable("DB_PASSWORD", default="Zxcv4g97!")
    DB_NAME = get_env_variable("DB_NAME", default="p1g9")
    CONN_STRING = get_env_variable("DB_CONN_STRING", default="tcp:mednat.ieeta.pt\SQLSERVER,8101")
