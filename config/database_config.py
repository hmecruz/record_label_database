import pyodbc
from .env_loader import get_env_variable

class DatabaseConfig:
    DB_USER = get_env_variable("DB_USER", default="")
    DB_PASSWORD = get_env_variable("DB_PASSWORD", default="")
    DB_NAME = get_env_variable("DB_NAME", default="")
    CONN_STRING = get_env_variable("DB_CONN_STRING", default="")

    def get_connection():
        # use the variables that are set in the environment
        conn_str = (
            "DRIVER={ODBC Driver 17 for SQL Server};"
            f"SERVER={DatabaseConfig.CONN_STRING};"
            f"DATABASE={DatabaseConfig.DB_NAME};"
            f"UID={DatabaseConfig.DB_USER};"
            f"PWD={DatabaseConfig.DB_PASSWORD};"
            "Encrypt=no;"  # Disable if encryption causes issues
        )
        return pyodbc.connect(conn_str)
