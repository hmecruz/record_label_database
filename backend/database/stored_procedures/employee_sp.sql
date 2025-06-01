-- ================================================
-- sp_GetEmployees: Fetch employees with optional filters
-- ================================================
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

-- ================================================
-- sp_GetEmployeeByID: Fetch a single employee by EmployeeID
-- ================================================
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

-- ================================================
-- sp_GetPersonByNIF: Helper to fetch Person (& any ContributorID) by NIF
--   (same as in contributor_sp.sql)
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetPersonByNIF
    @NIF VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.NIF,
        p.Name,
        p.DateOfBirth,
        p.Email,
        p.PhoneNumber,
        c.ContributorID
    FROM dbo.Person p
    LEFT JOIN dbo.Contributor c
      ON c.Person_NIF = p.NIF
    WHERE p.NIF = @NIF;
END
GO

-- ================================================
-- sp_AddEmployeeFromExistingPerson:
--   Given an existing Person’s @NIF, insert exactly one
--   new Employee with the provided fields.
--   Returns @NewID = newly created EmployeeID.
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_AddEmployeeFromExistingPerson
    @NIF           VARCHAR(20),
    @JobTitle      VARCHAR(100),
    @Department    VARCHAR(100)   = NULL,
    @Salary        DECIMAL(10,2),
    @HireDate      DATE,
    @RecordLabelID INT,
    @NewID         INT            OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1) Insert the new Employee row
        INSERT INTO dbo.Employee
            (JobTitle, Department, Salary, HireDate, RecordLabel_RecordLabelID, Person_NIF)
        VALUES
            (@JobTitle, @Department, @Salary, @HireDate, @RecordLabelID, @NIF);

        SET @NewID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ================================================
-- sp_CreateEmployee:
--   Handles three cases:
--     A) @NIF is brand‐new → insert Person + Employee
--     B) @NIF already exists as Person AND already has an Employee → return that EmployeeID
--     C) @NIF exists as Person but no Employee yet → compare incoming Person fields to existing;
--          • if identical → insert new Employee
--          • if different → signal conflict (caller shows keep/overwrite dialog)
--   Outputs:
--     @EmployeeID   = newly inserted (or existing) EmployeeID
--     @PersonNIF    = the Person’s NIF
--     @Existing     = 0 (newly created) or 1 (Person already existed)
--     @Conflict     = 1 if Person exists but fields differ
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_CreateEmployee
(
    @NIF           VARCHAR(20)    = NULL,    -- optional front‐end
    @Name          VARCHAR(255),
    @DateOfBirth   DATE           = NULL,
    @Email         VARCHAR(255)   = NULL,
    @PhoneNumber   VARCHAR(50)    = NULL,
    @JobTitle      VARCHAR(100),
    @Department    VARCHAR(100)   = NULL,
    @Salary        DECIMAL(10,2),
    @HireDate      DATE,
    @RecordLabelID INT,
    @EmployeeID    INT            OUTPUT,
    @PersonNIF     VARCHAR(20)    OUTPUT,
    @Existing      BIT            OUTPUT,    -- 1 if Person already existed
    @Conflict      BIT            OUTPUT     -- 1 if Person exists but fields differ
)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1) If a non‐NULL @NIF was supplied, check if that Person already exists
    IF @NIF IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Person WHERE NIF = @NIF)
    BEGIN
        -- 1a) If an Employee record for that Person already exists, return immediately
        IF EXISTS (SELECT 1 FROM dbo.Employee WHERE Person_NIF = @NIF)
        BEGIN
            SELECT 
                @EmployeeID  = e.EmployeeID,
                @PersonNIF   = @NIF,
                @Existing    = 1,
                @Conflict    = 0
            FROM dbo.Employee e
            WHERE e.Person_NIF = @NIF;

            RETURN;  -- done
        END

        -- 1b) Person exists but no Employee row → compare incoming Person fields to existing
        DECLARE 
            @existingName        VARCHAR(255),
            @existingDOB         DATE,
            @existingEmail       VARCHAR(255),
            @existingPhoneNumber VARCHAR(50);

        SELECT 
            @existingName        = p.Name,
            @existingDOB         = p.DateOfBirth,
            @existingEmail       = p.Email,
            @existingPhoneNumber = p.PhoneNumber
        FROM dbo.Person p
        WHERE p.NIF = @NIF;

        -- If all fields match exactly, create the Employee directly:
        IF (ISNULL(@existingName, '') = ISNULL(@Name, ''))
           AND (ISNULL(CONVERT(VARCHAR(10), @existingDOB, 120), '') = ISNULL(CONVERT(VARCHAR(10), @DateOfBirth, 120), ''))
           AND (ISNULL(@existingEmail, '') = ISNULL(@Email, ''))
           AND (ISNULL(@existingPhoneNumber, '') = ISNULL(@PhoneNumber, ''))
        BEGIN
            -- Person matches exactly → insert Employee
            EXEC dbo.sp_AddEmployeeFromExistingPerson
                 @NIF           = @NIF,
                 @JobTitle      = @JobTitle,
                 @Department    = @Department,
                 @Salary        = @Salary,
                 @HireDate      = @HireDate,
                 @RecordLabelID = @RecordLabelID,
                 @NewID         = @EmployeeID OUTPUT;

            SET @PersonNIF  = @NIF;
            SET @Existing   = 1;  -- Person existed, but we just created the Employee
            SET @Conflict   = 0;
            RETURN;
        END
        ELSE
        BEGIN
            -- Person exists but fields differ → signal conflict
            SET @EmployeeID  = NULL;
            SET @PersonNIF   = @NIF;
            SET @Existing    = 1;
            SET @Conflict    = 1;
            RETURN;
        END
    END

    -- 2) If we reach here, either @NIF was NULL or Person doesn’t exist → create fresh Person + Employee
    IF @NIF IS NULL
        SET @NIF = CONVERT(VARCHAR(20), NEWID());  -- generate random NIF

    BEGIN TRANSACTION;
    BEGIN TRY
        -- 2a) Insert into Person
        INSERT INTO dbo.Person (NIF, Name, DateOfBirth, Email, PhoneNumber)
        VALUES (@NIF, @Name, @DateOfBirth, @Email, @PhoneNumber);

        -- 2b) Insert into Employee
        INSERT INTO dbo.Employee
            (JobTitle, Department, Salary, HireDate, RecordLabel_RecordLabelID, Person_NIF)
        VALUES
            (@JobTitle, @Department, @Salary, @HireDate, @RecordLabelID, @NIF);

        SET @EmployeeID  = SCOPE_IDENTITY();
        SET @PersonNIF   = @NIF;
        SET @Existing    = 0;
        SET @Conflict    = 0;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ================================================
