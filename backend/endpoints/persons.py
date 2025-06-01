# backend/endpoints/persons.py

from flask import Blueprint, request, jsonify, abort
from config.database_config import DatabaseConfig
import pyodbc

from config.logger import get_logger
logger = get_logger(__name__)

persons_api = Blueprint(
    'persons_api',
    __name__,
    url_prefix='/api/persons'
)

@persons_api.route('/<string:nif>', methods=['PUT'])
def update_person(nif):
    """
    Updates Person fields (Name, DateOfBirth, Email, PhoneNumber) for an existing NIF.
    """
    data = request.get_json() or {}
    logger.debug(f"update_person called for NIF={nif} with data={data}")

    name  = data.get('Name')
    dob   = data.get('DateOfBirth')
    email = data.get('Email')
    phone = data.get('PhoneNumber')

    # Require at least one field to update
    if name is None and dob is None and email is None and phone is None:
        logger.warning("update_person: no fields provided to update for NIF={}".format(nif))
        abort(400, description="At least one of Name, DateOfBirth, Email, or PhoneNumber must be provided")

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_UpdatePerson "
                "@NIF=?, @Name=?, @DateOfBirth=?, @Email=?, @PhoneNumber=?",
                nif, name, dob, email, phone
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
            # Check for the “51010: Person not found” that our SP throws
            if '51010' in str(pe):
                logger.info(f"update_person: Person NIF={nif} not found")
                abort(404, description=f"Person with NIF {nif} not found")
            logger.exception(f"ProgrammingError in sp_UpdatePerson for NIF={nif}: {pe}")
            raise
    except pyodbc.Error as e:
        logger.exception(f"Database error updating Person NIF={nif}")
        abort(500, description="Internal error while updating Person.")
    finally:
        conn.close()

    # Return the updated Person
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT NIF, Name, DateOfBirth, Email, PhoneNumber "
            "FROM dbo.Person WHERE NIF = ?",
            nif
        )
        row = cursor.fetchone()
        if not row:
            logger.error(f"update_person: Person NIF={nif} disappeared after update")
            abort(404, description=f"Person with NIF {nif} not found after update")
        person = {
            "NIF":         row.NIF,
            "Name":        row.Name,
            "DateOfBirth": row.DateOfBirth.isoformat() if row.DateOfBirth else None,
            "Email":       row.Email,
            "PhoneNumber": row.PhoneNumber
        }
        return jsonify(person), 200
    except pyodbc.Error as e:
        logger.exception(f"Database error reading Person NIF={nif} after update")
        abort(500, description="Internal error fetching updated Person.")
    finally:
        conn.close()
