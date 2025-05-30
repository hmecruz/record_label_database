-- GetContributors: Get contributors with optional filters
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

-- GetContributorByID: Get contributor by ID
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

-- CreateContributor: Create a new contributor
CREATE OR ALTER PROCEDURE dbo.sp_CreateContributor
    @Name        VARCHAR(255),
    @DateOfBirth DATE           = NULL,
    @Email       VARCHAR(255)   = NULL,
    @PhoneNumber VARCHAR(50)    = NULL,
    @Roles       VARCHAR(MAX)   = NULL,  -- comma-separated list
    @NewID       INT            OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1) Person: generate a new NIF? We assume NIF provided by client, but here Person_NIF = NEWID
        DECLARE @newNIF VARCHAR(20) = CONVERT(VARCHAR(20), NEWID());
        INSERT INTO dbo.Person (NIF, Name, DateOfBirth, Email, PhoneNumber)
        VALUES (@newNIF, @Name, @DateOfBirth, @Email, @PhoneNumber);

        -- 2) Contributor
        INSERT INTO dbo.Contributor (Person_NIF)
        VALUES (@newNIF);
        SET @NewID = SCOPE_IDENTITY();

        -- 3) Roles
        IF @Roles IS NOT NULL
        BEGIN
            DECLARE @r VARCHAR(50);
            DECLARE curR CURSOR FOR
              SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@Roles, ',');
            OPEN curR;
            FETCH NEXT FROM curR INTO @r;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @r = 'Artist'
                    INSERT INTO dbo.Artist (Contributor_ContributorID) VALUES (@NewID);
                ELSE IF @r = 'Producer'
                    INSERT INTO dbo.Producer (Contributor_ContributorID) VALUES (@NewID);
                ELSE IF @r = 'Songwriter'
                    INSERT INTO dbo.Songwriter (Contributor_ContributorID) VALUES (@NewID);
                FETCH NEXT FROM curR INTO @r;
            END
            CLOSE curR; DEALLOCATE curR;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;  -- rethrow
    END CATCH
END
GO

-- UpdateContributor: Update an existing contributor
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
        -- Update Person fields
        UPDATE p
        SET Name = @Name,
            DateOfBirth = @DateOfBirth,
            Email = @Email,
            PhoneNumber = @PhoneNumber
        FROM dbo.Person p
        JOIN dbo.Contributor c ON c.Person_NIF = p.NIF
        WHERE c.ContributorID = @ID;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK; RAISERROR('Contributor not found',16,1); RETURN;
        END

        -- Refresh role tables
        DELETE FROM dbo.Artist      WHERE Contributor_ContributorID = @ID;
        DELETE FROM dbo.Producer    WHERE Contributor_ContributorID = @ID;
        DELETE FROM dbo.Songwriter  WHERE Contributor_ContributorID = @ID;

        IF @Roles IS NOT NULL
        BEGIN
            DECLARE @r VARCHAR(50);
            DECLARE curR CURSOR FOR
              SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@Roles, ',');
            OPEN curR;
            FETCH NEXT FROM curR INTO @r;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @r = 'Artist'
                    INSERT INTO dbo.Artist (Contributor_ContributorID) VALUES (@ID);
                ELSE IF @r = 'Producer'
                    INSERT INTO dbo.Producer (Contributor_ContributorID) VALUES (@ID);
                ELSE IF @r = 'Songwriter'
                    INSERT INTO dbo.Songwriter (Contributor_ContributorID) VALUES (@ID);
                FETCH NEXT FROM curR INTO @r;
            END
            CLOSE curR; DEALLOCATE curR;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- -- DeleteContributor: Delete a contributor by ID
CREATE OR ALTER PROCEDURE dbo.sp_DeleteContributor
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.Contributor WHERE ContributorID = @ID;
    IF @@ROWCOUNT = 0
        RAISERROR('Contributor not found',16,1);
END
GO
