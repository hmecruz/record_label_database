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
    WHERE (@Name  IS NULL OR Name        LIKE '%' + @Name  + '%')
      AND (@Role  IS NULL OR Roles       LIKE '%' + @Role  + '%')
      AND (@Email IS NULL OR Email       LIKE '%' + @Email + '%')
      AND (@Phone IS NULL OR PhoneNumber LIKE '%' + @Phone + '%');
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
-- GetPersonByNIF: Helper to fetch a Person (and any existing ContributorID) by NIF
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
-- CreateContributor:
--   • If @NIF is provided and that Person already exists, do NOT re-insert Person
--   • Otherwise, insert a new Person
--   • Then insert a new Contributor(Person_NIF)
--   • Insert any role rows into Artist/Producer/Songwriter
--   • OUTPUT parameters:
--       @ContributorID (new ContributorID),
--       @PersonNIF     (the actual NIF used),
--       @Existing      (1 if the Person already existed, 0 if newly created)
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_CreateContributor
    @NIF           VARCHAR(20)   = NULL,   -- Optional: if provided, attempt to reuse existing Person
    @Name          VARCHAR(255),
    @DateOfBirth   DATE          = NULL,
    @Email         VARCHAR(255)  = NULL,
    @PhoneNumber   VARCHAR(50)   = NULL,
    @Roles         VARCHAR(MAX)  = NULL,   -- comma-separated: “Artist,Producer,Songwriter”
    @ContributorID INT           OUTPUT,
    @PersonNIF     VARCHAR(20)   OUTPUT,
    @Existing      BIT           OUTPUT    -- 1 if Person already existed, else 0
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @actualNIF VARCHAR(20);

        IF @NIF IS NOT NULL
        BEGIN
            -- If @NIF matches an existing Person, skip inserting Person
            IF EXISTS (SELECT 1 FROM dbo.Person WHERE NIF = @NIF)
            BEGIN
                SET @actualNIF = @NIF;

                -- Fetch that Person’s existing ContributorID (if any)
                SELECT TOP 1 
                    @ContributorID = c.ContributorID,
                    @PersonNIF     = p.NIF
                FROM dbo.Person p
                LEFT JOIN dbo.Contributor c
                  ON c.Person_NIF = p.NIF
                WHERE p.NIF = @NIF;

                SET @Existing = 1;

                -- Exit now (no new insert) — caller can detect @Existing=1
                ROLLBACK TRANSACTION;
                RETURN;
            END
        END

        -- If we reach here, either @NIF was NULL, or @NIF not found → create new Person
        IF @NIF IS NULL
            SET @actualNIF = CONVERT(VARCHAR(20), NEWID()); 
        ELSE
            SET @actualNIF = @NIF;

        INSERT INTO dbo.Person (NIF, Name, DateOfBirth, Email, PhoneNumber)
        VALUES (@actualNIF, @Name, @DateOfBirth, @Email, @PhoneNumber);

        -- Now insert into Contributor
        INSERT INTO dbo.Contributor (Person_NIF)
        VALUES (@actualNIF);

        SET @ContributorID = SCOPE_IDENTITY();
        SET @PersonNIF     = @actualNIF;
        SET @Existing      = 0;

        -- Insert roles into Artist / Producer / Songwriter
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
        THROW;  -- re-raise the original error
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
-- UpdateContributor: Update existing Contributor’s Person fields and roles
-- (Note: does not allow changing NIF.  Only “overwrite” logic in the endpoint uses sp_UpdatePerson first)
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_UpdateContributor
    @ID          INT,
    @Name        VARCHAR(255),
    @DateOfBirth DATE           = NULL,
    @Email       VARCHAR(255)   = NULL,
    @PhoneNumber VARCHAR(50)    = NULL,
    @Roles       VARCHAR(MAX)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Update the Person record linked to this Contributor
        UPDATE p
        SET
          Name        = @Name,
          DateOfBirth = @DateOfBirth,
          Email       = @Email,
          PhoneNumber = @PhoneNumber
        FROM dbo.Person p
        JOIN dbo.Contributor c
          ON c.Person_NIF = p.NIF
        WHERE c.ContributorID = @ID;

        IF @@ROWCOUNT = 0
            THROW 50020, 'Contributor not found', 1;

        -- Clear existing role rows
        DELETE FROM dbo.Artist     WHERE Contributor_ContributorID = @ID;
        DELETE FROM dbo.Producer   WHERE Contributor_ContributorID = @ID;
        DELETE FROM dbo.Songwriter WHERE Contributor_ContributorID = @ID;

        -- Insert new roles
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
                    INSERT dbo.Artist (Contributor_ContributorID) VALUES (@ID);
                ELSE IF @r = 'Producer'
                    INSERT dbo.Producer (Contributor_ContributorID) VALUES (@ID);
                ELSE IF @r = 'Songwriter'
                    INSERT dbo.Songwriter (Contributor_ContributorID) VALUES (@ID);

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
-- DeleteContributor: Delete a contributor by ContributorID
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_DeleteContributor
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dbo.Contributor
    WHERE ContributorID = @ID;

    IF @@ROWCOUNT = 0
        THROW 50021, 'Contributor not found', 1;
END
GO
