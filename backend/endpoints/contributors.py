# backend/endpoints/contributors.py

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
    Convert a row from vw_Contributors into a JSON-serializable dict.
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

    logger.debug(f"list_contributors called with filters: name={name}, role={role}, email={email}, phone={phone}")
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
    except pyodbc.Error as e:
        logger.exception("Database error in list_contributors")
        abort(500, description="Internal server error while fetching contributors.")
    finally:
        conn.close()

@contributors_api.route('/<int:contrib_id>', methods=['GET'])
def get_contributor(contrib_id):
    logger.debug(f"get_contributor called with ID={contrib_id}")
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetContributorByID @ID=?",
            contrib_id
        )
        row = cursor.fetchone()
        if not row:
            logger.info(f"Contributor with ID {contrib_id} not found in GET")
            abort(404, description=f"Contributor with ID {contrib_id} not found")
        return jsonify(map_row_to_contributor(row)), 200
    except pyodbc.Error as e:
        logger.exception(f"Database error in get_contributor ID={contrib_id}")
        abort(500, description="Internal server error while fetching contributor.")
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
    logger.debug(f"create_contributor payload: {data} | args: {request.args}")

    # Basic validation
    if not data.get('NIF'):
        logger.warning("create_contributor missing 'NIF'")
        abort(400, description="Field 'NIF' is required")
    if not data.get('Name'):
        logger.warning("create_contributor missing 'Name'")
        abort(400, description="Field 'Name' is required")
    if not data.get('Roles'):
        logger.warning("create_contributor missing 'Roles'")
        abort(400, description="Field 'Roles' is required")

    nif   = data['NIF'].strip()
    name  = data['Name'].strip()
    dob   = data.get('DateOfBirth')
    email = data.get('Email')
    phone = data.get('PhoneNumber')
    roles = data.get('Roles')

    # query flags
    use_old_person   = request.args.get('useOldPerson', '').lower() == 'true'
    overwrite_person = request.args.get('overwritePerson', '').lower() == 'true'

    # 1) If overwritePerson=true, first update the Person row to the new fields:
    if overwrite_person:
        logger.debug(f"overwrite_person=True: updating Person {nif} first")
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                UPDATE dbo.Person
                SET Name = ?, DateOfBirth = ?, Email = ?, PhoneNumber = ?
                WHERE NIF = ?
                """,
                name, dob, email, phone, nif
            )
            if cursor.rowcount == 0:
                logger.info(f"No Person found with NIF {nif} to overwrite")
                abort(404, description=f"No Person found with NIF {nif} to overwrite.")
            conn.commit()
        except pyodbc.Error as e:
            logger.exception(f"Failed to overwrite Person {nif}")
            conn.rollback()
            abort(500, description="Failed to overwrite Person.")
        finally:
            conn.close()

        # Now that Person is updated, we fall through to “useOldPerson” behavior
        use_old_person = True

    # 2) If useOldPerson=true, skip sp_CreateContributor and call sp_AddContributorFromExistingPerson
    if use_old_person:
        logger.debug(f"use_old_person=True: adding contributor from existing Person {nif}")
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
        except pyodbc.IntegrityError as ie:
            logger.warning(f"IntegrityError adding contributor from existing Person {nif}: {ie}")
            conn.rollback()
            abort(400, description="Failed to add Contributor under existing Person.")
        except pyodbc.Error as e:
            logger.exception(f"Error adding contributor from existing Person {nif}")
            conn.rollback()
            abort(500, description=f"Cannot add Contributor for Person {nif}.")
        finally:
            conn.close()

        if not row or row.ContributorID is None:
            logger.error(f"No ContributorID returned when adding from existing Person {nif}")
            abort(500, description="Unexpected error: no ContributorID returned.")
        return get_contributor(row.ContributorID)

    # 3) Normal path: call sp_CreateContributor and check for conflict
    logger.debug(f"Normal create path: calling sp_CreateContributor for NIF={nif}")
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
    except pyodbc.IntegrityError as ie:
        logger.warning(f"IntegrityError in sp_CreateContributor for NIF={nif}: {ie}")
        conn.rollback()
        abort(400, description=str(ie))
    except pyodbc.Error as e:
        logger.exception(f"Database error in sp_CreateContributor for NIF={nif}")
        conn.rollback()
        abort(500, description="Internal error while creating contributor.")
    finally:
        conn.close()

    new_id     = row.NewID         # may be NULL if conflict
    person_nif = row.PersonNIF
    existing   = bool(row.Existing)
    conflict   = bool(row.Conflict)

    # 3a) If conflict = 1, return HTTP 409 + JSON describing mismatch
    if conflict:
        logger.info(f"Conflict detected for NIF {person_nif} (incoming vs existing Person).")
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                "EXEC dbo.sp_GetPersonByNIF @NIF = ?",
                person_nif
            )
            p = cursor.fetchone()
            if not p:
                logger.error(f"Person unexpectedly not found ({person_nif}) after conflict")
                abort(500, description="Person unexpectedly not found after conflict.")
            existing_person = {
                "NIF":          p.NIF,
                "Name":         p.Name,
                "DateOfBirth":  p.DateOfBirth.isoformat() if p.DateOfBirth else None,
                "Email":        p.Email,
                "PhoneNumber":  p.PhoneNumber,
                "ContributorID": p.ContributorID  # may be NULL
            }
        except pyodbc.Error as e:
            logger.exception(f"Error fetching Person {person_nif} after conflict")
            abort(500, description="Internal error retrieving existing Person.")
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

    # 3b) If existing=1 and new_id is NULL → Person existed, fields matched, but the SP did not create Contributor row.
    if existing and (new_id is None):
        logger.debug(f"Existing Person {person_nif} matched exactly; adding Contributor now.")
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
            logger.exception(f"Failed to add Contributor for existing Person {person_nif}")
            conn.rollback()
            abort(500, description="Failed to add Contributor for existing Person.")
        finally:
            conn.close()

        if not row2 or row2.ContributorID is None:
            logger.error(f"No ContributorID returned on add‐existing path for Person {person_nif}")
            abort(500, description="Unexpected error: no ContributorID returned on add‐existing path.")
        return get_contributor(row2.ContributorID)

    # 3c) Otherwise, new_id must be non‐NULL (Person+Contributor just created, or Person was already Contributor).
    if new_id is None:
        logger.error("sp_CreateContributor returned NULL ContributorID without conflict/exists")
        abort(500, description="Unexpected internal error: ContributorID is null.")
    logger.debug(f"Successfully created new Contributor ID={new_id}")
    return get_contributor(new_id)


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
    logger.debug(f"delete_contributor called for ID={contrib_id}")
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
                logger.info(f"delete_contributor: Contributor ID={contrib_id} not found")
                abort(404, description=f"Contributor with ID {contrib_id} not found")
            logger.exception(f"ProgrammingError in sp_DeleteContributor ID={contrib_id}")
            raise
        return '', 204
    except pyodbc.Error as e:
        logger.exception(f"Database error deleting Contributor ID={contrib_id}")
        abort(500, description="Internal error while deleting contributor.")
    finally:
        conn.close()
