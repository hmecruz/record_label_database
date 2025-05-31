# backend/endpoints/collaborations.py

from flask import Blueprint, request, jsonify, abort
from config.database_config import DatabaseConfig
import pyodbc

collab_api = Blueprint(
    'collab_api',
    __name__,
    url_prefix='/api/collaborations'
)

def map_row_to_collab(row):
    """
    Map a row from vw_Collaborations into a JSON-serializable dict.
    Splits the comma-separated RecordLabels/Contributors into Python lists.
    """
    # pull the correct columns from your view
    raw_labels  = getattr(row, 'RecordLabels', '') or ''
    raw_contrib = getattr(row, 'Contributors', '')   or ''

    labels = [lbl.strip() for lbl in raw_labels.split(',')  if lbl.strip()]
    contribs = [c.strip() for c in raw_contrib.split(',') if c.strip()]

    return {
        "CollaborationID":   row.CollaborationID,
        "CollaborationName": row.CollaborationName,
        "StartDate":         row.StartDate.isoformat() if row.StartDate else None,
        "EndDate":           row.EndDate.isoformat()   if row.EndDate   else None,
        "Description":       row.Description,
        "SongID":            row.SongID,
        "SongTitle":         row.SongTitle,
        "RecordLabels":      labels,
        "Contributors":      contribs
    }

@collab_api.route('', methods=['GET'])
def list_collaborations():
    # read optional filters
    name        = request.args.get('name')
    start       = request.args.get('start')
    end         = request.args.get('end')
    song        = request.args.get('song')
    label       = request.args.get('labels')
    contributor = request.args.get('contributors')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetCollaborations "
            "@Name=?, @Start=?, @End=?, @Song=?, @Label=?, @Contributor=?",
            name, start, end, song, label, contributor
        )
        rows = cursor.fetchall()
        results = [map_row_to_collab(r) for r in rows]
        return jsonify(results), 200
    finally:
        conn.close()

@collab_api.route('/<int:cid>', methods=['GET'])
def get_collaboration(cid):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetCollaborationByID @ID=?",
            cid
        )
        row = cursor.fetchone()
        if not row:
            abort(404, description=f"Collaboration with ID {cid} not found")
        return jsonify(map_row_to_collab(row)), 200
    finally:
        conn.close()

@collab_api.route('', methods=['POST'])
def create_collaboration():
    data = request.get_json() or {}
    if not data.get("CollaborationName") or not data.get("StartDate"):
        abort(400, description="Fields 'CollaborationName' and 'StartDate' are required")

    name       = data["CollaborationName"]
    start      = data["StartDate"]
    end        = data.get("EndDate")
    desc       = data.get("Description")
    song_title = data.get("SongTitle")
    labels     = data.get("RecordLabels")   # comma-separated string
    contribs   = data.get("Contributors")   # comma-separated string

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        result = cursor.execute(
            "DECLARE @NewID INT; "
            "EXEC dbo.sp_CreateCollaboration "
            "@CollaborationName=?, @StartDate=?, @EndDate=?, @Description=?, "
            "@SongTitle=?, @RecordLabels=?, @Contributors=?, @NewID=@NewID OUTPUT; "
            "SELECT @NewID AS NewID;",
            name, start, end, desc, song_title, labels, contribs
        )
        new_id = result.fetchone().NewID
        conn.commit()
    except pyodbc.Error as e:
        conn.rollback()
        abort(500, description=str(e))
    finally:
        conn.close()

    return get_collaboration(new_id)

@collab_api.route('/<int:cid>', methods=['PUT'])
def update_collaboration(cid):
    data = request.get_json() or {}
    if not data.get("CollaborationName") or not data.get("StartDate"):
        abort(400, description="Fields 'CollaborationName' and 'StartDate' are required")

    name       = data["CollaborationName"]
    start      = data["StartDate"]
    end        = data.get("EndDate")
    desc       = data.get("Description")
    song_title = data.get("SongTitle")
    labels     = data.get("RecordLabels")
    contribs   = data.get("Contributors")

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_UpdateCollaboration "
                "@ID=?, @CollaborationName=?, @StartDate=?, @EndDate=?, @Description=?, "
                "@SongTitle=?, @RecordLabels=?, @Contributors=?",
                cid, name, start, end, desc, song_title, labels, contribs
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
            # your SP throws 50030 if not found
            if '50030' in str(pe):
                abort(404, description=f"Collaboration with ID {cid} not found")
            raise
    finally:
        conn.close()

    return get_collaboration(cid)

@collab_api.route('/<int:cid>', methods=['DELETE'])
def delete_collaboration(cid):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_DeleteCollaboration @ID=?",
                cid
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
            # your SP throws 50031 if not found
            if '50031' in str(pe):
                abort(404, description=f"Collaboration with ID {cid} not found")
            raise
        return '', 204
    finally:
        conn.close()
