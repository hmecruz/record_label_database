# backend/endpoints/contributors.py

from flask import Blueprint, request, jsonify, abort, make_response
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
    Columns: ContributorID, NIF, Name, DateOfBirth, Email, PhoneNumber, RecordLabelName, Roles
    """
    return {
        "ContributorID":    row.ContributorID,
        "NIF":              row.NIF,
        "Name":             row.Name,
        "DateOfBirth":      row.DateOfBirth.isoformat() if row.DateOfBirth else None,
        "Email":            row.Email,
        "PhoneNumber":      row.PhoneNumber,
        "RecordLabelName":  row.RecordLabelName or "",
        "Roles":            row.Roles or ""
    }

def map_row_to_person(row):
    """
    Convert a row from sp_GetPersonByNIF (Person p + optional ContributorID) into a dict.
    Columns returned: NIF, Name, DateOfBirth, Email, PhoneNumber, ContributorID
    """
    return {
        "NIF":           row.NIF,
        "Name":          row.Name,
        "DateOfBirth":   row.DateOfBirth.isoformat() if row.DateOfBirth else None,
        "Email":         row.Email,
        "PhoneNumber":   row.PhoneNumber,
        "ContributorID": row.ContributorID  # may be None
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
    # Required fields
    if not data.get('Name'):
        abort(400, description="Field 'Name' is required")
    if not data.get('NIF'):
        abort(400, description="Field 'NIF' is required")
    if not data.get('Roles'):
        abort(400, description="Field 'Roles' is required")

    nif     = data['NIF']
    name    = data['Name']
    dob     = data.get('DateOfBirth')
    email   = data.get('Email')
    phone   = data.get('PhoneNumber')
    roles   = data.get('Roles')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        # First, see if that NIF already exists in Person via sp_GetPersonByNIF
        cursor.execute(
            "EXEC dbo.sp_GetPersonByNIF @NIF=?",
            nif
        )
        existing_person = cursor.fetchone()
        if existing_person:
            # If that Person is already a Contributor (ContributorID not NULL),
            # or if the user-supplied fields differ, return 409 with both sets of data.
            person_info = map_row_to_person(existing_person)

            # If that Person is already a Contributor:
            if person_info.get("ContributorID") is not None:
                # Already a contributor → conflict: “Contributor already exists”
                return make_response(
                    jsonify({
                        "message": "A contributor with that NIF already exists.",
                        "existingPerson": person_info,
                        "attempted": {
                            "NIF": nif,
                            "Name": name,
                            "DateOfBirth": dob,
                            "Email": email,
                            "PhoneNumber": phone,
                            "Roles": roles
                        }
                    }),
                    409
                )

            # Otherwise, Person exists (likely as an Employee), but not yet a Contributor.
            # Compare the existing Person’s data against what the user submitted:
            diffs = {}
            if person_info["Name"] != name:
                diffs["Name"] = {"existing": person_info["Name"], "attempted": name}
            if person_info["DateOfBirth"] != dob:
                diffs["DateOfBirth"] = {
                    "existing": person_info["DateOfBirth"],
                    "attempted": dob
                }
            if person_info["Email"] != email:
                diffs["Email"] = {"existing": person_info["Email"], "attempted": email}
            if person_info["PhoneNumber"] != phone:
                diffs["PhoneNumber"] = {
                    "existing": person_info["PhoneNumber"],
                    "attempted": phone
                }

            if diffs:
                # Conflict because the user’s fields differ from the existing Employee.
                return make_response(
                    jsonify({
                        "message": "A Person with that NIF already exists (as an Employee). "
                                   "Some fields differ—would you like to overwrite?",
                        "existingPerson": person_info,
                        "attempted": {
                            "NIF": nif,
                            "Name": name,
                            "DateOfBirth": dob,
                            "Email": email,
                            "PhoneNumber": phone,
                            "Roles": roles
                        },
                        "differences": diffs
                    }),
                    409
                )
            # If no diffs, the Person is the same—fall through to create Contributor below,
            # reusing the exact same Person record.
        end_if = None  # (only for indent clarity)

        # No conflict: either Person did not exist, or existed with identical fields.
        # Proceed to call sp_CreateContributor, which will insert Person if needed,
        # or create a Contributor row under the existing Person’s NIF.

        # We need to capture both ContributorID and @Existing flag.
        result = cursor.execute(
            """
            DECLARE @NewID INT;
            DECLARE @outPersonNIF VARCHAR(20);
            DECLARE @outExisting BIT;

            EXEC dbo.sp_CreateContributor
                @NIF=?,
                @Name=?, @DateOfBirth=?, @Email=?, @PhoneNumber=?, @Roles=?,
                @ContributorID=@NewID OUTPUT,
                @PersonNIF=@outPersonNIF OUTPUT,
                @Existing=@outExisting OUTPUT;

            SELECT @NewID AS NewID, @outPersonNIF AS PersonNIF, @outExisting AS Existing;
            """,
            nif, name, dob, email, phone, roles
        )
        row = result.fetchone()
        new_id    = row.NewID
        outExist  = row.Existing
        # outPersonNIF = row.PersonNIF  # not used beyond that

        conn.commit()

    except pyodbc.IntegrityError as e:
        conn.rollback()
        abort(400, description=str(e))
    finally:
        conn.close()

    # If sp_CreateContributor returned Existing=1 but we’d not hit the earlier 409,
    # it means a Person existed with IDENTICAL fields, and we just created a Contributor row.
    # We now return the freshly created contributor.
    return get_contributor(new_id)

@contributors_api.route('/<int:contrib_id>', methods=['PUT'])
def update_contributor(contrib_id):
    data = request.get_json() or {}
    if not data.get('Name'):
        abort(400, description="Field 'Name' is required")
    if not data.get('NIF'):
        abort(400, description="Field 'NIF' is required")
    if not data.get('Roles'):
        abort(400, description="Field 'Roles' is required")

    nif     = data['NIF']
    name    = data['Name']
    dob     = data.get('DateOfBirth')
    email   = data.get('Email')
    phone   = data.get('PhoneNumber')
    roles   = data.get('Roles')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()

        # If the frontend detected a NIF mismatch (i.e. the user confirmed “overwrite”),
        # it should have already called sp_UpdatePerson on that NIF first.  Here we only
        # update roles & Person fields under the assumption that NIF was already correct.
        try:
            cursor.execute(
                "EXEC dbo.sp_UpdateContributor "
                "@ID=?, @Name=?, @DateOfBirth=?, @Email=?, @PhoneNumber=?, @Roles=?",
                contrib_id, name, dob, email, phone, roles
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
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
