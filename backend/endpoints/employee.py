# backend/endpoints/employees.py

from flask import Blueprint, request, jsonify, abort
from config.database_config import DatabaseConfig
import pyodbc
from config.logger import get_logger

logger = get_logger(__name__)

employee_api = Blueprint(
    'employee_api',
    __name__,
    url_prefix='/api/employees'
)

def map_row_to_employee(row):
    """
    Convert a row from vw_Employees into a JSON‐serializable dict.
    Order: EmployeeID, NIF, Name, DateOfBirth, JobTitle, Department,
           Salary, HireDate, Email, PhoneNumber, RecordLabelID, RecordLabelName
    """
    return {
        "EmployeeID":      row.EmployeeID,
        "NIF":             row.NIF,
        "Name":            row.Name,
        "DateOfBirth":     row.DateOfBirth.isoformat() if row.DateOfBirth else None,
        "JobTitle":        row.JobTitle,
        "Department":      row.Department,
        "Salary":          float(row.Salary),
        "HireDate":        row.HireDate.isoformat() if row.HireDate else None,
        "Email":           row.Email,
        "PhoneNumber":     row.PhoneNumber,
        "RecordLabelID":   row.RecordLabelID,
        "RecordLabelName": row.RecordLabelName or ""
    }

@employee_api.route('', methods=['GET'])
def list_employees():
    nif        = request.args.get('nif')
    name       = request.args.get('name')
    jobtitle   = request.args.get('jobtitle')
    department = request.args.get('department')
    email      = request.args.get('email')
    phone      = request.args.get('phone')
    # (We do not send a “label” filter to the SP; that can be applied client‐side if needed.)

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetEmployees "
            "@NIF=?, @Name=?, @JobTitle=?, @Department=?, @Email=?, @Phone=?",
            nif, name, jobtitle, department, email, phone
        )
        rows = cursor.fetchall()
        employees = [map_row_to_employee(r) for r in rows]
        return jsonify(employees), 200
    finally:
        conn.close()

@employee_api.route('/<int:emp_id>', methods=['GET'])
def get_employee(emp_id):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetEmployeeByID @ID=?",
            emp_id
        )
        row = cursor.fetchone()
        if not row:
            abort(404, description=f"Employee with ID {emp_id} not found")
        emp = map_row_to_employee(row)
        return jsonify(emp), 200
    finally:
        conn.close()

