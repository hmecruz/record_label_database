import os
from flask import Blueprint, jsonify, abort
from config.database_config import DatabaseConfig
import pyodbc

db_admin_api = Blueprint(
    'db_admin_api',
    __name__,
    url_prefix='/api/db'
)

def _exec_sql_file(cursor, path):
    """
    Read a .sql file, split on GO (on its own line), and execute each batch.
    """
    with open(path, 'r', encoding='utf-8') as f:
        sql = f.read()

    # Split on lines with only 'GO' (possibly with surrounding whitespace)
    batches = []
    current = []
    for line in sql.splitlines():
        if line.strip().upper() == 'GO':
            if current:
                batches.append('\n'.join(current))
                current = []
        else:
            current.append(line)
    if current:
        batches.append('\n'.join(current))

    for batch in batches:
        if batch.strip():
            cursor.execute(batch)

@db_admin_api.route('/drop_tables', methods=['POST'])
def drop_all_tables():
    """
    POST /api/db/drop_tables
    Executes drop_all_tables.sql to drop every table (in the correct order).
    """
    # resolve path to drop_all_tables.sql
    base = os.path.dirname(os.path.dirname(__file__))  # backend/
    sql_path = os.path.join(base, 'database', 'drop_all_tables.sql')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _exec_sql_file(cursor, sql_path)
        conn.commit()
        return jsonify({"message": "All tables dropped successfully."}), 200
    except pyodbc.Error as e:
        conn.rollback()
        abort(500, description=f"Error dropping tables: {e}")
    finally:
        conn.close()

@db_admin_api.route('/populate', methods=['POST'])
def populate_data():
    """
    POST /api/db/populate
    Executes insert_data.sql to seed the database with initial data.
    """
    base = os.path.dirname(os.path.dirname(__file__))  # backend/
    sql_path = os.path.join(base, 'database', 'insert_data.sql')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _exec_sql_file(cursor, sql_path)
        conn.commit()
        return jsonify({"message": "Database populated successfully."}), 200
    except pyodbc.Error as e:
        conn.rollback()
        abort(500, description=f"Error populating data: {e}")
    finally:
        conn.close()
