from backend import create_app
from config.database_config import DatabaseConfig

app = create_app()

# Ensure the database connection is established before running the server
try:
    conn = DatabaseConfig.get_connection()  # returns a pyodbc.Connection
    cursor = conn.cursor()
    cursor.execute("SELECT 1")
    result = cursor.fetchone()
    print("✅ Database connection successful:", result)
    conn.close()
except Exception as e:
    print(f"❌ Database connection failed: {e}")

if __name__ == '__main__':
    app.run(
        host=app.config['HOST'],
        port=app.config['PORT'],
        debug=True,
    )

# run: python -m backend.main at the root of the project