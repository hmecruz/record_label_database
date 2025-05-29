-- =========================
-- Employee Management - DML Queries
-- =========================

-- ===== SELECT Queries =====

-- View all employees of a specific record label
SELECT e.EmployeeID, p.Name, e.JobTitle, e.Department, e.Salary, e.HireDate, p.Email, p.PhoneNumber
FROM Employee e
JOIN Person p ON e.Person_NIF = p.NIF
WHERE e.RecordLabel_RecordLabelID = 1;  -- Replace 1 with the desired RecordLabelID
ORDER BY e.EmployeeID;

-- ===== INSERT Queries =====

-- Add a new employee to a record label
INSERT INTO Employee (JobTitle, Department, Salary, HireDate, RecordLabel_RecordLabelID, Person_NIF)
VALUES ('Software Engineer', 'IT', 60000.00, '2025-05-28', 1, '123456789'); 
-- Replace values accordingly, ensure Person_NIF exists in Person table and RecordLabel_RecordLabelID exists

-- ===== UPDATE Queries =====

-- Promote or reassign an employee (change JobTitle, Department, or Salary)
UPDATE Employee
SET JobTitle = 'Senior Engineer',
    Department = 'R&D',
    Salary = 80000.00
WHERE EmployeeID = 10;  -- Replace with the EmployeeID to update

-- ===== DELETE Queries =====

-- Remove an employee (former employee)
DELETE FROM Employee
WHERE EmployeeID = 10;  -- Replace with the EmployeeID to delete
