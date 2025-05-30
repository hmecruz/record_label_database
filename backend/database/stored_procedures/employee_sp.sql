-- GetEmployees: Retrieves employees based on optional search criteria.
CREATE OR ALTER PROCEDURE dbo.sp_GetEmployees
    @NIF         VARCHAR(20)    = NULL,
    @Name        VARCHAR(255)   = NULL,
    @JobTitle    VARCHAR(100)   = NULL,
    @Department  VARCHAR(100)   = NULL,
    @Email       VARCHAR(255)   = NULL,
    @Phone       VARCHAR(50)    = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_Employees
    WHERE (@NIF        IS NULL OR NIF        LIKE '%' + @NIF       + '%')
      AND (@Name       IS NULL OR Name       LIKE '%' + @Name      + '%')
      AND (@JobTitle   IS NULL OR JobTitle   LIKE '%' + @JobTitle  + '%')
      AND (@Department IS NULL OR Department LIKE '%' + @Department+ '%')
      AND (@Email      IS NULL OR Email      LIKE '%' + @Email     + '%')
      AND (@Phone      IS NULL OR PhoneNumber LIKE '%' + @Phone    + '%');
END
GO

-- GetEmployeeByID: Retrieves a specific employee by their ID.
CREATE OR ALTER PROCEDURE dbo.sp_GetEmployeeByID
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_Employees
    WHERE EmployeeID = @ID;
END
GO

-- CreateEmployee: Inserts a new employee and returns their ID.
CREATE OR ALTER PROCEDURE dbo.sp_CreateEmployee
    @NIF         VARCHAR(20),
    @Name        VARCHAR(255),
    @DateOfBirth DATE           = NULL,
    @Email       VARCHAR(255)   = NULL,
    @PhoneNumber VARCHAR(50)    = NULL,
    @JobTitle    VARCHAR(100),
    @Department  VARCHAR(100)   = NULL,
    @Salary      DECIMAL(10,2),
    @HireDate    DATE,
    @RecordLabelID INT,
    @NewID       INT            OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Person (NIF, Name, DateOfBirth, Email, PhoneNumber)
    VALUES (@NIF, @Name, @DateOfBirth, @Email, @PhoneNumber);

    INSERT INTO dbo.Employee
        (JobTitle, Department, Salary, HireDate, RecordLabel_RecordLabelID, Person_NIF)
    VALUES
        (@JobTitle, @Department, @Salary, @HireDate, @RecordLabelID, @NIF);

    SET @NewID = SCOPE_IDENTITY();
END
GO

-- UpdateEmployee: Updates an existing employee by their ID.
CREATE OR ALTER PROCEDURE dbo.sp_UpdateEmployee
    @ID          INT,
    @Name        VARCHAR(255),
    @DateOfBirth DATE           = NULL,
    @Email       VARCHAR(255)   = NULL,
    @PhoneNumber VARCHAR(50)    = NULL,
    @JobTitle    VARCHAR(100),
    @Department  VARCHAR(100)   = NULL,
    @Salary      DECIMAL(10,2),
    @HireDate    DATE,
    @RecordLabelID INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Person
    SET
        Name        = @Name,
        DateOfBirth = @DateOfBirth,
        Email       = @Email,
        PhoneNumber = @PhoneNumber
    WHERE NIF = (SELECT Person_NIF FROM dbo.Employee WHERE EmployeeID = @ID);

    UPDATE dbo.Employee
    SET
        JobTitle                  = @JobTitle,
        Department                = @Department,
        Salary                    = @Salary,
        HireDate                  = @HireDate,
        RecordLabel_RecordLabelID = @RecordLabelID
    WHERE EmployeeID = @ID;

    IF @@ROWCOUNT = 0
        RAISERROR('Employee with ID %d not found', 16, 1, @ID);
END
GO

-- DeleteEmployee: Deletes an employee by their ID.
CREATE OR ALTER PROCEDURE dbo.sp_DeleteEmployee
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dbo.Employee
    WHERE EmployeeID = @ID;

    IF @@ROWCOUNT = 0
        RAISERROR('Employee with ID %d not found', 16, 1, @ID);
END
GO
