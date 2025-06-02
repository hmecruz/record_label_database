from flask import Blueprint, request, jsonify, abort
from config.database_config import DatabaseConfig
import pyodbc
from config.logger import get_logger

logger = get_logger(__name__)

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

    # 1) Overwrite existing Person first, if requested
    if overwrite_person:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                EXEC dbo.sp_UpdatePerson
                  @NIF=?, @Name=?, @DateOfBirth=?, @Email=?, @PhoneNumber=?
                """,
                nif, name, dob, email, phone
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
            conn.rollback()
            if '51010' in str(pe):
                abort(404, description=f"Person with NIF {nif} not found")
            raise
        finally:
            conn.close()

        # now treat as "use old person"
        use_old_person = True

    # 2) If useOldPerson=true, skip sp_CreateContributor and call sp_AddContributorFromExistingPerson
    if use_old_person:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            result = cursor.execute(
                """
                DECLARE @NewCID INT;
                EXEC dbo.sp_AddContributorFromExistingPerson
                  @NIF=?, @Roles=?, @NewID=@NewCID OUTPUT;
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
            abort(404, description=f"Cannot add Contributor for NIF {nif}: {pe}")
        finally:
            conn.close()

        if not row or row.ContributorID is None:
            abort(500, description="Unexpected error: no ContributorID returned.")
        return get_contributor(row.ContributorID)

    # 3) Normal path: call sp_CreateContributor
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

    new_id      = row.NewID         # may be NULL if conflict
    person_nif  = row.PersonNIF
    existing    = bool(row.Existing)
    conflict    = bool(row.Conflict)

    # 3a) Conflict → return 409 + JSON
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

    # 3b) Person existed & no new Contributor inserted → insert via sp_AddContributorFromExistingPerson
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

    # 3c) Otherwise, new_id must be non‐NULL
    if new_id is None:
        abort(500, description="Unexpected internal error: ContributorID is null.")
    return get_contributor(new_id)


@contributors_api.route('/<int:contrib_id>/dependencies', methods=['GET'])
def get_contributor_dependencies(contrib_id):
    """
    GET /api/contributors/{id}/dependencies
    Returns JSON with { CollaborationCount, SongCount } for this contributor.
    """
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetContributorDependencies @ContributorID = ?",
            contrib_id
        )
        row = cursor.fetchone()
        if not row:
            # If procedure returned no rows, assume no dependencies
            return jsonify({"CollaborationCount": 0, "SongCount": 0}), 200

        return jsonify({
            "CollaborationCount": row.CollaborationCount,
            "SongCount":          row.SongCount
        }), 200

    except pyodbc.ProgrammingError as pe:
        # If the stored proc threw “Contributor not found,” respond 404
        if "50020" in str(pe):
            abort(404, description=f"Contributor with ID {contrib_id} not found")
        logger.exception(f"Error fetching dependencies for contributor {contrib_id}")
        abort(500, description="Failed to fetch dependencies")
    finally:
        conn.close()


@contributors_api.route('/<int:contrib_id>', methods=['PUT'])
def update_contributor(contrib_id):
    data = request.get_json() or {}
    logger.debug(f"update_contributor called for ID={contrib_id} with data={data}")

    if not data.get('NIF'):
        logger.warning("update_contributor missing 'NIF'")
        abort(400, description="Field 'NIF' is required")
    if not data.get('Name'):
        abort(400, description="Field 'Name' is required")
    if not data.get('Roles'):
        abort(400, description="Field 'Roles' is required")

    nif   = data['NIF'].strip()
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
               "@ID=?, @NewNIF=?, @Name=?, @DateOfBirth=?, @Email=?, @PhoneNumber=?, @Roles=?",
               contrib_id, nif, name, dob, email, phone, roles
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
            if 'Contributor not found' in str(pe):
                logger.info(f"update_contributor: Contributor ID={contrib_id} not found")
                abort(404, description=f"Contributor with ID {contrib_id} not found")
            logger.exception(f"ProgrammingError in sp_UpdateContributor ID={contrib_id}")
            raise
    except pyodbc.Error as e:
        logger.exception(f"Database error updating Contributor ID={contrib_id}")
        abort(500, description="Internal error while updating contributor.")
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
            if 'Contributor not found' in str(pe) or '50020' in str(pe):
                abort(404, description=f"Contributor with ID {contrib_id} not found")
            raise
        return '', 204
    finally:
        conn.close()
