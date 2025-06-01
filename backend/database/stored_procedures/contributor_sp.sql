-- ================================================
-- sp_GetContributors: Fetch contributors with optional filters
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
-- sp_GetContributorByID: Fetch a single contributor by ContributorID
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
-- sp_GetPersonByNIF: Helper to fetch Person (& any ContributorID) by NIF
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
-- sp_AddContributorFromExistingPerson:
--   Given a Person’s @NIF, insert exactly one
--   new Contributor and the comma-separated @Roles.
--   Returns @NewID = newly created ContributorID.
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
                BEGIN
                    -- Give each new Artist a unique default StageName
                    INSERT dbo.Artist 
                      (Contributor_ContributorID, StageName)
                    VALUES 
                      (@NewID, CONCAT('Artist_', CAST(@NewID AS VARCHAR(20))));
                END
                ELSE IF @r = 'Producer'
                BEGIN
                    INSERT dbo.Producer (Contributor_ContributorID) VALUES (@NewID);
                END
                ELSE IF @r = 'Songwriter'
                BEGIN
                    INSERT dbo.Songwriter (Contributor_ContributorID) VALUES (@NewID);
                END

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
-- sp_CreateContributor:
--   Handles three cases:
--     A) NIF is brand-new → insert Person + Contributor + Roles
--     B) NIF already exists as Person AND already has a Contributor → return that ContributorID
--     C) NIF exists as Person but no Contributor yet → compare incoming Person fields to existing;
--          • if identical → insert new Contributor + Roles
--          • if different → signal conflict and return existing Person data
--   Outputs:
--     @ContributorID  = newly inserted ContributorID (or existing slug)
--     @PersonNIF      = the Person’s NIF
--     @Existing       = 0 (newly created) or 1 (Person already existed)
--     @Conflict       = 1 if Person fields differ → caller must handle “keep vs overwrite vs cancel.”
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

    -- 1) If a non-NULL @NIF was supplied, check if that Person already exists
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

        -- If all fields match exactly, create the Contributor directly:
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
                BEGIN
                    -- Give each new Artist a unique default StageName
                    INSERT dbo.Artist 
                      (Contributor_ContributorID, StageName)
                    VALUES 
                      (@ContributorID, CONCAT('Artist_', CAST(@ContributorID AS VARCHAR(20))));
                END
                ELSE IF @r = 'Producer'
                BEGIN
                    INSERT dbo.Producer (Contributor_ContributorID) VALUES (@ContributorID);
                END
                ELSE IF @r = 'Songwriter'
                BEGIN
                    INSERT dbo.Songwriter (Contributor_ContributorID) VALUES (@ContributorID);
                END

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
-- sp_UpdateContributor: 
--   Updates a Contributor’s Person (possibly changing NIF),
--   then updates Roles.  If @NewNIF differs from the old one,
--   it updates Person.NIF and fixes the Contributor.Person_NIF
--   (and any Employee.Person_NIF) to point to the new NIF.
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_UpdateContributor
(
    @ID            INT,            -- ContributorID to update
    @NewNIF        VARCHAR(20),    -- New NIF (may differ from old)
    @Name          VARCHAR(255),   -- New Name
    @DateOfBirth   DATE            = NULL,
    @Email         VARCHAR(255)    = NULL,
    @PhoneNumber   VARCHAR(50)     = NULL,
    @Roles         VARCHAR(MAX)    = NULL    -- comma-separated
)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @oldNIF VARCHAR(20);

        -- 1) Find the old Person_NIF for this Contributor
        SELECT 
            @oldNIF = c.Person_NIF
        FROM dbo.Contributor AS c
        WHERE c.ContributorID = @ID;

        IF @oldNIF IS NULL
        BEGIN
            -- ContributorID not found
            THROW 50020, 'Contributor not found', 1;
        END

        -- 2) If the NIF changed, update Person.NIF and also any referring FKs
        IF @NewNIF IS NOT NULL AND @NewNIF <> @oldNIF
        BEGIN
            -- First, ensure the new NIF is not already in use by some other Person
            IF EXISTS (SELECT 1 FROM dbo.Person WHERE NIF = @NewNIF)
            BEGIN
                -- Trying to change to an existing NIF → unique‐key violation
                THROW 51011, 'NIF already exists', 1;
            END

            -- Update the PK in Person
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

            -- Update the Contributor row to point to the new NIF
            UPDATE dbo.Contributor
            SET Person_NIF = @NewNIF
            WHERE ContributorID = @ID;

            -- Also update any Employee that pointed to the oldNIF
            UPDATE dbo.Employee
            SET Person_NIF = @NewNIF
            WHERE Person_NIF = @oldNIF;
        END
        ELSE
        BEGIN
            -- 3) NIF did not change (or @NewNIF is blank), just update the other Person fields
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

        -- 4) Delete existing roles for this Contributor
        DELETE FROM dbo.Artist     WHERE Contributor_ContributorID = @ID;
        DELETE FROM dbo.Producer   WHERE Contributor_ContributorID = @ID;
        DELETE FROM dbo.Songwriter WHERE Contributor_ContributorID = @ID;

        -- 5) Re‐insert roles (if any)
        IF @Roles IS NOT NULL
        BEGIN
            DECLARE @r VARCHAR(50);
            DECLARE cur CURSOR FOR
              SELECT LTRIM(RTRIM(value)) 
              FROM STRING_SPLIT(@Roles, ',');
            OPEN cur;
            FETCH NEXT FROM cur INTO @r;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @r = 'Artist'
                BEGIN
                    -- If you're using the Artist table, and you need a StageName,
                    -- you can supply a default or require it in the JSON. For now:
                    INSERT dbo.Artist 
                      (Contributor_ContributorID, StageName)
                    VALUES 
                      (@ID, CONCAT('Artist_', CAST(@ID AS VARCHAR(20))));
                END
                ELSE IF @r = 'Producer'
                BEGIN
                    INSERT dbo.Producer (Contributor_ContributorID) VALUES (@ID);
                END
                ELSE IF @r = 'Songwriter'
                BEGIN
                    INSERT dbo.Songwriter (Contributor_ContributorID) VALUES (@ID);
                END

                FETCH NEXT FROM cur INTO @r;
            END
            CLOSE cur; 
            DEALLOCATE cur;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;  -- rethrow the original error
    END CATCH