@employee_api.route('', methods=['POST'])
def create_employee():
    data = request.get_json() or {}

    # Basic validation for required fields
    missing = []
    for fld in ['NIF', 'Name', 'JobTitle', 'Salary', 'HireDate', 'RecordLabelID']:
        if not data.get(fld):
            missing.append(fld)
    if missing:
        abort(400, description=f"Missing required fields: {', '.join(missing)}")

    nif        = data['NIF'].strip()
    name       = data['Name'].strip()
    dob        = data.get('DateOfBirth')
    email      = data.get('Email')
    phone      = data.get('PhoneNumber')
    job_title  = data['JobTitle'].strip()
    department = data.get('Department')
    salary     = data['Salary']
    hire_date  = data['HireDate']
    label_id   = data['RecordLabelID']

    use_old_person   = request.args.get('useOldPerson', '').lower() == 'true'
    overwrite_person = request.args.get('overwritePerson', '').lower() == 'true'

    # 1) If overwritePerson=true, first update the Person row to the new fields (name/dob/email/phone)
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
            # SP throws 51010 if no Person found
            if '51010' in str(pe) or 'Person not found' in str(pe):
                abort(404, description=f"Person with NIF {nif} not found")
            # re‐raise for any other error
            raise
        finally:
            conn.close()
        # Now behave as if use_old_person = true
        use_old_person = True

    # 2) If useOldPerson=true, skip sp_CreateEmployee entirely and call sp_AddEmployeeFromExistingPerson
    if use_old_person:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            result = cursor.execute(
                """
                DECLARE @NewEID INT;
                EXEC dbo.sp_AddEmployeeFromExistingPerson
                  @NIF           = ?,
                  @JobTitle      = ?,
                  @Department    = ?,
                  @Salary        = ?,
                  @HireDate      = ?,
                  @RecordLabelID = ?,
                  @NewID         = @NewEID OUTPUT;
                SELECT @NewEID AS EmployeeID;
                """,
                nif, job_title, department, salary, hire_date, label_id
            )
            row = result.fetchone()
            conn.commit()
        except pyodbc.IntegrityError as e:
            conn.rollback()
            abort(400, description="Failed to add Employee under existing Person: " + str(e))
        except pyodbc.ProgrammingError as pe:
            conn.rollback()
            abort(404, description=f"Cannot add Employee for NIF {nif}: {pe}")
        finally:
            conn.close()

        if not row or row.EmployeeID is None:
            abort(500, description="Unexpected error: no EmployeeID returned.")
        return get_employee(row.EmployeeID)

    # 3) Normal path: call sp_CreateEmployee and check for conflict
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        result = cursor.execute(
            """
            DECLARE @NewID       INT;
            DECLARE @OutPersonNIF VARCHAR(20);
            DECLARE @OutExisting  BIT;
            DECLARE @OutConflict  BIT;

            EXEC dbo.sp_CreateEmployee
                @NIF           = ?,
                @Name          = ?,
                @DateOfBirth   = ?,
                @Email         = ?,
                @PhoneNumber   = ?,
                @JobTitle      = ?,
                @Department    = ?,
                @Salary        = ?,
                @HireDate      = ?,
                @RecordLabelID = ?,
                @EmployeeID    = @NewID OUTPUT,
                @PersonNIF     = @OutPersonNIF OUTPUT,
                @Existing      = @OutExisting OUTPUT,
                @Conflict      = @OutConflict OUTPUT;

            SELECT 
              @NewID        AS NewID,
              @OutPersonNIF AS PersonNIF,
              @OutExisting  AS Existing,
              @OutConflict  AS Conflict;
            """,
            nif, name, dob, email, phone,
            job_title, department, salary, hire_date, label_id
        )
        row = result.fetchone()
        conn.commit()
    except pyodbc.IntegrityError as e:
        conn.rollback()
        abort(400, description=str(e))
    finally:
        conn.close()

    new_id     = row.NewID           # may be NULL if conflict
    person_nif = row.PersonNIF
    existing   = bool(row.Existing)
    conflict   = bool(row.Conflict)

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
                # note: EmployeeID is not returned by sp_GetPersonByNIF; 
                # if you want to return existing “EmployeeID” you could issue a separate query.
                "EmployeeID":   None
            }
        finally:
            conn.close()

        incoming_data = {
            "NIF":          nif,
            "Name":         name,
            "DateOfBirth":  dob,
            "Email":        email,
            "PhoneNumber":  phone,
            "JobTitle":     job_title,
            "Department":   department,
            "Salary":       salary,
            "HireDate":     hire_date,
            "RecordLabelID":label_id
        }

        return (
            jsonify({
              "message": "Person with that NIF already exists but fields differ.",
              "existingPerson": existing_person,
              "incomingData": incoming_data
            }),
            409
        )

    # 3b) If existing=1 and new_id is NULL → sp_CreateEmployee matched “fields exactly” 
    #     and did not auto‐insert an Employee row. Now insert via sp_AddEmployeeFromExistingPerson.
    if existing and (new_id is None):
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            result2 = cursor.execute(
                """
                DECLARE @NewEID INT;
                EXEC dbo.sp_AddEmployeeFromExistingPerson
                  @NIF           = ?,
                  @JobTitle      = ?,
                  @Department    = ?,
                  @Salary        = ?,
                  @HireDate      = ?,
                  @RecordLabelID = ?,
                  @NewID         = @NewEID OUTPUT;
                SELECT @NewEID AS EmployeeID;
                """,
                person_nif, job_title, department, salary, hire_date, label_id
            )
            row2 = result2.fetchone()
            conn.commit()
        except pyodbc.Error as e:
            conn.rollback()
            abort(500, description="Failed to add Employee for existing Person: " + str(e))
        finally:
            conn.close()

        if not row2 or row2.EmployeeID is None:
            abort(500, description="Unexpected error: no EmployeeID returned on add‐existing path.")
        return get_employee(row2.EmployeeID)

    # 3c) Otherwise, new_id must be non‐NULL now
    if new_id is None:
        abort(500, description="Unexpected internal error: EmployeeID is null.")
    return get_employee(new_id)


