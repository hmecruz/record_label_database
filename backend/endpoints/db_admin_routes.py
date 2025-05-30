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

@db_admin_api.route('/init', methods=['POST'])
def init_schema():
    """
    POST /api/db/init
    1) Executes ddl.sql to (re)create all tables and constraints.
    2) Executes views.sql to create views.
    3) Executes all .sql files in stored_procedures/ to create stored procedures.
    """
    base        = os.path.dirname(os.path.dirname(__file__))  # backend/
    ddl_path    = os.path.join(base, 'database', 'ddl.sql')
    views_path  = os.path.join(base, 'database', 'views.sql')
    sp_folder   = os.path.join(base, 'database', 'stored_procedures')  

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()

        # 1) Create tables & constraints
        _exec_sql_file(cursor, ddl_path)

        # 2) Create views
        _exec_sql_file(cursor, views_path)

        # 3) Create stored procedures
        for filename in sorted(os.listdir(sp_folder)):
            if filename.lower().endswith('.sql'):
                sp_path = os.path.join(sp_folder, filename)
                _exec_sql_file(cursor, sp_path)

        conn.commit()
        return jsonify({
            "message": "Schema, views, and stored procedures initialized successfully."
        }), 200

    except pyodbc.Error as e:
        conn.rollback()
        abort(500, description=f"Error initializing schema: {e}")
    finally:
        conn.close()

@db_admin_api.route('/populate', methods=['POST'])
def populate_data():
    """
    POST /api/db/populate
    Executes insert_data.sql to seed the database with initial data.
    """
    base     = os.path.dirname(os.path.dirname(__file__))  # backend/
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
