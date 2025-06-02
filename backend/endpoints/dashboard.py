from flask import Blueprint, jsonify, abort
from config.database_config import DatabaseConfig
import pyodbc
from config.logger import get_logger
logger = get_logger(__name__)


dashboard_api = Blueprint(
    'dashboard_api',
    __name__,
    url_prefix='/api/dashboard'
)

@dashboard_api.route('/counts', methods=['GET'])
def get_counts():
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("EXEC dbo.sp_GetDashboardCounts")
        row = cursor.fetchone()
        if not row:
            abort(500, description="Unexpected: no row from sp_GetDashboardCounts")
        
        data = {
            "RecordLabelCount":   row.RecordLabelCount,
            "EmployeeCount":      row.EmployeeCount,
            "SongCount":          row.SongCount,
            "ContributorCount":   row.ContributorCount,
            "CollaborationCount": row.CollaborationCount
        }
        logger.info(f"Dashboard counts: {data}")
        return jsonify(data), 200
    finally:
        conn.close()
