-- Record Labels View
CREATE OR ALTER VIEW dbo.vw_RecordLabels
AS
SELECT
    RecordLabelID,
    Name,
    Location,
    Website,
    Email,
    PhoneNumber
FROM dbo.RecordLabel;
GO

-- Employees View
CREATE OR ALTER VIEW dbo.vw_Employees
AS
SELECT
    e.EmployeeID,
    e.Person_NIF           AS NIF,
    p.Name,
    p.DateOfBirth          AS DateOfBirth,
    e.JobTitle,
    e.Department,
    e.Salary,
    e.HireDate,
    p.Email,
    p.PhoneNumber,
    e.RecordLabel_RecordLabelID AS RecordLabelID,
    rl.Name                AS RecordLabelName
FROM dbo.Employee e
JOIN dbo.Person    p  ON p.NIF = e.Person_NIF
JOIN dbo.RecordLabel rl ON rl.RecordLabelID = e.RecordLabel_RecordLabelID;
GO