@employee_api.route('/<int:emp_id>/dependencies', methods=['GET'])
def get_employee_dependencies(emp_id):
    """
    GET /api/employees/{id}/dependencies
    Returns JSON with { CollaborationCount, SongCount } for this employee’s Person.
    """
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC dbo.sp_GetEmployeeDependencies @EmployeeID = ?",
            emp_id
        )
        row = cursor.fetchone()
        if not row:
            return jsonify({"CollaborationCount": 0, "SongCount": 0}), 200

        return jsonify({
            "CollaborationCount": row.CollaborationCount,
            "SongCount":          row.SongCount
        }), 200

    except pyodbc.ProgrammingError as pe:
        # If the stored proc threw “Employee not found,” respond 404
        if "50030" in str(pe) or "Employee not found" in str(pe):
            abort(404, description=f"Employee with ID {emp_id} not found")
        logger.exception(f"Error fetching dependencies for employee {emp_id}")
        abort(500, description="Failed to fetch dependencies")
    finally:
        conn.close()


@employee_api.route('/<int:emp_id>', methods=['PUT'])
def update_employee(emp_id):
    data = request.get_json() or {}
    logger.debug(f"update_employee called for ID={emp_id} with data={data}")

    # Required: NIF, Name, JobTitle, Salary, HireDate, RecordLabelID
    missing = []
    for fld in ['NIF', 'Name', 'JobTitle', 'Salary', 'HireDate', 'RecordLabelID']:
        if not data.get(fld):
            missing.append(fld)
    if missing:
        logger.warning(f"update_employee missing required fields: {missing}")
        abort(400, description=f"Missing required fields: {', '.join(missing)}")

    new_nif     = data['NIF'].strip()
    name        = data['Name'].strip()
    dob         = data.get('DateOfBirth')
    email       = data.get('Email')
    phone       = data.get('PhoneNumber')
    job_title   = data['JobTitle'].strip()
    department  = data.get('Department')
    salary      = data['Salary']
    hire_date   = data['HireDate']
    label_id    = data['RecordLabelID']

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_UpdateEmployee "
                "@EmployeeID=?, @NewNIF=?, @Name=?, @DateOfBirth=?, @Email=?, @PhoneNumber=?, "
                "@JobTitle=?, @Department=?, @Salary=?, @HireDate=?, @RecordLabelID=?",
                emp_id,
                new_nif,
                name,
                dob,
                email,
                phone,
                job_title,
                department,
                salary,
                hire_date,
                label_id
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
            str_pe = str(pe)
            # SP throws 50030 if Employee not found
            if '50030' in str_pe or 'Employee not found' in str_pe:
                logger.info(f"update_employee: Employee ID={emp_id} not found")
                abort(404, description=f"Employee with ID {emp_id} not found")
            # SP throws 51011 for “NIF already exists”
            if '51011' in str_pe or 'NIF already exists' in str_pe:
                abort(409, description="The new NIF already exists for another Person.")
            logger.exception(f"ProgrammingError in sp_UpdateEmployee ID={emp_id}")
            raise
    except pyodbc.Error as e:
        logger.exception(f"Database error updating Employee ID={emp_id}")
        abort(500, description="Internal error while updating employee.")
    finally:
        conn.close()

    return get_employee(emp_id)


@employee_api.route('/<int:emp_id>', methods=['DELETE'])
def delete_employee(emp_id):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_DeleteEmployee @ID=?",
                emp_id
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
            str_pe = str(pe)
            # SP throws 50010 if Employee not found
            if '50010' in str_pe or 'Employee not found' in str_pe:
                abort(404, description=f"Employee with ID {emp_id} not found")
            raise
        return '', 204
    finally:
        conn.close()
