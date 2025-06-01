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
    Convert a cursor row from vw_Employees into a JSON dict.
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
        "HireDate":        row.HireDate.isoformat(),
        "Email":           row.Email,
        "PhoneNumber":     row.PhoneNumber,
        "RecordLabelID":   row.RecordLabelID,
        "RecordLabelName": row.RecordLabelName
    }

@employee_api.route('', methods=['GET'])
def list_employees():
    # read optional filters
    nif        = request.args.get('nif')
    name       = request.args.get('name')
    jobtitle   = request.args.get('jobtitle')
    department = request.args.get('department')
    email      = request.args.get('email')
    phone      = request.args.get('phone')
    # note: 'label' filter handled client-side

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
    # Validate required fields
    required = ['NIF', 'Name', 'JobTitle', 'Salary', 'HireDate', 'RecordLabelID']
    missing = [f for f in required if not data.get(f)]
    if missing:
        abort(400, description=f"Missing required fields: {', '.join(missing)}")

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        # call create proc, capture new ID
        result = cursor.execute(
            "DECLARE @NewID INT; "
            "EXEC dbo.sp_CreateEmployee "
            "@NIF=?,@Name=?,@DateOfBirth=?,@Email=?,@PhoneNumber=?,"
            "@JobTitle=?,@Department=?,@Salary=?,@HireDate=?,@RecordLabelID=?,"
            "@NewID=@NewID OUTPUT; "
            "SELECT @NewID AS NewID;",
            data.get('NIF'),
            data.get('Name'),
            data.get('DateOfBirth'),
            data.get('Email'),
            data.get('PhoneNumber'),
            data.get('JobTitle'),
            data.get('Department'),
            data.get('Salary'),
            data.get('HireDate'),
            data.get('RecordLabelID')
        )
        new_id = result.fetchone().NewID
        conn.commit()
    except pyodbc.IntegrityError as e:
        conn.rollback()
        abort(400, description=str(e))
    finally:
        conn.close()

    # fetch full record to return including RecordLabelName
    return get_employee(new_id)

@employee_api.route('/<int:emp_id>', methods=['PUT'])
def update_employee(emp_id):
    data = request.get_json() or {}
    logger.debug(f"update_employee called for ID={emp_id} with data={data}")

    # Validate required fields
    required = ['Name', 'JobTitle', 'Salary', 'HireDate', 'RecordLabelID']
    missing = [f for f in required if not data.get(f)]
    if missing:
        logger.warning(f"update_employee missing required fields: {missing}")
        abort(400, description=f"Missing required fields: {', '.join(missing)}")

    name          = data.get('Name').strip()
    dob           = data.get('DateOfBirth')
    email         = data.get('Email')
    phone         = data.get('PhoneNumber')
    job_title     = data.get('JobTitle').strip()
    department    = data.get('Department')
    salary        = data.get('Salary')
    hire_date     = data.get('HireDate')
    record_label  = data.get('RecordLabelID')

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        try:
            cursor.execute(
                "EXEC dbo.sp_UpdateEmployee "
                "@ID=?, @Name=?, @DateOfBirth=?, @Email=?, @PhoneNumber=?, "
                "@JobTitle=?, @Department=?, @Salary=?, @HireDate=?, @RecordLabelID=?",
                emp_id,
                name,
                dob,
                email,
                phone,
                job_title,
                department,
                salary,
                hire_date,
                record_label
            )
            conn.commit()
        except pyodbc.ProgrammingError as pe:
            # SP might throw error 50011 if Employee not found
            if '50011' in str(pe):
                logger.info(f"update_employee: Employee ID={emp_id} not found")
                abort(404, description=f"Employee with ID {emp_id} not found")
            logger.exception(f"ProgrammingError in sp_UpdateEmployee ID={emp_id}")
            raise
    except pyodbc.Error as e:
        logger.exception(f"Database error updating Employee ID={emp_id}")
        abort(500, description="Internal error while updating employee.")
    finally:
        conn.close()

    # Re‐fetch and return the updated employee
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
            if '50012' in str(pe):
                abort(404, description=f"Employee with ID {emp_id} not found")
            raise
        return '', 204
    finally:
        conn.close()
