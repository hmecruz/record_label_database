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
    @NIF           VARCHAR(20),
    @Name          VARCHAR(255),
    @DateOfBirth   DATE           = NULL,
    @Email         VARCHAR(255)   = NULL,
    @PhoneNumber   VARCHAR(50)    = NULL,
    @JobTitle      VARCHAR(100),
    @Department    VARCHAR(100)   = NULL,
    @Salary        DECIMAL(10,2),
    @HireDate      DATE,
    @RecordLabelID INT,
    @NewID         INT            OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @DateOfBirth IS NOT NULL AND @HireDate < @DateOfBirth
    BEGIN
        RAISERROR('Hire date cannot be earlier than date of birth.', 16, 1);
        RETURN;
    END

    INSERT INTO dbo.Person (NIF, Name, DateOfBirth, Email, PhoneNumber)
    VALUES (@NIF, @Name, @DateOfBirth, @Email, @PhoneNumber);

    INSERT INTO dbo.Employee
        (JobTitle, Department, Salary, HireDate, RecordLabel_RecordLabelID, Person_NIF)
    VALUES
        (@JobTitle, @Department, @Salary, @HireDate, @RecordLabelID, @NIF);

    SET @NewID = SCOPE_IDENTITY();
END
GO


-- ================================================
-- sp_UpdateEmployee: 
--   Updates an Employee’s Person (possibly changing NIF), 
--   and also updates the Employee record (JobTitle, etc.).
--   If the new NIF differs from the old one, we update Person.NIF
--   and fix both Employee.Person_NIF and any Contributor.Person_NIF
--   (if that Person is also a Contributor).
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_UpdateEmployee
(
    @EmployeeID    INT,
    @NewNIF        VARCHAR(20),    -- New NIF for the Person
    @Name          VARCHAR(255),   -- Person Name
    @DateOfBirth   DATE           = NULL,
    @Email         VARCHAR(255)   = NULL,
    @PhoneNumber   VARCHAR(50)    = NULL,
    @JobTitle      VARCHAR(100),
    @Department    VARCHAR(100)   = NULL,
    @Salary        DECIMAL(10,2),
    @HireDate      DATE,
    @RecordLabelID INT
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @oldNIF VARCHAR(20);

        -- 1) Find the old Person_NIF for this Employee
        SELECT 
            @oldNIF = e.Person_NIF
        FROM dbo.Employee AS e
        WHERE e.EmployeeID = @EmployeeID;

        IF @oldNIF IS NULL
        BEGIN
            THROW 50030, 'Employee not found', 1;
        END

        -- 2) If the NIF changed, update Person.NIF and fix any dependent FKs
        IF @NewNIF IS NOT NULL AND @NewNIF <> @oldNIF
        BEGIN
            -- Make sure the new NIF is not already taken
            IF EXISTS (SELECT 1 FROM dbo.Person WHERE NIF = @NewNIF)
            BEGIN
                THROW 51011, 'NIF already exists', 1;
            END

            -- Update Person.PK from oldNIF to newNIF, and update other columns
            UPDATE dbo.Person
            SET
                NIF         = @NewNIF,
                Name        = @Name,
                DateOfBirth = @DateOfBirth,
                Email       = @Email,
                PhoneNumber = @PhoneNumber
            WHERE NIF = @oldNIF;

            IF @@ROWCOUNT = 0
                THROW 51010, 'Person not found', 1;

            -- Update the Employee row to point to the new NIF
            UPDATE dbo.Employee
            SET Person_NIF = @NewNIF
            WHERE EmployeeID = @EmployeeID;

            -- If that same person was a Contributor, update its FK, too
            UPDATE dbo.Contributor
            SET Person_NIF = @NewNIF
            WHERE Person_NIF = @oldNIF;
        END
        ELSE
        BEGIN
            -- 3) NIF did not change: simply update the Person’s other fields
            UPDATE dbo.Person
            SET
                Name        = @Name,
                DateOfBirth = @DateOfBirth,
                Email       = @Email,
                PhoneNumber = @PhoneNumber
            WHERE NIF = @oldNIF;

            IF @@ROWCOUNT = 0
                THROW 51010, 'Person not found', 1;
        END

        -- 4) Now update the Employee’s own columns (JobTitle, etc.)
        UPDATE dbo.Employee
        SET
            JobTitle                  = @JobTitle,
            Department                = @Department,
            Salary                    = @Salary,
            HireDate                  = @HireDate,
            RecordLabel_RecordLabelID = @RecordLabelID,
            Person_NIF                = COALESCE(@NewNIF, @oldNIF)
        WHERE EmployeeID = @EmployeeID;

        IF @@ROWCOUNT = 0
            THROW 50031, 'Employee not found during update', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ================================================
-- sp_DeleteEmployee: 
--   Deletes an Employee by EmployeeID.
--   If the associated Person (via Person_NIF) has no other 
--   Employee or Contributor references after deletion, 
--   that Person row is also removed.
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_DeleteEmployee
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @personNIF VARCHAR(20);

        -- 1) Find the Person_NIF for this Employee
        SELECT 
            @personNIF = e.Person_NIF
        FROM dbo.Employee AS e
        WHERE e.EmployeeID = @ID;

        IF @personNIF IS NULL
        BEGIN
            -- No such Employee found
            THROW 50010, 'Employee not found', 1;
        END

        -- 2) Delete the Employee row
        DELETE FROM dbo.Employee
        WHERE EmployeeID = @ID;

        -- 3) Check if that Person_NIF is still referenced by any Employee or Contributor
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Employee    WHERE Person_NIF = @personNIF
        )
        AND NOT EXISTS (
            SELECT 1 FROM dbo.Contributor WHERE Person_NIF = @personNIF
        )
        BEGIN
            -- No remaining references: delete the Person
            DELETE FROM dbo.Person
            WHERE NIF = @personNIF;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;  -- rethrow the original error (preserves message and number)
    END CATCH
END
GO