END
GO


-- ================================================
-- sp_DeleteContributor: 
--   Deletes a Contributor by ContributorID.
--   Also removes any Collaboration_Contributor and Contributor_Song links first.
--   If the associated Person (via Person_NIF) has no other 
--   Contributor or Employee references after deletion, 
--   that Person row is also removed.
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_DeleteContributor
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @personNIF VARCHAR(20);

        -- 1) Find the Person_NIF for this Contributor
        SELECT 
            @personNIF = c.Person_NIF
        FROM dbo.Contributor AS c
        WHERE c.ContributorID = @ID;

        IF @personNIF IS NULL
        BEGIN
            -- No such Contributor found
            THROW 50020, 'Contributor not found', 1;
        END

        -- 2) Delete any Collaboration_Contributor rows for this Contributor
        DELETE FROM dbo.Collaboration_Contributor
        WHERE Contributor_ContributorID = @ID;

        -- 3) Delete any Contributor_Song rows for this Contributor
        DELETE FROM dbo.Contributor_Song
        WHERE Contributor_ContributorID = @ID;

        -- 4) Delete the Contributor row itself
        DELETE FROM dbo.Contributor
        WHERE ContributorID = @ID;

        -- 5) Check if that Person_NIF is still referenced by any Contributor or Employee
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Contributor WHERE Person_NIF = @personNIF
        )
        AND NOT EXISTS (
            SELECT 1 FROM dbo.Employee    WHERE Person_NIF = @personNIF
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
        THROW;  -- rethrow the original error
    END CATCH
END
GO


-- ================================================
-- sp_GetContributorDependencies:
--   Returns counts of “child” rows that reference this contributor:
--     • Collaboration_Contributor rows
--     • Contributor_Song rows
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetContributorDependencies
    @ContributorID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @collabCount INT = 0;
    DECLARE @songCount  INT = 0;

    SELECT 
        @collabCount = COUNT(*) 
    FROM dbo.Collaboration_Contributor
    WHERE Contributor_ContributorID = @ContributorID;

    SELECT 
        @songCount = COUNT(*) 
    FROM dbo.Contributor_Song
    WHERE Contributor_ContributorID = @ContributorID;

    SELECT
        @collabCount AS CollaborationCount,
        @songCount  AS SongCount;
END
GO