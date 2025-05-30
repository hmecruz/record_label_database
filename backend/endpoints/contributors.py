from flask import Blueprint, request, jsonify, abort
from config.database_config import DatabaseConfig
import pyodbc

contributors_api = Blueprint(
    'contributors_api',
    __name__,
    url_prefix='/api/contributors'
)

def map_row_to_contributor(row):
    """
    Convert a row from vw_Contributors into a JSON-serializable dict.
    Columns: ContributorID, NIF, Name, DateOfBirth, Email, PhoneNumber, Roles
    """
    return {
        "ContributorID": row.ContributorID,
        "NIF":           row.NIF,
        "Name":          row.Name,
        "DateOfBirth":   row.DateOfBirth.isoformat() if row.DateOfBirth else None,
        "Email":         row.Email,
        "PhoneNumber":   row.PhoneNumber,
        "Roles":         row.Roles or ""
    }

@contributors_api.route('', methods=['GET'])
def list_contributors():
    name  = request.args.get('name')
    role  = request.args.get('role')
    email = request.args.get('email')
    phone = request.args.get('phone')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetContributors "
            "@Name=?, @Role=?, @Email=?, @Phone=?",
            name, role, email, phone
        )
        rows = cursor.fetchall()
        results = [map_row_to_contributor(r) for r in rows]
        return jsonify(results), 200
    finally:
        conn.close()

@contributors_api.route('/<int:contrib_id>', methods=['GET'])
def get_contributor(contrib_id):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetContributorByID @ID=?",
            contrib_id
        )
        row = cursor.fetchone()
        if not row:
            abort(404, description=f"Contributor with ID {contrib_id} not found")
        return jsonify(map_row_to_contributor(row)), 200
    finally:
        conn.close()

@contributors_api.route('', methods=['POST'])
def create_contributor():
    data = request.get_json() or {}
    if not data.get('Name'):
        abort(400, description="Field 'Name' is required")

    name        = data['Name']
    dob         = data.get('DateOfBirth')
    email       = data.get('Email')
    phone       = data.get('PhoneNumber')
    roles       = data.get('Roles')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        # call create proc, capture new ID
        result = cursor.execute(
            "DECLARE @NewID INT; "
            "EXEC dbo.sp_CreateContributor "
            "@Name=?, @DateOfBirth=?, @Email=?, @PhoneNumber=?, @Roles=?, @NewID=@NewID OUTPUT; "
            "SELECT @NewID AS NewID;",
            name, dob, email, phone, roles
        )
        new_id = result.fetchone().NewID
        conn.commit()
    except pyodbc.IntegrityError as e:
        conn.rollback()
        abort(400, description=str(e))
    finally:
        conn.close()

    return get_contributor(new_id)

@contributors_api.route('/<int:contrib_id>', methods=['PUT'])
def update_contributor(contrib_id):
    data = request.get_json() or {}
    if not data.get('Name'):
        abort(400, description="Field 'Name' is required")

    name        = data['Name']
    dob         = data.get('DateOfBirth')
    email       = data.get('Email')
    phone       = data.get('PhoneNumber')
    roles       = data.get('Roles')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_UpdateContributor "
                "@ID=?, @Name=?, @DateOfBirth=?, @Email=?, @PhoneNumber=?, @Roles=?",
                contrib_id, name, dob, email, phone, roles
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
            # RAISERROR('Contributor not found',...) produces ProgrammingError
            if 'Contributor not found' in str(pe):
                abort(404, description=f"Contributor with ID {contrib_id} not found")
            raise
    finally:
        conn.close()

    return get_contributor(contrib_id)

@contributors_api.route('/<int:contrib_id>', methods=['DELETE'])
def delete_contributor(contrib_id):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_DeleteContributor @ID=?",
                contrib_id
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
            if 'Contributor not found' in str(pe):
                abort(404, description=f"Contributor with ID {contrib_id} not found")
            raise
        return '', 204
    finally:
        conn.close()
