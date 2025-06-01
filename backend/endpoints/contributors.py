# backend/endpoints/contributors.py

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
    Convert a row from vw_Contributors into a JSON‐serializable dict.
    Columns: ContributorID, NIF, Name, DateOfBirth, Email, PhoneNumber, RecordLabelName, Roles
    """
    return {
        "ContributorID":   row.ContributorID,
        "NIF":             row.NIF,
        "Name":            row.Name,
        "DateOfBirth":     row.DateOfBirth.isoformat() if row.DateOfBirth else None,
        "Email":           row.Email,
        "PhoneNumber":     row.PhoneNumber,
        "RecordLabelName": row.RecordLabelName or "",
        "Roles":           row.Roles or ""
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
        return jsonify([map_row_to_contributor(r) for r in rows]), 200
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
    """
    Three modes:
      1) Normal (no query flags): call sp_CreateContributor; if Conflict=1 → return 409+JSON.
      2) useOldPerson=true: call sp_AddContributorFromExistingPerson on the existing NIF.
      3) overwritePerson=true: update Person first, then call sp_AddContributorFromExistingPerson.
    """
    data = request.get_json() or {}

    # Basic validation
    if not data.get('NIF'):
        abort(400, description="Field 'NIF' is required")
    if not data.get('Name'):
        abort(400, description="Field 'Name' is required")
    if not data.get('Roles'):
        abort(400, description="Field 'Roles' is required")

    nif   = data['NIF'].strip()
    name  = data['Name'].strip()
    dob   = data.get('DateOfBirth')
    email = data.get('Email')
    phone = data.get('PhoneNumber')
    roles = data.get('Roles')

    use_old_person     = request.args.get('useOldPerson', '').lower() == 'true'
    overwrite_person   = request.args.get('overwritePerson', '').lower() == 'true'

    # 1) If overwritePerson=true, first update the Person row to the new fields:
    if overwrite_person:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            # We assume Person with that NIF exists. If not, this will affect 0 rows.
            cursor.execute(
                """
                UPDATE dbo.Person
                SET Name = ?, DateOfBirth = ?, Email = ?, PhoneNumber = ?
                WHERE NIF = ?
                """,
                name, dob, email, phone, nif
            )
            if cursor.rowcount == 0:
                # If no Person row was updated, abort with 404.
                abort(404, description=f"No Person found with NIF {nif} to overwrite.")
            conn.commit()
        except pyodbc.Error as e:
            conn.rollback()
            abort(500, description="Failed to overwrite Person: " + str(e))
        finally:
            conn.close()

        # Now that Person is updated, we fall through to "useOldPerson" behavior:
        use_old_person = True

    # 2) If useOldPerson=true, skip sp_CreateContributor entirely and call sp_AddContributorFromExistingPerson:
    if use_old_person:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            result = cursor.execute(
                """
                DECLARE @NewCID INT;
                EXEC dbo.sp_AddContributorFromExistingPerson
                  @NIF = ?,
                  @Roles = ?,
                  @NewID = @NewCID OUTPUT;
                SELECT @NewCID AS ContributorID;
                """,
                nif, roles
            )
            row = result.fetchone()
            conn.commit()
        except pyodbc.IntegrityError as e:
            conn.rollback()
            abort(400, description="Failed to add Contributor under existing Person: " + str(e))
        except pyodbc.ProgrammingError as pe:
            conn.rollback()
            # Possible “Person not found” or FK issue:
            abort(404, description="Cannot add Contributor for NIF " + nif + ": " + str(pe))
        finally:
            conn.close()

        if not row or row.ContributorID is None:
            abort(500, description="Unexpected error: no ContributorID returned.")
        return get_contributor(row.ContributorID)

    # 3) Normal path: call sp_CreateContributor and check for conflict
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        result = cursor.execute(
            """
            DECLARE @NewID       INT;
            DECLARE @OutPersonNIF VARCHAR(20);
            DECLARE @OutExisting  BIT;
            DECLARE @OutConflict  BIT;

            EXEC dbo.sp_CreateContributor
                @NIF           = ?,
                @Name          = ?,
                @DateOfBirth   = ?,
                @Email         = ?,
                @PhoneNumber   = ?,
                @Roles         = ?,
                @ContributorID = @NewID OUTPUT,
                @PersonNIF     = @OutPersonNIF OUTPUT,
                @Existing      = @OutExisting OUTPUT,
                @Conflict      = @OutConflict OUTPUT;

            SELECT 
              @NewID        AS NewID,
              @OutPersonNIF AS PersonNIF,
              @OutExisting  AS Existing,
              @OutConflict  AS Conflict;
            """,
            nif, name, dob, email, phone, roles
        )
        row = result.fetchone()
        conn.commit()
    except pyodbc.IntegrityError as e:
        conn.rollback()
        abort(400, description=str(e))
    finally:
        conn.close()

    # Unpack SP outputs:
    new_id      = row.NewID         # may be NULL if conflict
    person_nif  = row.PersonNIF
    existing    = bool(row.Existing)
    conflict    = bool(row.Conflict)

    # 3a) If conflict=1, return HTTP 409 + JSON describing existing Person vs incoming data
    if conflict:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                "EXEC dbo.sp_GetPersonByNIF @NIF = ?",
                person_nif
            )
            p = cursor.fetchone()
            if not p:
                abort(500, description="Person unexpectedly not found after conflict.")
            existing_person = {
                "NIF":          p.NIF,
                "Name":         p.Name,
                "DateOfBirth":  p.DateOfBirth.isoformat() if p.DateOfBirth else None,
                "Email":        p.Email,
                "PhoneNumber":  p.PhoneNumber,
                "ContributorID": p.ContributorID  # may be NULL
            }
        finally:
            conn.close()

        incoming_data = {
            "NIF":          nif,
            "Name":         name,
            "DateOfBirth":  dob,
            "Email":        email,
            "PhoneNumber":  phone,
            "Roles":        roles
        }

        return (
            jsonify({
              "message": "Person with that NIF already exists but fields differ.",
              "existingPerson": existing_person,
              "incomingData": incoming_data
            }),
            409
        )

    # 3b) If existing=1 and new_id is NULL → no conflict and Person existed, but SP_CreateContributor did NOT auto‐insert a Contributor row.
    # In that case, SP must have matched “fields exactly.” We now insert the Contributor via sp_AddContributorFromExistingPerson.
    if existing and (new_id is None):
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            result2 = cursor.execute(
                """
                DECLARE @NewCID INT;
                EXEC dbo.sp_AddContributorFromExistingPerson
                  @NIF = ?,
                  @Roles = ?,
                  @NewID = @NewCID OUTPUT;
                SELECT @NewCID AS ContributorID;
                """,
                person_nif, roles
            )
            row2 = result2.fetchone()
            conn.commit()
        except pyodbc.Error as e:
            conn.rollback()
            abort(500, description="Failed to add Contributor for existing Person: " + str(e))
        finally:
            conn.close()

        if not row2 or row2.ContributorID is None:
            abort(500, description="Unexpected error: no ContributorID returned on add‐existing path.")
        return get_contributor(row2.ContributorID)

    # 3c) Otherwise, new_id must be non‐NULL (either we just created Person+Contributor, or Person was already Contributor).
    if new_id is None:
        # Defensive check—should not happen
        abort(500, description="Unexpected internal error: ContributorID is null.")
    return get_contributor(new_id)


@contributors_api.route('/<int:contrib_id>', methods=['PUT'])
def update_contributor(contrib_id):
    data = request.get_json() or {}
    if not data.get('NIF'):
        abort(400, description="Field 'NIF' is required")
    if not data.get('Name'):
        abort(400, description="Field 'Name' is required")
    if not data.get('Roles'):
        abort(400, description="Field 'Roles' is required")

    # We do not change NIF here—NIF identifies the Person. Just update Person + Roles.
    name  = data['Name']
    dob   = data.get('DateOfBirth')
    email = data.get('Email')
    phone = data.get('PhoneNumber')
    roles = data.get('Roles')

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