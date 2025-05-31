# backend/endpoints/record_label_endpoints.py

from flask import Blueprint, request, jsonify, abort
from config.database_config import DatabaseConfig
import pyodbc

record_label_api = Blueprint(
    'record_label_api',
    __name__,
    url_prefix='/api/record_labels'
)

def map_row_to_label(row):
    """
    Helper to convert a cursor row into our JSON dict.
    Assumes the SELECT * from vw_RecordLabels returns columns in this order:
      RecordLabelID, Name, Location, Website, Email, PhoneNumber
    """
    return {
        "RecordLabelID": row.RecordLabelID,
        "Name":          row.Name,
        "Location":      row.Location,
        "Website":       row.Website,
        "Email":         row.Email,
        "PhoneNumber":   row.PhoneNumber
    }

@record_label_api.route('', methods=['GET'])
def list_record_labels():
    # read optional filters
    name     = request.args.get('name')
    location = request.args.get('location')
    website  = request.args.get('website')
    email    = request.args.get('email')
    phone    = request.args.get('phone')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetRecordLabels "
            "@Name=?, @Location=?, @Website=?, @Email=?, @Phone=?",
            name, location, website, email, phone
        )
        rows = cursor.fetchall()
        labels = [map_row_to_label(r) for r in rows]
        return jsonify(labels), 200
    finally:
        conn.close()

@record_label_api.route('/<int:label_id>', methods=['GET'])
def get_record_label(label_id):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetRecordLabelByID @ID=?",
            label_id
        )
        row = cursor.fetchone()
        if not row:
            abort(404, description=f"RecordLabel with ID {label_id} not found")
        label = map_row_to_label(row)
        return jsonify(label), 200
    finally:
        conn.close()

@record_label_api.route('', methods=['POST'])
def create_record_label():
    data = request.get_json() or {}
    # Basic validation
    if not data.get("Name") or not data.get("Email"):
        abort(400, description="Fields 'Name' and 'Email' are required")

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        new_id = cursor.execute(
            "DECLARE @NewID INT; "
            "EXEC dbo.sp_CreateRecordLabel "
            "@Name=?, @Location=?, @Website=?, @Email=?, @PhoneNumber=?, "
            "@NewID=@NewID OUTPUT; "
            "SELECT @NewID AS NewID;",
            data.get("Name"),
            data.get("Location"),
            data.get("Website"),
            data.get("Email"),
            data.get("PhoneNumber")
        ).fetchone().NewID

        conn.commit()

        created = {
            "RecordLabelID": new_id,
            "Name":          data.get("Name"),
            "Location":      data.get("Location"),
            "Website":       data.get("Website"),
            "Email":         data.get("Email"),
            "PhoneNumber":   data.get("PhoneNumber")
        }
        return jsonify(created), 201

    except pyodbc.IntegrityError as e:
        # handle unique constraints, etc.
        abort(400, description=str(e))
    finally:
        conn.close()

@record_label_api.route('/<int:label_id>', methods=['PUT'])
def update_record_label(label_id):
    data = request.get_json() or {}
    # Basic validation
    if not data.get("Name") or not data.get("Email"):
        abort(400, description="Fields 'Name' and 'Email' are required")

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        # Call update proc; if it throws, we catch and map
        try:
            cursor.execute(
                "EXEC dbo.sp_UpdateRecordLabel "
                "@ID=?, @Name=?, @Location=?, @Website=?, @Email=?, @PhoneNumber=?",
                label_id,
                data.get("Name"),
                data.get("Location"),
                data.get("Website"),
                data.get("Email"),
                data.get("PhoneNumber")
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
            # SQL THROW errors come through as ProgrammingError
            if "50000" in str(pe):
                abort(404, description=f"RecordLabel with ID {label_id} not found")
            raise

        updated = {
            "RecordLabelID": label_id,
            "Name":          data.get("Name"),
            "Location":      data.get("Location"),
            "Website":       data.get("Website"),
            "Email":         data.get("Email"),
            "PhoneNumber":   data.get("PhoneNumber")
        }
        return jsonify(updated), 200

    finally:
        conn.close()

@record_label_api.route('/<int:label_id>', methods=['DELETE'])
def delete_record_label(label_id):
    """
    DELETE logic with two modes:
      ‣ Strict delete (no ?cascade=true):
          • Call sp_CheckRecordLabelDependencies
          • If employeeCount or collaborationCount > 0 → HTTP 409 with JSON {employeeCount, collaborationCount}
          • Else → CALL sp_DeleteRecordLabel and return 204
      ‣ Cascade delete (if ?cascade=true):
          • CALL sp_DeleteRecordLabel_Cascade and return 204
    """
    cascade_flag = request.args.get('cascade', 'false').lower() == 'true'

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()

        if not cascade_flag:
            # 1) Check dependencies
            #    We expect sp_CheckRecordLabelDependencies to set two OUTPUT parameters:
            #       @EmployeeCount, @CollaborationCount
            result = cursor.execute(
                """
                DECLARE @E INT, @C INT;
                EXEC dbo.sp_CheckRecordLabelDependencies
                    @ID=?, 
                    @EmployeeCount=@E OUTPUT, 
                    @CollaborationCount=@C OUTPUT;
                SELECT @E AS Emp, @C AS Collab;
                """,
                label_id
            ).fetchone()

            # If no row returned, treat as “label not found”
            if result is None:
                abort(404, description=f"RecordLabel with ID {label_id} not found")

            employee_count      = result.Emp
            collaboration_count = result.Collab

            # 2a) If dependencies exist, return 409 + JSON counts
            if (employee_count or collaboration_count):
                return jsonify({
                    "employeeCount": employee_count,
                    "collaborationCount": collaboration_count
                }), 409

            # 2b) Otherwise, strictly delete
            try:
                cursor.execute(
                    "EXEC dbo.sp_DeleteRecordLabel @ID=?",
                    label_id
                )
                conn.commit()
                return '', 204
            except pyodbc.ProgrammingError as pe:
                # If SP threw “50001 → not found”
                if "50001" in str(pe):
                    abort(404, description=f"RecordLabel with ID {label_id} not found")
                raise

        else:
            # 3) cascade=true → delete dependents & delete the label
            try:
                cursor.execute(
                    "EXEC dbo.sp_DeleteRecordLabel_Cascade @ID=?",
                    label_id
                )
                conn.commit()
                return '', 204
            except pyodbc.ProgrammingError as pe:
                # If cascade SP threw “50001 → not found”
                if "50001" in str(pe):
                    abort(404, description=f"RecordLabel with ID {label_id} not found")
                raise

    finally:
        conn.close()