-- sp_UpdateEmployee: 
--   Updates an Employee’s Person (possibly changing NIF), 
--   then updates the Employee record (JobTitle, etc.).  
--   If @NewNIF differs from the old one, updates Person.NIF 
--   and fixes FKs in Employee and in Contributor (if any).
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_UpdateEmployee
(
    @EmployeeID    INT,
    @NewNIF        VARCHAR(20),    -- New NIF for Person (may differ from old)
    @Name          VARCHAR(255),   -- New Person Name
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

        -- 2) If the NIF changed, update Person.PK from oldNIF → newNIF, then fix FKs
        IF @NewNIF IS NOT NULL AND @NewNIF <> @oldNIF
        BEGIN
            -- Ensure the new NIF isn’t already used by another Person
            IF EXISTS (SELECT 1 FROM dbo.Person WHERE NIF = @NewNIF)
            BEGIN
                THROW 51011, 'NIF already exists', 1;
            END

            -- Update Person row (PK + other fields)
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

            -- Update the Employee row to point to newNIF
            UPDATE dbo.Employee
            SET Person_NIF = @NewNIF
            WHERE EmployeeID = @EmployeeID;

            -- If that Person was also a Contributor, update its FK, too:
            UPDATE dbo.Contributor
            SET Person_NIF = @NewNIF
            WHERE Person_NIF = @oldNIF;
        END
        ELSE
        BEGIN
            -- 3) NIF did not change: update only the other Person fields
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

        -- 4) Update the Employee’s own fields
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
--   that Person is also removed.
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

        -- 3) If no other Employee or Contributor references this Person, remove the Person
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Employee    WHERE Person_NIF = @personNIF
        )
        AND NOT EXISTS (
            SELECT 1 FROM dbo.Contributor WHERE Person_NIF = @personNIF
        )
        BEGIN
            DELETE FROM dbo.Person
            WHERE NIF = @personNIF;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ================================================
-- sp_GetEmployeeDependencies:
--   Returns counts of rows that reference this employee’s Person_NIF:
--     • How many Collaboration_Contributor links refer to this Person via Contributor
--     • How many Contributor_Song links refer to this Person via Contributor
--   (Because an Employee may also be a Contributor.)
--   The frontend can use these counts to warn before deletion.
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetEmployeeDependencies
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @personNIF VARCHAR(20) = NULL;
    DECLARE @collabCount INT = 0;
    DECLARE @songCount  INT = 0;

    -- 1) Get the Person_NIF for this Employee
    SELECT 
        @personNIF = e.Person_NIF
    FROM dbo.Employee e
    WHERE e.EmployeeID = @EmployeeID;

    IF @personNIF IS NULL
    BEGIN
        -- If the Employee doesn’t exist, return zeros
        SELECT 0 AS CollaborationCount, 0 AS SongCount;
        RETURN;
    END

    -- 2) Count “collaboration‐contributor” rows where that contributor corresponds to this Person
    SELECT 
        @collabCount = COUNT(*)
    FROM dbo.Collaboration_Contributor cc
    JOIN dbo.Contributor co 
      ON co.ContributorID = cc.Contributor_ContributorID
    WHERE co.Person_NIF = @personNIF;

    -- 3) Count “contributor‐song” rows similarly
    SELECT 
        @songCount = COUNT(*)
    FROM dbo.Contributor_Song cs
    JOIN dbo.Contributor co 
      ON co.ContributorID = cs.Contributor_ContributorID
    WHERE co.Person_NIF = @personNIF;

    SELECT
        @collabCount AS CollaborationCount,
        @songCount    AS SongCount;
END
GO
