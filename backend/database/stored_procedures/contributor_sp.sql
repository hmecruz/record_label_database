-- ================================================
-- GetContributors: Fetch contributors with optional filters
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetContributors
    @Name   VARCHAR(255) = NULL,
    @Role   VARCHAR(50)  = NULL,
    @Email  VARCHAR(255) = NULL,
    @Phone  VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_Contributors
    WHERE (@Name  IS NULL OR Name           LIKE '%' + @Name  + '%')
      AND (@Role  IS NULL OR Roles          LIKE '%' + @Role  + '%')
      AND (@Email IS NULL OR Email          LIKE '%' + @Email + '%')
      AND (@Phone IS NULL OR PhoneNumber    LIKE '%' + @Phone + '%');
END
GO

-- ================================================
-- GetContributorByID: Fetch a single contributor by ContributorID
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetContributorByID
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_Contributors
    WHERE ContributorID = @ID;
END
GO

-- ================================================
-- 4) sp_GetPersonByNIF: Helper to fetch Person (& any ContributorID) by NIF
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
-- 5) sp_AddContributorFromExistingPerson:
--    Given a Person’s @NIF, insert exactly one
--    new Contributor and the comma‐separated @Roles.
--    Returns @NewID = newly created ContributorID.
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_AddContributorFromExistingPerson
    @NIF       VARCHAR(20),
    @Roles     VARCHAR(MAX)    = NULL,   -- comma-separated
    @NewID     INT            OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1) Insert the new Contributor row
        INSERT INTO dbo.Contributor (Person_NIF)
        VALUES (@NIF);

        SET @NewID = SCOPE_IDENTITY();

        -- 2) Insert roles for that Contributor
        IF @Roles IS NOT NULL
        BEGIN
            DECLARE @r VARCHAR(50);
            DECLARE cur CURSOR FOR
              SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@Roles, ',');
            OPEN cur;
            FETCH NEXT FROM cur INTO @r;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @r = 'Artist'
                    INSERT dbo.Artist (Contributor_ContributorID) VALUES (@NewID);
                ELSE IF @r = 'Producer'
                    INSERT dbo.Producer (Contributor_ContributorID) VALUES (@NewID);
                ELSE IF @r = 'Songwriter'
                    INSERT dbo.Songwriter (Contributor_ContributorID) VALUES (@NewID);
                FETCH NEXT FROM cur INTO @r;
            END
            CLOSE cur; 
            DEALLOCATE cur;
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
-- 6) sp_CreateContributor:
--    Handles three cases:
--      A) NIF is brand‐new → insert Person + Contributor + Roles
--      B) NIF already exists as Person AND already has a Contributor → return that ContributorID
--      C) NIF exists as Person but no Contributor yet → compare incoming Person fields to existing;
--           • if identical → insert new Contributor + Roles
--           • if different → signal conflict and return existing Person data
--    Outputs:
--      @ContributorID  = newly inserted ContributorID (or existing slug)
--      @PersonNIF      = the Person’s NIF
--      @Existing       = 0 (newly created) or 1 (Person already existed)
--      @Conflict       = 1 if Person fields differ → caller must handle “keep vs overwrite vs cancel.”
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_CreateContributor
(
    @NIF           VARCHAR(20)    = NULL,    -- optional front‐end
    @Name          VARCHAR(255),
    @DateOfBirth   DATE           = NULL,
    @Email         VARCHAR(255)   = NULL,
    @PhoneNumber   VARCHAR(50)    = NULL,
    @Roles         VARCHAR(MAX)   = NULL,    -- comma-separated
    @ContributorID INT            OUTPUT,
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
        -- 1a) If a Contributor record for that Person already exists, return immediately
        IF EXISTS (SELECT 1 FROM dbo.Contributor WHERE Person_NIF = @NIF)
        BEGIN
            SELECT 
                @ContributorID = c.ContributorID,
                @PersonNIF     = @NIF,
                @Existing      = 1,
                @Conflict      = 0
            FROM dbo.Contributor c
            WHERE c.Person_NIF = @NIF;

            RETURN;  -- done
        END

        -- 1b) Person exists but no Contributor row → compare incoming Person fields to existing
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

        -- If all fields match (including NULLs), create the Contributor directly:
        IF (ISNULL(@existingName, '') = ISNULL(@Name, ''))
           AND (ISNULL(CONVERT(VARCHAR(10), @existingDOB, 120), '') = ISNULL(CONVERT(VARCHAR(10), @DateOfBirth, 120), ''))
           AND (ISNULL(@existingEmail, '') = ISNULL(@Email, ''))
           AND (ISNULL(@existingPhoneNumber, '') = ISNULL(@PhoneNumber, ''))
        BEGIN
            -- Person matches exactly → insert Contributor + Roles
            EXEC dbo.sp_AddContributorFromExistingPerson 
                 @NIF       = @NIF,
                 @Roles     = @Roles,
                 @NewID     = @ContributorID OUTPUT;

            SET @PersonNIF = @NIF;
            SET @Existing  = 1;  -- Person existed, but we just created the Contributor
            SET @Conflict  = 0;
            RETURN;
        END
        ELSE
        BEGIN
            -- Person exists but fields differ → signal conflict
            SET @ContributorID = NULL;
            SET @PersonNIF     = @NIF;
            SET @Existing      = 1;
            SET @Conflict      = 1;
            RETURN;
        END
    END

    -- 2) If we reach here, either @NIF was NULL or Person doesn’t exist → create fresh Person + Contributor + Roles
    IF @NIF IS NULL
        SET @NIF = CONVERT(VARCHAR(20), NEWID());  -- generate random NIF

    BEGIN TRANSACTION;
    BEGIN TRY
        -- 2a) Insert into Person
        INSERT INTO dbo.Person (NIF, Name, DateOfBirth, Email, PhoneNumber)
        VALUES (@NIF, @Name, @DateOfBirth, @Email, @PhoneNumber);

        -- 2b) Insert into Contributor
        INSERT INTO dbo.Contributor (Person_NIF)
        VALUES (@NIF);

        SET @ContributorID = SCOPE_IDENTITY();
        SET @PersonNIF     = @NIF;
        SET @Existing      = 0;
        SET @Conflict      = 0;

        -- 2c) Insert roles
        IF @Roles IS NOT NULL
        BEGIN
            DECLARE @r VARCHAR(50);
            DECLARE cur CURSOR FOR
              SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@Roles, ',');
            OPEN cur;
            FETCH NEXT FROM cur INTO @r;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @r = 'Artist'
                    INSERT dbo.Artist (Contributor_ContributorID) VALUES (@ContributorID);
                ELSE IF @r = 'Producer'
                    INSERT dbo.Producer (Contributor_ContributorID) VALUES (@ContributorID);
                ELSE IF @r = 'Songwriter'
                    INSERT dbo.Songwriter (Contributor_ContributorID) VALUES (@ContributorID);
                FETCH NEXT FROM cur INTO @r;
            END
            CLOSE cur;
            DEALLOCATE cur;
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
-- UpdatePerson: If the user chooses to overwrite an existing Person’s fields
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_UpdatePerson
    @NIF         VARCHAR(20),
    @Name        VARCHAR(255),
    @DateOfBirth DATE           = NULL,
    @Email       VARCHAR(255)   = NULL,
    @PhoneNumber VARCHAR(50)    = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Person
    SET
      Name        = @Name,
      DateOfBirth = @DateOfBirth,
      Email       = @Email,
      PhoneNumber = @PhoneNumber
    WHERE NIF = @NIF;

    IF @@ROWCOUNT = 0
        THROW 51010, 'Person not found', 1;
END
GO

-- ================================================
-- DeleteContributor: Delete a contributor by ContributorID
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_DeleteContributor
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.Contributor WHERE ContributorID = @ID;
    IF @@ROWCOUNT = 0
        THROW 50021, 'Contributor not found', 1;
END
GO