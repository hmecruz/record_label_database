# backend/endpoints/persons.py

from flask import Blueprint, request, jsonify, abort
from config.database_config import DatabaseConfig
import pyodbc

persons_api = Blueprint(
    'persons_api',
    __name__,
    url_prefix='/api/persons'
)

@persons_api.route('/<string:nif>', methods=['PUT'])
def update_person(nif):
    data = request.get_json() or {}

    # We expect at least one field to update
    name        = data.get('Name')
    dob         = data.get('DateOfBirth')
    email       = data.get('Email')
    phone       = data.get('PhoneNumber')

    if name is None and dob is None and email is None and phone is None:
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
            # If SP threw “51000: Person not found”
            if '51000' in str(pe):
                abort(404, description=f"Person with NIF {nif} not found")
            raise
    finally:
        conn.close()

    # Return the updated Person as JSON
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
            abort(404, description=f"Person with NIF {nif} not found")
        person = {
            "NIF":         row.NIF,
            "Name":        row.Name,
            "DateOfBirth": row.DateOfBirth.isoformat() if row.DateOfBirth else None,
            "Email":       row.Email,
            "PhoneNumber": row.PhoneNumber
        }
        return jsonify(person), 200
    finally:
        conn.close()